-- vim: shiftwidth=2:foldmethod=marker
-- Plugin list

vim.cmd [[packadd packer.nvim]]
require('configurations')
vim.cmd([[
augroup packer_user_config
  autocmd!
  autocmd BufWritePost plugins.lua source <afile> | PackerCompile
augroup end
]])

return require('packer').startup(function()
  -- Packer can manage itself  
  use 'wbthomason/packer.nvim'

  -- : Visual plugins {{{
  use{
    {
      'vim-airline/vim-airline',
      requires = {
        -- Git plugins for hunks and branch
        'tpope/vim-fugitive',
        'mhinz/vim-signify',
        'airblade/vim-gitgutter'
      }
    },
    'vim-airline/vim-airline-themes',
--[[    {
      'akinsho/bufferline.nvim',
      requires = 'kyazdani42/nvim-web-devicons'
    },
-- ]]
    {
      'noib3/nvim-cokeline',
      requires = 'kyazdani42/nvim-web-devicons',
      -- : Configuration {{{
      config = function()
        require('cokeline').setup{
          show_if_buffers_are_at_least = 2,
        }
      end
      -- }}}
    },
--    'ryanoasis/vim-devicons',
    {
      'nvim-treesitter/nvim-treesitter',
      requires = {
        'nvim-treesitter/nvim-treesitter-refactor',
        'nvim-treesitter/nvim-treesitter-textobjects',
      },
      run = ':TSUpdate'
    },
    {
      'norcalli/nvim-colorizer.lua',
      ft = {'css', 'javascript', 'vim', 'html', 'typescript', 'fxml'},
      config = [[require('colorizer').setup{'css', 'javascript', 'vim', 'html', 'fxml'}]],
    },
    {
      'neovimhaskell/haskell-vim',
      ft = {'haskell', 'lhaskell', 'hs', 'lhs'}
    }
  }
  use { -- Themes
    'morhetz/gruvbox',
    'altercation/vim-colors-solarized',
    'doums/darcula',
    'jnurmine/zenburn',
    'sainnhe/gruvbox-material',
    {
      'briones-gabriel/darcula-solid.nvim',
      requires = 'rktjmp/lush.nvim'
    }

  }
-- }}}
  
  --: IDE Feature plugins{{{
  use {
    'neovim/nvim-lspconfig',
    'ms-jpq/coq_nvim',
    'ms-jpq/coq.artifacts',
    'preservim/tagbar',
    'jiangmiao/auto-pairs',
    'onsails/lspkind-nvim',   -- https://github.com/onsails/lspkind-nvim
    'kosayoda/nvim-lightbulb', -- https://github.com/kosayoda/nvim-lightbulb
    'ray-x/lsp_signature.nvim',
    'b0o/mapx.nvim',
    'folke/trouble.nvim'
--[[    { -- Completion
      'hrsh7th/nvim-cmp',
      requires = {
        'L3MON4D3/LuaSnip',
        { 'hrsh7th/cmp-buffer', after = 'nvim-cmp' },
        'hrsh7th/cmp-nvim-lsp',
        { 'hrsh7th/cmp-path', after = 'nvim-cmp' },
        { 'hrsh7th/cmp-nvim-lua', after = 'nvim-cmp' },
        { 'saadparwaiz1/cmp_luasnip', after = 'nvim-cmp' },
      },
      config = [[require('config.cmp')] ],
      event = 'InsertEnter *',
    },
    { -- Debuggina
      'mfussenegger/nvim-dap',
      setup = [[require('config.dap_setup')] ],
      config = [[require('config.dap')] ],
      requires = 'jbyuki/one-small-step-for-vimkind',
      wants = 'one-small-step-for-vimkind',
      module = 'dap',
    },
    {
      'rcarriga/nvim-dap-ui',
      requires = 'nvim-dap',
      after = 'nvim-dap',
      config = function()
        require('dapui').setup()
      end,
    }
--]]
  }
--}}}
  -- Documentation
  use {
    'danymat/neogen',
    requires = 'nvim-treesitter',
    config = [[require('config.neogen')]],
    keys = { '<localleader>d', '<localleader>df', '<localleader>dc' },
  }

  
  -- Easy use 
  use 'psliwka/vim-smoothie'

  -- Search
  use 'romainl/vim-cool'

  -- Addons
  use {
    'editorconfig/editorconfig-vim',
    'mhinz/vim-startify',
    'tomtom/tcomment_vim',
  -- https://github.com/RishabhRD/nvim-lsputils
    {
      'RishabhRD/nvim-lsputils',
      requires = {
          'RishabhRD/popfix'
      },
    },
    {
      'kyazdani42/nvim-tree.lua',
      requires = {
          'kyazdani42/nvim-web-devicons',
      },
      config = function() require'nvim-tree'.setup{} end
    }
  }
  -- Profiling
  use { 
    'dstein64/vim-startuptime', 
    cmd = 'StartupTime', 
    config = [[vim.g.startuptime_tries = 10]] 
  }
end)
