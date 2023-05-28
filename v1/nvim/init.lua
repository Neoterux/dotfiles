-- Vim Options
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.mouse = 'a'

-- Setup the plugins
-- require('plugins').setup()

vim.loader.enable()
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
  import = 'plugins',
  change_detection = {
    -- Detect changes and reload UI
    enabled = true,
    notify = false, 
  }
}

require('settings')
require('settings.mappings')

-- require('lsp/config')

-- Configure plugins
-- vim.cmd 'colorscheme gruvbox-material'


-- vim: sw=2 tw=2 ts=2 smarttab expandtab
