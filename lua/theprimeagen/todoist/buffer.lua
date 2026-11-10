-- Editable task list in an org-style buffer. Edit lines freely, then :w pushes the changes.

local api = require("theprimeagen.todoist.api")
local sync = require("theprimeagen.todoist.sync")

local M = {}

-- [bufnr] = { filter, projects, snapshot, busy }
local state = {}

local HELP = {
  "Todoist buffer",
  "",
  "  x        toggle done on the line (or the selected lines)",
  "  o / O    new task below / above",
  "  :w       push edits, new tasks, completions and deletions to Todoist",
  "  R        reload from Todoist (drops unsaved edits)",
  "",
  "  Task line:  - [ ] Text <date> p1",
  "    <date>    2026-11-10, or anything Todoist understands: <tomorrow 9am>, <every fri>",
  "              delete the <...> to clear the date",
  "    p1..p3    priority (p4, the default, is not shown)",
  "  Move a line under another '* Project' header to move the task there.",
  "  Deleting a line deletes the task (you are asked first).",
}

local function notify(msg, level)
  vim.notify("Todoist: " .. msg, level or vim.log.levels.INFO)
end

local function setup_syntax(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd([[
      syntax clear
      syntax match todoistComment /^#.*$/
      syntax match todoistHeader /^\*\+\s.*$/ contains=todoistId
      syntax match todoistDone /^\s*- \[[xX]\].*$/ contains=todoistId
      syntax match todoistDue /<[^<>]*>/
      syntax match todoistP1 /\s\zsp1\ze\s*\%({{\|$\)/
      syntax match todoistP2 /\s\zsp2\ze\s*\%({{\|$\)/
      syntax match todoistP3 /\s\zsp3\ze\s*\%({{\|$\)/
      syntax match todoistId /\s*{{[A-Za-z0-9_-]\+}}\s*$/ conceal
      highlight default link todoistComment Comment
      highlight default link todoistHeader Title
      highlight default link todoistDone Comment
      highlight default link todoistDue Special
      highlight default link todoistP1 DiagnosticError
      highlight default link todoistP2 DiagnosticWarn
      highlight default link todoistP3 DiagnosticInfo
    ]])
  end)
end

local function set_window_options()
  vim.opt_local.conceallevel = 2
  vim.opt_local.concealcursor = "nc"
  vim.opt_local.wrap = false
end

local function toggle_done(first, last)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
  for i, line in ipairs(lines) do
    if line:match("^%s*%- %[ %]") then
      lines[i] = line:gsub("%[ %]", "[x]", 1)
    elseif line:match("^%s*%- %[[xX]%]") then
      lines[i] = line:gsub("%[[xX]%]", "[ ]", 1)
    end
  end
  vim.api.nvim_buf_set_lines(buf, first - 1, last, false, lines)
end

local function show_help()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP)
  vim.bo[buf].modifiable = false
  local width = 0
  for _, line in ipairs(HELP) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width + 2,
    height = #HELP,
    row = math.floor((vim.o.lines - #HELP) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  for _, key in ipairs({ "q", "<Esc>", "g?" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, nowait = true })
  end
end

local function set_keymaps(buf)
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = "Todoist: " .. desc })
  end
  map("n", "x", function()
    local row = vim.fn.line(".")
    toggle_done(row, row)
  end, "toggle done")
  map("x", "x", function()
    local first, last = vim.fn.line("v"), vim.fn.line(".")
    if first > last then
      first, last = last, first
    end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    toggle_done(first, last)
  end, "toggle done")
  map("n", "o", "o- [ ] ", "new task below")
  map("n", "O", "O- [ ] ", "new task above")
  map("n", "R", function()
    M.refresh(buf)
  end, "reload")
  map("n", "g?", show_help, "help")
end

--- The filter of the current buffer if it is a Todoist buffer, else nil.
function M.current_filter()
  local st = state[vim.api.nvim_get_current_buf()]
  return st and st.filter
end

local function find_buffer(filter)
  for buf, st in pairs(state) do
    if st.filter == filter and vim.api.nvim_buf_is_valid(buf) then
      return buf
    end
  end
end

local function create_buffer(filter)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, "todoist://" .. (filter or "all"))
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "todoist"
  state[buf] = { filter = filter }

  setup_syntax(buf)
  set_keymaps(buf)

  local group = vim.api.nvim_create_augroup("todoist_buffer_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    buffer = buf,
    callback = function()
      M.write(buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    buffer = buf,
    callback = set_window_options,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      state[buf] = nil
    end,
  })
  return buf
end

local function jump_to_task(buf, task_id)
  local needle = "{{" .. task_id .. "}}"
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find(needle, 1, true) then
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        vim.api.nvim_win_set_cursor(win, { lnum, 0 })
      end
      return
    end
  end
end

--- Reloads the buffer from Todoist. on_done(ok) runs after the lines are replaced.
function M.refresh(buf, on_done)
  local st = state[buf]
  if not st or st.busy then
    return
  end
  st.busy = true
  api.fetch(st.filter, function(err, projects, tasks)
    st.busy = false
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if err then
      notify(err, vim.log.levels.ERROR)
      return on_done and on_done(false)
    end

    local lines, snapshot = sync.render(projects, tasks, st.filter)
    st.projects, st.snapshot = projects, snapshot

    local cursors = {}
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      cursors[win] = vim.api.nvim_win_get_cursor(win)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    for win, cursor in pairs(cursors) do
      vim.api.nvim_win_set_cursor(win, { math.min(cursor[1], #lines), 0 })
    end

    if on_done then
      on_done(true)
    end
  end)
end

--- Opens (or reuses) the buffer for a filter; nil means every active task.
--- If task_id is given, the cursor lands on that task.
function M.open(filter, task_id)
  local buf = find_buffer(filter)
  local fresh = not buf
  buf = buf or create_buffer(filter)
  vim.api.nvim_set_current_buf(buf)
  set_window_options()

  if fresh or not vim.bo[buf].modified then
    if fresh then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Todoist: loading…" })
      vim.bo[buf].modified = false
    end
    M.refresh(buf, function(ok)
      if ok and task_id then
        jump_to_task(buf, task_id)
      end
    end)
  elseif task_id then
    jump_to_task(buf, task_id)
  end
end

local OP_ORDER = { delete = 1, create = 2, update = 3, move = 4, close = 5 }

-- Quick Add parses the text (dates, @labels, ...) but has no project field, and a #Project
-- in the text would be ambiguous for duplicate names. So add it to the default project,
-- then apply the line's explicit <date>/priority and move it where the line says.
-- cb(err, task) gets the task as it ended up.
local function create_task(op, cb)
  api.quick_add(op.text, function(err, task)
    if err then
      return cb(err)
    end
    if not (task and task.id) then
      return cb("Todoist did not return the new task, so its project and date could not be set")
    end

    local function move_if_needed(current)
      if current.project_id == op.project_id then
        return cb(nil, current)
      end
      api.move_task(current.id, op.project_id, function(move_err, moved)
        if move_err then
          return cb("created, but could not move it: " .. move_err)
        end
        cb(nil, moved or vim.tbl_extend("force", current, { project_id = op.project_id }))
      end)
    end

    if next(op.overrides) == nil then
      return move_if_needed(task)
    end
    api.update_task(task.id, op.overrides, function(update_err, updated)
      if update_err then
        return cb("created, but could not set its date/priority: " .. update_err)
      end
      move_if_needed(updated or task)
    end)
  end)
end

local function run_op(op, cb)
  if op.kind == "create" then
    create_task(op, cb)
  elseif op.kind == "update" then
    api.update_task(op.id, op.body, cb)
  elseif op.kind == "move" then
    api.move_task(op.id, op.project_id, cb)
  elseif op.kind == "close" then
    api.close_task(op.id, cb)
  elseif op.kind == "delete" then
    api.delete_task(op.id, cb)
  end
end

local function summarize(ops)
  local counts, order = {}, {}
  for _, op in ipairs(ops) do
    if not counts[op.kind] then
      order[#order + 1] = op.kind
    end
    counts[op.kind] = (counts[op.kind] or 0) + 1
  end
  local parts = {}
  for _, kind in ipairs(order) do
    parts[#parts + 1] = counts[kind] .. " " .. kind
  end
  return table.concat(parts, ", ")
end

local function confirm_deletes(ops)
  local labels = {}
  for _, op in ipairs(ops) do
    if op.kind == "delete" then
      labels[#labels + 1] = "  " .. op.label
    end
  end
  if #labels == 0 then
    return true
  end
  local prompt = ("Delete %d task(s) from Todoist?\n%s"):format(#labels, table.concat(labels, "\n"))
  return vim.fn.confirm(prompt, "&Yes\n&No", 2) == 1
end

function M.write(buf)
  local st = state[buf]
  if not st or not st.snapshot then
    return notify("nothing loaded yet", vim.log.levels.WARN)
  end
  if st.busy then
    return notify("still syncing, try again in a moment", vim.log.levels.WARN)
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local ops, errors = sync.plan(lines, st.snapshot, st.projects, st.filter)
  if #errors > 0 then
    return notify("nothing saved:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
  end
  if #ops == 0 then
    vim.bo[buf].modified = false
    return notify("no changes")
  end
  if not confirm_deletes(ops) then
    return notify("write cancelled")
  end

  table.sort(ops, function(a, b)
    return OP_ORDER[a.kind] < OP_ORDER[b.kind]
  end)

  st.busy = true
  local failures, created = {}, {}
  local function project_name(id)
    for _, project in ipairs(st.projects) do
      if project.id == id then
        return project.name
      end
    end
    return tostring(id)
  end
  local function step(i)
    if i > #ops then
      st.busy = false
      if #failures > 0 then
        notify(("%d of %d changes failed:\n%s"):format(#failures, #ops, table.concat(failures, "\n")),
          vim.log.levels.ERROR)
      else
        notify("saved (" .. summarize(ops) .. ")" .. table.concat(created, ""))
      end
      return M.refresh(buf)
    end
    local op = ops[i]
    run_op(op, function(err, task)
      if err then
        failures[#failures + 1] = ("%s %q: %s"):format(op.kind, op.label, err)
      elseif op.kind == "create" then
        local wanted = op.project_id
        local landed = task and task.project_id or wanted
        if landed ~= wanted then
          failures[#failures + 1] = ("create %q: asked for #%s, Todoist put it in #%s"):format(
            op.label, project_name(wanted), project_name(landed))
        else
          created[#created + 1] = ("\n  + %s → #%s"):format(op.label, project_name(landed))
        end
      end
      step(i + 1)
    end)
  end
  step(1)
end

return M
