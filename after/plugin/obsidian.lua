require("obsidian").setup({
  workspaces = {
    {
      name = "personal",
      path = "~/Obsidian/Vault",
    },
  },

  daily_notes = {
    -- Optional, if you keep daily notes in a separate directory.
    folder = "Daily Notes/",
  },

  mappings = {
    -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
    ["gf"] = {
      action = function()
        return require("obsidian").util.gf_passthrough()
      end,
      opts = { noremap = false, expr = true, buffer = true },
    },
    -- Toggle check-boxes.
    ["<leader>ch"] = {
      action = function()
        return require("obsidian").util.toggle_checkbox()
      end,
      opts = { buffer = true },
    },
    -- Smart action depending on context, either follow link or toggle checkbox.
    ["<leader>t"] = {
      action = function()
        return require("obsidian").today()
      end,
      opts = { buffer = true, expr = true },
    }
  },

  -- see below for full list of options 👇
})
