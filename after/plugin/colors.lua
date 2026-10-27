require('rose-pine').setup({ disable_background = true })

-- Make float/completion borders visible: same bg as the editor, bright border fg
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('FloatBorderContrast', {}),
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
    vim.api.nvim_set_hl(0, 'NormalFloat', { fg = normal.fg, bg = normal.bg })
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#82aaff', bg = normal.bg })
  end,
})

function ColorMyPencils(color)
  color = color or "nightfly"
  vim.cmd.colorscheme(color)
end

ColorMyPencils()
