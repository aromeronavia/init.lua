vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>",
  { silent = true, noremap = true }
)

vim.keymap.set("n", "<leader>xx", "<cmd>Trouble document_diagnostics <cr>",
  { silent = true, noremap = true }
)

vim.keymap.set("n", "<leader>xd", "<cmd>Trouble workspace_diagnostics <cr>",
  { silent = true, noremap = true }
)

require("trouble").setup {
  icons = {
    ---@type trouble.Indent.symbols
    indent        = {
      top         = "│ ",
      middle      = "├╴",
      last        = "└╴",
      -- last          = "-╴",
      -- last       = "╰╴", -- rounded
      fold_open   = " ",
      fold_closed = " ",
      ws          = "  ",
    },
    folder_closed = " ",
    folder_open   = " ",
    kinds         = {
      Array         = " ",
      Boolean       = "󰨙 ",
      Class         = " ",
      Constant      = "󰏿 ",
      Constructor   = " ",
      Enum          = " ",
      EnumMember    = " ",
      Event         = " ",
      Field         = " ",
      File          = " ",
      Function      = "󰊕 ",
      Interface     = " ",
      Key           = " ",
      Method        = "󰊕 ",
      Module        = " ",
      Namespace     = "󰦮 ",
      Null          = " ",
      Number        = "󰎠 ",
      Object        = " ",
      Operator      = " ",
      Package       = " ",
      Property      = " ",
      String        = " ",
      Struct        = "󰆼 ",
      TypeParameter = " ",
      Variable      = "󰀫 ",
    },
  },
}
