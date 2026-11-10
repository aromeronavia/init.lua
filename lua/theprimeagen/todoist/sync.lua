-- Builds the buffer from Todoist data, and turns an edited buffer back into API operations.
-- No I/O; safe to test headless.

local format = require("theprimeagen.todoist.format")

local M = {}

local function sort_projects(projects)
  local sorted = vim.list_slice(projects)
  table.sort(sorted, function(a, b)
    if a.inbox_project ~= b.inbox_project then
      return a.inbox_project == true
    end
    return (a.child_order or 0) < (b.child_order or 0)
  end)
  return sorted
end

-- Orders tasks the way Todoist does: by child_order, subtasks right under their parent.
-- A subtask whose parent isn't in the view (e.g. a filter) is shown at the top level.
local function task_tree(tasks)
  local by_id, children, roots = {}, {}, {}
  for _, task in ipairs(tasks) do
    by_id[task.id] = task
  end
  for _, task in ipairs(tasks) do
    if task.parent_id and by_id[task.parent_id] then
      children[task.parent_id] = children[task.parent_id] or {}
      table.insert(children[task.parent_id], task)
    else
      table.insert(roots, task)
    end
  end

  local function by_order(a, b)
    return (a.child_order or 0) < (b.child_order or 0)
  end

  local ordered = {}
  local function walk(list, depth)
    table.sort(list, by_order)
    for _, task in ipairs(list) do
      table.insert(ordered, { task = task, depth = depth })
      if children[task.id] then
        walk(children[task.id], depth + 1)
      end
    end
  end
  walk(roots, 0)
  return ordered
end

--- The project a filter is scoped to, as a project object, or nil.
function M.filter_project(projects, filter)
  local name = format.project_from_filter(filter)
  if not name then
    return nil
  end
  for _, project in ipairs(projects) do
    if project.name:lower() == name:lower() then
      return project
    end
  end
end

--- Returns the buffer lines and a snapshot { [task_id] = parsed line } to diff against on write.
--- A nil filter lists every project, so empty ones are there to add tasks under.
--- A single-project filter ("#Prefix") always shows that project, even with no tasks.
function M.render(projects, tasks, filter)
  local always_show = M.filter_project(projects, filter)
  local tasks_by_project = {}
  for _, task in ipairs(tasks) do
    tasks_by_project[task.project_id] = tasks_by_project[task.project_id] or {}
    table.insert(tasks_by_project[task.project_id], task)
  end

  local lines = {
    "# Todoist: " .. (filter or "all tasks")
      .. "   x toggle done · o new task · :w sync · R refresh · g? help",
  }
  local snapshot = {}

  for _, project in ipairs(sort_projects(projects)) do
    local project_tasks = tasks_by_project[project.id]
    if project_tasks or not filter or project == always_show then
      table.insert(lines, "")
      table.insert(lines, format.render_header(project))
      for _, entry in ipairs(task_tree(project_tasks or {})) do
        local line = format.render_task(entry.task, entry.depth + 1)
        table.insert(lines, line)
        local parsed = format.parse_task(line)
        parsed.project_id = project.id
        snapshot[entry.task.id] = parsed
      end
    end
  end

  return lines, snapshot
end

local function due_fields(due, allow_clear)
  if not due then
    return allow_clear and { due_string = "no date" } or {}
  end
  if due:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return { due_date = due }
  end
  return { due_string = due }
end

local function inbox_id(projects)
  for _, project in ipairs(projects) do
    if project.inbox_project then
      return project.id
    end
  end
end

--- Compares the edited lines with the snapshot.
--- Returns ops (each { kind, id?, body?, project_id?, label }) and a list of error strings.
--- If there are errors, nothing should be applied.
--- Task lines above the first header go to the filter's project, or the Inbox.
function M.plan(lines, snapshot, projects, filter)
  local projects_by_id, projects_by_name, duplicate_names = {}, {}, {}
  for _, project in ipairs(projects) do
    projects_by_id[project.id] = project
    local key = project.name:lower()
    if projects_by_name[key] then
      duplicate_names[key] = true
    end
    projects_by_name[key] = project
  end

  local ops, errors, seen = {}, {}, {}
  local default_project = M.filter_project(projects, filter)
  local current_project = default_project and default_project.id or inbox_id(projects)

  for lnum, line in ipairs(lines) do
    local header, header_id = format.parse_header(line)
    local task = not header and format.parse_task(line)

    if header then
      local project = projects_by_id[header_id] or projects_by_name[header:lower()]
      if not projects_by_id[header_id] and duplicate_names[header:lower()] then
        project = nil
        table.insert(errors, ("line %d: more than one project is named %q"):format(lnum, header))
      elseif not project then
        table.insert(errors, ("line %d: no project named %q (create it in Todoist first)"):format(lnum, header))
      end
      current_project = project and project.id
    elseif task and task.content ~= "" and current_project then
      local before = task.id and snapshot[task.id]

      if before and not seen[task.id] then
        seen[task.id] = true

        local changes = {}
        if task.content ~= before.content then
          changes.content = task.content
        end
        if task.priority ~= before.priority then
          changes.priority = format.api_priority(task.priority)
        end
        if task.due ~= before.due then
          changes = vim.tbl_extend("force", changes, due_fields(task.due, true))
        end
        if next(changes) then
          table.insert(ops, { kind = "update", id = task.id, body = changes, label = task.content })
        end
        if current_project ~= before.project_id then
          table.insert(ops, { kind = "move", id = task.id, project_id = current_project, label = task.content })
        end
        if task.checked then
          table.insert(ops, { kind = "close", id = task.id, label = task.content })
        end
      elseif not task.checked then
        -- New line, or a pasted duplicate of an existing task: create it through Quick Add,
        -- so "Call John at 4pm @calls" is parsed like in the Todoist app. An explicit
        -- <date> or pN on the line is applied afterwards and wins over the parsed text.
        local overrides = due_fields(task.due, false)
        if task.priority ~= format.DEFAULT_PRIORITY then
          overrides.priority = format.api_priority(task.priority)
        end
        table.insert(ops, {
          kind = "create",
          text = task.content,
          project_id = current_project,
          overrides = overrides,
          label = task.content,
        })
      end
    end
  end

  for id, before in pairs(snapshot) do
    if not seen[id] then
      table.insert(ops, { kind = "delete", id = id, label = before.content })
    end
  end

  return ops, errors
end

return M
