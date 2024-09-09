vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>",
  { silent = true, noremap = true }
)

vim.keymap.set("n", "<leader>xx", "<cmd>Trouble document_diagnostics <cr>",
  { silent = true, noremap = true }
)

vim.keymap.set("n", "<leader>xd", "<cmd>Trouble workspace_diagnostics <cr>",
  { silent = true, noremap = true }
)
