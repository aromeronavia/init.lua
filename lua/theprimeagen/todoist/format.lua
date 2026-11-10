-- Converts between Todoist tasks and buffer lines. No I/O; safe to test headless.
--
--   * Project name
--     - [ ] Task text <2026-11-10> p1 {{taskid}}
--
-- The {{taskid}} suffix is concealed in the buffer. A task line without one is a new task.
-- The UI priority p1 (most urgent) is 4 in the API.

local M = {}

M.DEFAULT_PRIORITY = 4

function M.priority_label(api_priority)
  return 5 - (api_priority or 1)
end

function M.api_priority(label)
  return 5 - label
end

--- The text shown between < >. Recurring tasks show their rule ("every monday")
--- so editing the line doesn't silently turn them into one-off dates.
function M.due_text(due)
  if not due then
    return nil
  end
  if due.is_recurring and due.string then
    return due.string
  end
  local date, time = due.date:match("^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d)")
  if date then
    return date .. " " .. time
  end
  return due.date
end

function M.render_task(task, depth)
  local parts = {
    string.rep("  ", depth or 0) .. "- [" .. (task.checked and "x" or " ") .. "] " .. task.content,
  }
  local due = M.due_text(task.due)
  if due then
    parts[#parts + 1] = "<" .. due .. ">"
  end
  local label = M.priority_label(task.priority)
  if label ~= M.DEFAULT_PRIORITY then
    parts[#parts + 1] = "p" .. label
  end
  parts[#parts + 1] = "{{" .. task.id .. "}}"
  return table.concat(parts, " ")
end

--- The project a filter is scoped to ("#Prefix", "##Prefix"), or nil for anything broader.
function M.project_from_filter(filter)
  if not filter then
    return nil
  end
  local name = vim.trim(filter):match("^##?([^&|!()#@]+)$")
  return name and vim.trim(name) or nil
end

--- Headers carry the project id (concealed) so duplicate or renamed projects resolve exactly.
function M.render_header(project)
  return "* " .. project.name .. " {{" .. project.id .. "}}"
end

--- Returns name, id (id is nil for a header typed by hand), or nil if not a header.
function M.parse_header(line)
  local rest = line:match("^%*+%s+(.-)%s*$")
  if not rest then
    return nil
  end
  local name, id = rest:match("^(.-)%s*{{([%w_%-]+)}}$")
  if name then
    return name, id
  end
  return rest, nil
end

-- Splits a trailing token off `text`; returns the remaining text and the capture, if any.
local function take_suffix(text, pattern)
  local head, capture = text:match("^(.-)" .. pattern)
  if head then
    return head, capture
  end
  return text, nil
end

--- Returns nil for lines that aren't tasks. Otherwise
--- { checked, content, due (nil or text), priority (1-4 label), id (nil for new tasks) }.
function M.parse_task(line)
  local mark, rest = line:match("^%s*%- %[([ xX])%]%s?(.*)$")
  if not mark then
    return nil
  end

  local id, priority, due
  rest, id = take_suffix(rest, "%s*{{([%w_%-]+)}}%s*$")
  -- Due date and priority may come in either order.
  for _ = 1, 2 do
    if not priority then
      rest, priority = take_suffix(rest, "%s+p([1-4])%s*$")
    end
    if not due then
      rest, due = take_suffix(rest, "%s*<([^<>]*)>%s*$")
    end
  end

  due = due and vim.trim(due) or nil
  if due == "" then
    due = nil
  end

  return {
    checked = mark ~= " ",
    content = vim.trim(rest),
    due = due,
    priority = tonumber(priority) or M.DEFAULT_PRIORITY,
    id = id,
  }
end

return M
