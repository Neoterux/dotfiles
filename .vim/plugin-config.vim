" Load additional functions for plugins configuration
so ~/.vim/plugin-config-functions.vim

" AIRLINE PLUGING CONFIGURATION
let g:airline_section_b = '%{strftime("%c")}'

let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline_theme = 'base16_gruvbox_dark_hard'

" NERDTree CONFIGURATION
" let g:NERDTreeDirArrowExpandable = '⬏'
" let g:NERDTreeDirArrowCollapsible = '⬎'

" vim-devicon plugin Config

let g:webdevicons_enable = 1
let g:webdevicons_enable_nerdtree = 1


" Lightline
let g:lightline = {
			\ 'separator': {'left': "\ue0b0", 'right': "\ue0b2"},
			\ 'component_function'  : {
				\ 'cocstatus': 'coc#status',
				\ 'filetype': 'SetupFileType',
				\ 'fileformat': 'MyFileformat',
				\ }
			\ }

function! MyFiletype()
  return winwidth(0) > 70 ? (strlen(&filetype) ? &filetype . ' ' . WebDevIconsGetFileTypeSymbol() : 'no ft') : ''
endfunction

function! MyFileformat()
  return winwidth(0) > 70 ? (&fileformat . ' ' . WebDevIconsGetFileFormatSymbol()) : ''
endfunction


" IdentLine Plugin CONFIGURATION
let g:indentLine_defaultGroup = 'SpecialKey'
let g:indentLine_color_term = 239
let g:indentLine_char_list = ['|', '¦', '┆', '┊']
let g:indentLine_enabled = 1

" Language Client Plugin configuration
" set rtp+=~/.vim/pack/psuit/start/LanguageClient-neovim

let g:LanguageClient_rootMakers = ['*.cabal', 'stack.yaml']
let g:LanguageClient_serverCommands = { 
			\ 'haskell': ['ghcide', '--lsp'],
			\ 'vue': ['vls'],
			\ 'sh': ['bash-language-server', 'start']
			\}
let g:LanguageClient_rootMakers = ['*.cabal', 'stack.yaml']

hi link ALEError Error
hi Warning term=underline cterm=underline ctermfg=Yellow gui=undercurl guisp=Gold
hi link ALEWarning Warning
hi link ALEInfo SpellCap

