-- General maps for Vim
require('mapx').setup{global = true}
-- Map leader
vim.g.mapleader = ' '
local mmap = vim.api.nvim_set_keymap

-- Abbreviations
vim.cmd 'cnoreabbrev tree NvimTreeToggle'
vim.cmd 'cnoreabbrev diff Gdiff'
-- vim.cmd 'cnoreabbrev fzf FZF'

-- Tabgar maps
nmap('<F6>', ':TagbarToggle<CR>')

-- Tree maps
map('<Leader>t', ':NvimTreeToggle<CR>')

-- FZF Maps
nnoremap('<F5>', ':FZF<CR>')

-- IDE-Like  mapping
nnoremap('<Leader>w', ':w<CR>') -- Save file [normal]
nnoremap('<Leader>q', ':q<CR>') -- Secure quit file [normal]
nnoremap('<Leader>d', ':t.<CR>') -- Duplicate the current line [normal]
nnoremap('<Leader>r', ':vsplit<CR>') -- Vertical split buffer
-- Indentation shortcut keys
nnoremap('<Tab>', '>>_')        -- Add 1 indent level [normal]
nnoremap('<S-Tab>', '<<_')      -- Reduce 1 indent level [normal]
inoremap('<S-Tab>', '<C-D>')    -- Reduce 1 indent level [insert]
vnoremap('<Tab>', '>gv')        -- Add 1 indent level [visual]
vnoremap('<S-Tab>', '<gv')      -- Reduce 1 indent level [visual]


-- Extras
nnoremap('<C-t>', ':OpenTerminal<CR>')
--nnoremap('<Leader>h', ':BufferLineCycleNext<CR>')
--nnoremap('<Leader>h', '<Plug>(cokeline-focus-next)')
--nnoremap('<Leader>g', ':BufferLineCyclePrev<CR>')
-- nnoremap('<Leader>g', '<Plug>(cokeline-focus-prev)')
mmap('n', '<Leader>h', '<Plug>(cokeline-focus-prev)', {silent = true})
