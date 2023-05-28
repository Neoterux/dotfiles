-- vim: sw=2 ts=2 expandtab smarttab
local M = {}
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

function bootstrap()
  if not vim.loop.fs_stat(lazypath) then
    print('lazy.nvim not detected, installing...')
    vim.fn.system{
      'git',
      'clone',
      '--filter=blob:none',
      'https://github.com/folke/lazy.nvim.git',
      '--branch=stable',
      lazypath,
    }
    print('Successfully installed!')
  end
  vim.opt.rtp:prepend(lazypath)
end

function plugins()
  return {
    --: CORE Plugins {{{
    {
      'nvim-neo-tree/neo-tree.nvim',
      keys = {
        { '<leader>ft', '<cmd>Neotree toggle<CR>', desc = 'Neotree' },
      },
      config = function() require('neo-tree').setup() end,
    },
    'nvim-treesitter/nvim-treesitter',
    'junegunn/fzf',
    --}}}
    
    --: Development {{{
    'neovim/nvim-lspconfig',
    'williamboman/mason-lspconfig.nvim',
    'williamboman/mason.nvim',
    --}}}
    
    --: UI Plugins {{{
    {
      'sainnhe/gruvbox-material',
      config = function() vim.cmd [[colorscheme gruvbox-material]] end,
    },
    --}}}
  }
end

M.setup = function() 
  bootstrap()
  require('lazy').setup(plugins())
end

return M
