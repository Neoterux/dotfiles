-- vim:foldmethod=marker
-- Plugin configuration file
local au = require('au')
local let = vim.g -- Equals to let g:
local fn = vim.fn
local system = fn.system
let.startify_custom_header = fn['startify#pad'](fn.split(system([[/usr/bin/figlet -w 100 Welcome Neoterux!]]), '\n'))


-- lspkind configuration {{{
--[[
require('lspkind').init({
    -- enable text annotations
    with_text = true,
    preset = 'default',
    -- override preset symbols
    --
    -- default: {}
    symbol_map = {
      Text = "",
      Method = "",
      Function = "",
      Constructor = "",
      Field = "ﰠ",
      Variable = "",
      Class = "ﴯ",
      Interface = "",
      Module = "",
      Property = "ﰠ",
      Unit = "塞",
      Value = "",
      Enum = "",
      Keyword = "",
      Snippet = "",
      Color = "",
      File = "",
      Reference = "",
      Folder = "",
      EnumMember = "",
      Constant = "",
      Struct = "פּ",
      Event = "",
      Operator = "",
      TypeParameter = ""
    },
})
--]]
-- }}}

-- : Feline.nvim Configuration {{{
require('feline').setup()
-- }}}

--: Gruvbox settings {{{
-- Gruvbox-material{{{
--    vim.o.background = 'light'
    let.gruvbox_material_background = 'soft'
-- }}}
let.gruvbox_bold = true
let.gruvbox_italic = true
let.gruvbox_transparent_bg = true
let.gruvbox_constrat_dark = 'medium'
let.gruvbox_improved_strings = true
let.gruvbox_improved_warnings = true
let.gruvbox_sign_column = 'bg0'
--}}}

--: Airline settings {{{
let.airline_powerline_fonts                     = true
let.airline_theme                               = 'base16_gruvbox_dark_hard'
let['airline#extensions#tabline#enabled']       = false
let['airline#extensions#whitespace#enabled']    = false
let['airline#extensions#hunks#enabled']         = false
let['airline#extensions#branch#enabled']        = true

vim.cmd [[
    function! AirlineInit()
        let g:airline_section_b = airline#section#create_left(['hunks', 'branch'])
        let g:airline_section_y = ''
    endfunction
    autocmd User AirlineAfterInit call AirlineInit()
]]

-- }}}

--: Bufferline settings {{{
--[[ require('bufferline').setup{
    options = {
        tab_size = 18,
        max_name_length = 20,
        max_prefix_length = 15, -- Used when a buffer is de-duplicated
        diagnostics = 'nvim_lsp',
        separator_style = 'slant',
        offsets = { -- Custom buffer names
            {filetype = 'NvimTree', text = 'File Explorer', text_align = 'center', highlight = 'Directory'}
        },
        show_buffer_icons = true, -- Enable icons for buffer
        show_buffer_close_icon = true,
        sort_by = 'id'
    }
}
--]]
--}}}

