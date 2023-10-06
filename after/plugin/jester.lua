require('jester').setup({
  cmd = "npx jest -t '$result' -- $file",
})

vim.keymap.set('n', '<leader>jj', '<cmd>lua require("jester").run()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>jf', '<cmd>lua require("jester").run_file()<CR>', { noremap = true, silent = true })
