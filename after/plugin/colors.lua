require('rose-pine').setup({ disable_background = true })

function ColorMyPencils(color)
  color = color or "nightfly"
  vim.cmd.colorscheme(color)
end

ColorMyPencils()
