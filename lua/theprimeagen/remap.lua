vim.g.mapleader = " "

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "n", "v" }, "y", [["+y]])

vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

vim.keymap.set("i", "<C-c>", "<Esc>")

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>vfd", "<cmd>:e ~/.config/nvim/lua/theprimeagen/remap.lua<CR>")

vim.keymap.set("n", "<leader>gt", "<cmd>Git<CR>")

-- vim.keymap.set("n", "<leader>cpe", "<cmd>Copilot enable<CR>")
-- vim.keymap.set("n", "<leader>cpd", "<cmd>Copilot disable<CR>")

vim.keymap.set("n", "<leader><leader>", function()
  vim.cmd("so")
end)

vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")

vim.keymap.set("n", "<C-t>", vim.cmd.tabnew)

vim.keymap.set("n", "<C-f>", "<cmd>MRU<CR>")
vim.keymap.set("n", "<leader>mru", "<cmd>MRU<CR>")
vim.keymap.set("n", "<C-u>", "<cmd>noh<CR>")
vim.keymap.set("n", "<leader>ne", "<cmd>Neotree<CR>")
vim.keymap.set("n", "<leader>nf", "<cmd>NvimTreeFindFile<CR>")

vim.keymap.set("n", "<leader>e", vim.lsp.buf.format)

local diagnostics_active = true
local toggle_diagnostics = function()
  diagnostics_active = not diagnostics_active
  if diagnostics_active then
    vim.diagnostic.show()
  else
    vim.diagnostic.hide()
  end
end

vim.keymap.set('n', '<leader>d', toggle_diagnostics)
