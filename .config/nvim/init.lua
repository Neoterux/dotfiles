-- Basic configuration
-- Definitons:
-- vim.o  := vim global option
-- vim.go := vim global option
-- vim.wo := vim window option
-- vim.bo := vim buffer option (nvim > 0.6.0)
-- vim.fn := represent functions
-- vim.g  := equivalent to 'let g:...'



-- ******************************************************
-- *                                                    *
-- *                Global configuration                *
-- *                                                    *
-- ******************************************************

local set = vim.o
local set_ = vim.opt
local setg = vim.go
-- local wopt = vim.wo
-- local bopt = vim.bo
-- Basic configuration
set.splitright          = true  -- Activate to split in the right
set.encoding            = 'utf-8' -- Set the default encoding for new files
set.timeout             = false -- De/Activate timeout
set.ruler               = true  -- Show column & row position of the cursor
setg.t_Co               = '256'
set.number              = true  -- Enable number column
set.syntax              = 'on'  -- Enable syntax highlight
set_.termguicolors      = true  -- Enable TermGUIcolors
set.showmode            = false -- Hides --insert-- under statusline
set.wrap                = true  --
set.breakindent         = true  --
set.conceallevel        = 2     --
set.textwidth           = 120    -- Wrap lines more than 'n' characters
set.emoji               = true  --
vim.opt.backspace       = {     --
    'indent',
    'eol',
    'start'
}
set.undodir             = '/tmp'    -- Set the undo temp files will be saved
set.inccommand          = 'nosplit' --
set.showtabline         = 0  --
set_.signcolumn.auto    = 1     --
set_.clipboard:append{          --
    'unnamedplus'
}
set.mouse               = 'a'   -- Enable mouse
set.title               = true  -- Tab title as file name
set.undofile            = true  -- Activate undo temp files
set.cursorline          = true  -- Activate current cursor line Highlight
set.list                = true  -- ??
set_.listchars:append{          -- Configure ListChar
    trail = '»',                --   Trail character
    eol = '',                  --   EOL character
    tab ='|-',                  --   Tab character
    extends = '#',              --   
    space = '·'                 --   Space character
}
set_.filetype.Activate= true
-- Visual configuration
vim.cmd[[colorscheme darcula-solid]]
set_.termguicolors      = true   -- De/Activate use of gui colors instead of term
set.laststatus          = 2      -- When window will have a status line
-- set.fillchars = 'fold: ,foldclose: ,foldopen: ,foldsep: ,diff: ,eob: "'

-- Search
set.incsearch           = true  -- De/Activate incremental search
set.ignorecase          = true  -- De/Activate case sensitivity when search
set.smartcase           = true  -- ??
set.hlsearch            = true  -- De/Activate Highlight search target

-- Performance options
set.scrolljump          = 5     -- Set the scroll to jump n-lines at the time
set.lazyredraw          = true  --
set.redrawtime          = 10000 --
set.synmaxcol           = 180   -- Maximum column for syntax
set.re                  = 1     -- Regex engine

-- Tab configuration
set.expandtab           = true  -- Change tab character by spaces
set.smarttab            = true  -- ??
set.shiftround          = true  -- Round the indentation
set.tabstop             = 4     -- A tab would be interpreted as n-spaces
set.softtabstop         = 4     -- Indentation spaces??
set.shiftwidth          = 4     -- Indentation spaces
set.autoindent          = true  -- Auto indent while writting

-- Misc
set.completeopt         = "menuone,noselect,menu"
set.formatoptions       = "l"   -- word-wrap not split words
set.updatetime          = 4000
set.timeoutlen          = 1000  -- Delay to wait for next key in combo
vim.cmd[[filetype plugin indent on]]
vim.opt.shortmess:append("c")       -- Don't give ins-completion-menu messages
set.diffopt             = 'internal,filler,closeoff,algorithm:patience'
set.fixendofline        = false
set.regexpengine        = 0
vim.opt.fillchars = "fold: ,foldclose:,foldopen:,foldsep: ,diff: ,eob: "
vim.g.border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }


require('colors')

-- Custom commands
vim.cmd [[command! OpenTerminal lua require'utils/exfunctions'.openTerminal()]]

-- : Custom Plugins and configurations {{{
require('plugins')
-- require('lsp/nvim_lsp_init')
-- require('lsp/coq_config')
-- require('plugin_cfg')
-- }}}

-- Load keymaps
-- require('maps/general')
-- require('highlights')

