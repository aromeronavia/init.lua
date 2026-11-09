-- Telescope picker for git worktrees with a "created" column.
-- Same switching behaviour as git-worktree.nvim's picker (it calls the plugin
-- to switch), but shows when each worktree was created, newest first.
local M = {}

-- Parse `git worktree list --porcelain` into { path, sha, branch } entries.
local function list_worktrees()
  local lines = vim.fn.systemlist({ "git", "worktree", "list", "--porcelain" })
  if vim.v.shell_error ~= 0 then
    return nil, table.concat(lines, "\n")
  end

  local worktrees, current = {}, nil
  for _, line in ipairs(lines) do
    local key, value = line:match("^(%S+)%s?(.*)$")
    if key == "worktree" then
      current = { path = value, sha = "", branch = "(detached)" }
      table.insert(worktrees, current)
    elseif current and key == "HEAD" then
      current.sha = value:sub(1, 7)
    elseif current and key == "branch" then
      current.branch = value:gsub("^refs/heads/", "")
    elseif current and key == "bare" then
      current.bare = true
    end
  end

  return vim.tbl_filter(function(wt) return not wt.bare end, worktrees)
end

-- Creation time of the worktree folder (macOS records birth time).
local function created_at(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.birthtime and stat.birthtime.sec or 0
end

function M.pick(opts)
  opts = opts or {}
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")
  local utils = require("telescope.utils")

  local worktrees, err = list_worktrees()
  if not worktrees then
    vim.notify("git worktree list failed: " .. (err or ""), vim.log.levels.ERROR)
    return
  end

  local branch_width = 0
  for _, wt in ipairs(worktrees) do
    wt.created = created_at(wt.path)
    branch_width = math.max(branch_width, vim.fn.strdisplaywidth(wt.branch))
  end
  table.sort(worktrees, function(a, b) return a.created > b.created end)
  -- Cap the branch column so one very long branch name can't push the other
  -- columns off-screen; longer names get truncated with "…".
  branch_width = math.min(branch_width, 50)

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 16 }, -- created: YYYY-MM-DD HH:MM
      { width = branch_width },
      { width = 7 },  -- short sha
      { remaining = true },
    },
  })

  pickers.new(opts, {
    prompt_title = "Git Worktrees",
    finder = finders.new_table({
      results = worktrees,
      entry_maker = function(wt)
        return {
          value = wt,
          path = wt.path,
          ordinal = wt.branch .. " " .. wt.path,
          display = function()
            return displayer({
              { wt.created > 0 and os.date("%Y-%m-%d %H:%M", wt.created) or "?", "TelescopeResultsComment" },
              { wt.branch, "TelescopeResultsIdentifier" },
              { wt.sha, "TelescopeResultsNumber" },
              { utils.transform_path(opts, wt.path) },
            })
          end,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          require("git-worktree").switch_worktree(entry.path)
        end
      end)
      -- <M-c>: create a new worktree (same as the plugin's picker)
      map({ "i", "n" }, "<M-c>", function()
        actions.close(prompt_bufnr)
        require("telescope").extensions.git_worktree.create_git_worktree()
      end)
      return true
    end,
  }):find()
end

return M
