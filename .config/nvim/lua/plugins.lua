-- vim: shiftwidth=2:foldmethod=marker
-- Plugin list

vim.cmd [[packadd packer.nvim]]
-- require('configurations')
vim.cmd([[
augroup packer_user_config
  autocmd!
  autocmd BufWritePost plugins.lua source <afile> | PackerCompile
augroup end
]])

return require('packer').startup(function()
  use { 'lewis6991/impatient.nvim', config = [[require('impatient')]] }
  -- Packer can manage itself  
  use ({ 'wbthomason/packer.nvim', opt = true })

  -- : Core Plugins {{{
  use ({ "onsails/lspkind-nvim", event = 'VimEnter' })
  use {
    "hrsh7th/nvim-cmp",
    after = 'lspkind-nvim',
    config = [[require('configs.nvim-cmp')]],
    requires = {
--      "github/copilot.vim",
--      "hrsh7th/cmp-copilot",
      "hrsh7th/cmp-cmdline",
--      "hrsh7th/cmp-vsnip",
--      "hrsh7th/vim-vsnip",
      "lukas-reineke/cmp-under-comparator",
      "L3MON4D3/LuaSnip",
    }
  }

  use { "hrsh7th/cmp-nvim-lsp", after = 'nvim-cmp' }
  use { "hrsh7th/cmp-nvim-lua", after = 'nvim-cmp' }
  use { "hrsh7th/cmp-path", after = 'nvim-cmp' }
  use { "hrsh7th/cmp-buffer", after = 'nvim-cmp' }
  use { "hrsh7th/cmp-omni", after = 'nvim-cmp' }

  use { "quangnguyen30192/cmp-nvim-ultisnips", after = {'nvim-cmp', 'ultisnips'} }
  
  use ( -- LSP Configuration
    { 
      "neovim/nvim-lspconfig",
      requires = {
        "nvim-lua/lsp-status.nvim",
        "ray-x/lsp_signature.nvim",
        "onsails/diaglist.nvim",
      },
      after = 'cmp-nvim-lsp',
      config = [[require('configs.lsp')]]
    })
  -- }}}
  

  -- : Behaviour Plugins {{{
  use {
    "nvim-treesitter/nvim-treesitter",
    event = 'BufEnter',
    run = ":TSUpdate",
    config = [[require('configs.treesitter')]],
    requires = {
      { "lewis6991/spellsitter.nvim" },
      { "nvim-treesitter/nvim-treesitter-textobjects" },
      { "nvim-treesitter/nvim-treesitter-refactor" }
    }
  }
  use ({ "Vimjas/vim-python-pep8-indent", ft = { "python" } })
  use ({ "jeetsukumaran/vim-pythonsense", ft = { "python" } })
  use ({
    'kevinhwang91/nvim-hlslens',
    branch = 'main',
    keys = {{'n', '*'}, {'n', '#'}, {'n', 'n'}, {'n', 'N'}},
    config = [[require('configs.hlslens')]]
  })
  use {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    config = [[require('configs.telescope')]],
    requires = { 
      { 'nvim-lua/plenary.nvim' },
      { "nvim-telescope/telescope-fzf-native.nvim", run = 'make' },
      { "nvim-lua/popup.nvim" }
    }
  }
  use ({ "sbdchd/neoformat", cmd = { "Neoformat" } })
  use ({
    "karb94/neoscroll.nvim",
    event = 'VimEnter',
    config = function()
      vim.defer_fn(function() require('configs.neoscroll') end, 2000)
    end
  })
  use {
    "kyazdani42/nvim-tree.lua",
    requires = { 'kyazdani42/nvim-web-devicons' },
    config = [[require('configs.nvim-tree')]]
  }
  use { "tpope/vim-commentary", event = 'VimEnter' }
  use { "christoomey/vim-conflicted", requires = "tpope/vim-fugitive", cmd = {'Conflicted'} }
  use { "SirVer/ultisnips", event = 'InsertEnter' }
  use { "honza/vim-snippets", after = 'ultisnips' }
  use { "editorconfig/editorconfig-vim" }
  -- }}}
  
  -- : Language Specific Plugins {{{
  use ({ "plasticboy/vim-markdown", ft = { "markdown" } })
  use ({ "elzr/vim-json", ft = { 'json', 'markdown' } })
  use ({ "cespare/vim-toml", ft = { 'toml' }, branch = 'main' })
  use { "neovimhaskell/haskell-vim", ft = { 'haskell' } }
  -- }}}


-- : Enhancement Plugins {{{
  use { 
    "norcalli/nvim-colorizer.lua",
    config = [[require('configs.colorizer')]]
  }
  use { "antoinemadec/FixCursorHold.nvim" }
  use { 
    "iamcco/markdown-preview.nvim",
    run = function() vim.fn['mkdp#util#install']() end,
    ft = { 'markdown' }
  }
  use {
    "MTDL9/vim-log-highlighting",
    ft = { 'text', 'log' }
  }
  use { "tpope/vim-eunuch" }
--[[  use { 
    "williamboman/nvim-lsp-installer",
    require = "neovim/nvim-lspconfig",
    config = [[require('configs.lsp-installer')]
  }]]
--}}}

  -- : Visual Plugins {{{
  use ({'lifepillar/vim-gruvbox8', opt = true})
  use ({"mhinz/vim-signify", event = 'BufEnter'})
  use {'kyazdani42/nvim-web-devicons', event = 'VimEnter'}
  use { 
    'nvim-lualine/lualine.nvim',
    event = 'VimEnter',
    config = [[require('configs.statusline')]]
  }
  use ({ 'akinsho/bufferline.nvim', event = 'VimEnter', config = [[require('configs.bufferline')]] })
    -- Highlight URLs
  use ({ 'itchyny/vim-highlighturl', event= 'VimEnter' })
  use ({ 'briones-gabriel/darcula-solid.nvim', requires = 'rktjmp/lush.nvim' })
  use { "ellisonleao/gruvbox.nvim" }
  -- }}}

end)

