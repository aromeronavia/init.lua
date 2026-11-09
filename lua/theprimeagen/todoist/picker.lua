-- Telescope picker over Todoist tasks, for quick lookups.

local api = require("theprimeagen.todoist.api")
local format = require("theprimeagen.todoist.format")

local M = {}

M.DEFAULT_FILTER = "today | overdue"

local PRIORITY_HL = { "DiagnosticError", "DiagnosticWarn", "DiagnosticInfo" }

local function notify(msg, level)
  vim.notify("Todoist: " .. msg, level or vim.log.levels.INFO)
end

local function sort_tasks(tasks)
  table.sort(tasks, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority -- API 4 = p1
    end
    local a_due = a.due and a.due.date or "~"
    local b_due = b.due and b.due.date or "~"
    return a_due < b_due
  end)
end

--- Opens the picker. filter defaults to M.DEFAULT_FILTER; pass "all" for every active task.
function M.open(filter)
  filter = filter or M.DEFAULT_FILTER
  local api_filter = filter ~= "all" and filter or nil

  api.fetch(api_filter, function(err, projects, tasks)
    if err then
      return notify(err, vim.log.levels.ERROR)
    end
    if #tasks == 0 then
      return notify("no tasks match '" .. filter .. "'")
    end

    local project_names = {}
    for _, project in ipairs(projects) do
      project_names[project.id] = project.name
    end
    sort_tasks(tasks)

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local entry_display = require("telescope.pickers.entry_display")

    local displayer = entry_display.create({
      separator = " ",
      items = { { width = 2 }, { remaining = true }, { width = 16 }, { width = 18 } },
    })

    local function make_entry(task)
      local label = format.priority_label(task.priority)
      local project = project_names[task.project_id] or "?"
      local due = format.due_text(task.due) or ""
      return {
        value = task,
        ordinal = table.concat({ task.content, project, due }, " "),
        display = function()
          return displayer({
            { label < 4 and ("p" .. label) or "", PRIORITY_HL[label] },
            task.content,
            { "#" .. project, "Comment" },
            { due, "Special" },
          })
        end,
      }
    end

    local function complete_selected(prompt_bufnr)
      local entry = action_state.get_selected_entry()
      if not entry then
        return
      end
      actions.close(prompt_bufnr)
      api.close_task(entry.value.id, function(close_err)
        if close_err then
          return notify(close_err, vim.log.levels.ERROR)
        end
        notify("completed: " .. entry.value.content)
        M.open(filter)
      end)
    end

    local function add_task(prompt_bufnr)
      actions.close(prompt_bufnr)
      local todoist = require("theprimeagen.todoist")
      todoist.add(nil, function()
        M.open(filter)
      end, todoist.project_from_filter(filter))
    end

    pickers.new({}, {
      prompt_title = "Todoist: " .. filter,
      finder = finders.new_table({ results = tasks, entry_maker = make_entry }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry then
            require("theprimeagen.todoist.buffer").open(nil, entry.value.id)
          end
        end)
        map({ "i", "n" }, "<C-d>", complete_selected)
        map({ "i", "n" }, "<C-a>", add_task)
        return true
      end,
    }):find()
  end)
end

return M
