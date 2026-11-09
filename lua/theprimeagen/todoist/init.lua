-- Todoist inside Neovim. Needs TODOIST_API_TOKEN in the environment.
--
--   :Todoist [filter]      editable buffer (all tasks, or a Todoist filter like "today | overdue")
--   :TodoistPick [filter]  Telescope picker (default "today | overdue"; "all" for everything)
--   :TodoistAdd [text]     quick add with Todoist's own parsing: "Pay rent tomorrow #Home p1"

local api = require("theprimeagen.todoist.api")

local M = {}

local function arg_or_nil(args)
  local text = vim.trim(args)
  return text ~= "" and text or nil
end

--- The project a filter is scoped to ("#Prefix", "##Prefix"), or nil for anything broader.
function M.project_from_filter(filter)
  if not filter then
    return nil
  end
  local name = vim.trim(filter):match("^##?([^&|!()#@]+)$")
  return name and vim.trim(name) or nil
end

-- Quick add files tasks without a #Project into the Inbox, so add the default project
-- unless the text already names one. Spaces in project names are escaped as "\ ".
local function with_project(text, project)
  if not project or text:match("%f[%S]#%S") then
    return text
  end
  return text .. " #" .. project:gsub(" ", "\\ ")
end

--- Quick-adds a task; prompts when text is nil. on_added runs after a successful add.
--- project (optional) is where the task goes when the text doesn't name a #Project.
--- When omitted, it comes from the current Todoist buffer's filter, if that is one project.
function M.add(text, on_added, project)
  project = project or M.project_from_filter(require("theprimeagen.todoist.buffer").current_filter())

  local function submit(input)
    input = input and vim.trim(input)
    if not input or input == "" then
      return
    end
    input = with_project(input, project)
    api.quick_add(input, function(err)
      if err then
        return vim.notify("Todoist: " .. err, vim.log.levels.ERROR)
      end
      vim.notify("Todoist: added " .. input)
      if on_added then
        on_added()
      end
    end)
  end

  if text then
    submit(text)
  else
    local prompt = project and ("New task in #" .. project .. ": ")
      or "New task (e.g. 'Pay rent tomorrow #Home p1'): "
    vim.ui.input({ prompt = prompt }, submit)
  end
end

--- opts.project: project opened by <leader>t (e.g. "Prefix").
function M.setup(opts)
  opts = opts or {}
  local buffer = require("theprimeagen.todoist.buffer")
  local picker = require("theprimeagen.todoist.picker")

  vim.api.nvim_create_user_command("Todoist", function(opts)
    buffer.open(arg_or_nil(opts.args))
  end, { nargs = "*", desc = "Todoist: open task buffer" })

  vim.api.nvim_create_user_command("TodoistPick", function(opts)
    picker.open(arg_or_nil(opts.args))
  end, { nargs = "*", desc = "Todoist: pick a task" })

  vim.api.nvim_create_user_command("TodoistAdd", function(opts)
    M.add(arg_or_nil(opts.args))
  end, { nargs = "*", desc = "Todoist: quick add" })

  if opts.project then
    local project_filter = "#" .. opts.project
    vim.keymap.set("n", "<leader>t", function() buffer.open(project_filter) end,
      { desc = "Todoist: " .. opts.project .. " tasks" })
  end
  vim.keymap.set("n", "<leader>ot", function() buffer.open(nil) end, { desc = "Todoist: all tasks" })
  vim.keymap.set("n", "<leader>Tt", function() buffer.open(picker.DEFAULT_FILTER) end,
    { desc = "Todoist: today + overdue" })
  vim.keymap.set("n", "<leader>Tp", function() picker.open() end, { desc = "Todoist: pick a task" })
  vim.keymap.set("n", "<leader>Ta", function() M.add() end, { desc = "Todoist: quick add" })
end

return M
