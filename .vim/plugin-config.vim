" Load additional functions for plugins configuration
so ~/.vim/plugin-config-functions.vim

" ========================== [ Template plugin ] ==========================
let g:tmpl_search_paths = ['~/.vim/files-templates']
" Load data, this is personal
so ~/.vim/files-templates/template_data.vim

" ========================== [ Built-In Configuration ] ===================
let loaded_netrw = 0
let g:omni_sql_no_default_maps = 1
let g:loaded_python_provider = 0
let g:loaded_perl_provider = 0
let g:loaded_ruby_provider = 0

" ========================== [ Gruvbox Settings ] ==========================
let g:gruvbox_bold = 1
let g:gruvbox_italic = 1
let g:gruvbox_transparent_bg = 1
let g:gruvbox_contrast_dark = 'medium'
let g:gruvbox_improved_strings = 1
let g:gruvbox_improved_warnings = 1
let g:gruvbox_sign_column ='bg0'


" =========================== [ Airline Settings ] ===========================

let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline_theme = 'base16_gruvbox_dark_hard'
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" airline symbols
let g:airline_left_sep = ''
" let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''
let g:airline_symbols.whitespace = 'Ξ'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#whitespace#enabled = 0
let g:airline#extensions#hunks#enabled=1
let g:airline#extensions#branch#enabled = 1

function! AirlineInit()
    let g:airline_section_b = airline#section#create_left(['hunks', 'branch'])
    let g:airline_section_y = ''
endfunction
autocmd User AirlineAfterInit call AirlineInit()


" =========================== [ NERDTree Configuration ] ===========================
let NERDTreeQuitOnOpen = 1
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1

" Fix filetype for assembly
autocmd BufNewFile,BufRead *.asm,*.[sS] set filetype=asm

" ============================= [ vim-devicon Settings] =============================
let g:webdevicons_enable = 1
let g:webdevicons_enable_nerdtree = 1

" ================================== [ Deno ] ==================================


" ================================== [ DDC Configuration ] ==================================

" call ddc#custom#patch_global('completionMode', 'auto')

inoremap <silent><expr> <TAB>
\ ddc#map#pum_visible() ? '<C-n>' :
\ (col('.') <= 1 <Bar><Bar> getline('.')[col('.') - 2] =~# '\s') ?
\ '<TAB>' : ddc#map#manual_complete()

" <S-TAB>: completion back.
inoremap <expr><S-TAB>  ddc#map#pum_visible() ? '<C-p>' : '<C-h>'

call ddc#custom#patch_global('completionMenu', 'native')
call ddc#custom#patch_global('completionMode', 'manual')
call ddc#custom#patch_global('sources', ['ale', 'around', 'buffer'])

call ddc#custom#patch_filetype(['c', 'cpp'], 'sources', ['ale'])

call ddc#custom#patch_global('sourceOptions', {
            \'_': {
                \ 'matchers': ['matcher_fuzzy'],
                \ 'sorters': ['sorter_fuzzy'],
                \'converters': ['converter_fuzzy'],
                \}, 
            \'ale': {
                    \'mark': 'LSP',
                    \'maxCandidates' : 15,
                \ },
            \'clangd': {'mark': 'C'},
            \'around': {
                \'mark': 'AROUND',
                \'maxCandidates': 5,
                \},
            \'buffer': {
                \'mark': 'BUFFER',
                \'maxCandidates': 5,
                \}
            \})

call ddc#custom#patch_global('filterParams', {
            \ 'matcher_fuzzy': {
                \ 'splitMode': 'word'
                \},
            \ 'converter_fuzzy': {
                \ 'hlGroup': 'SpellBad'
                \}
            \})

call ddc#custom#patch_global('sourceParams', {
            \'ale': {
                \'cleanResultsWhitespace': v:false
                \}
            \})

" inoremap <silent><expr> <TAB>
"            \ ddc#map#pum_visible() ? '<C-n>' :
"            \ (col('.') <= 1 <Bar><Bar> getline('.')[col('.') - 2] =~# '\s') ?
"            \ '<TAB>': ddc#map#manual_complete()
" inoremap <Tab>   <Cmd>call pum#map#insert_relative(+1)<CR>
" inoremap <C-n>   <Cmd>call pum#map#insert_relative(+1)<CR>

" call popup_preview#enable()
call ddc#enable()
" ================================= [ Lightline ] =================================
if exists('g:lightline')
    let g:lightline = {
                \ 'separator': {'left': "\ue0b0", 'right': "\ue0b2"},
                \ 'component_function': {
                    \'cocstatus': 'coc#status',
                    \'filetype': 'SetupFileType',
                    \'fileformat': 'SetupFileformat'
                    \}
                \}
endif

" ==================================[ ALE Settings ]==================================
let g:ale_disable_lsp = 0
let g:ale_linters_explicit = 1
let g:ale_completion_enabled = 1
let g:ale_fixers = {
            \'*' : ['remove_trailing_lines', 'trim_whitespace']
            \}
let g:airline#extensions#ale#enabled = 1
let g:ale_detail_to_floating_preview = 1
let g:ale_set_balloons = 1
let g:ale_floating_preview = 1
let g:ale_echo_cursor = 1
let g:ale_cursor_detail = 1
let g:ale_echo_msg_error_str = 'Err'
let g:ale_echo_msg_warning_str = 'Wrn'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
let g:ale_floating_window_border = ['│', '─', '╭', '╮', '╯', '╰']

set omnifunc=ale#completion#OmniFunc



" ===================================[ IndentLine Settings]========================
"let g:indentLine_defaultGroup = 'SpecialKey'
"let g:indentLine_color_term = 239
let g:indentLine_char_list = ['|', '¦', '┆', '┊']
let g:indentLine_setColors = 0
let g:indentLine_setConceal = 0	   " Fix annoying markdown links conversion
let g:indentLine_fileTypeExclude = ['startify']
"let g:indentLine_enabled = 1

" Language Client Plugin configuration
" set rtp+=~/.vim/pack/psuit/start/LanguageClient-neovim
let g:LanguageClient_serverCommands = {
            \ 'r': ['R', '--slave', '-e', 'languageserver::run()']
            \}
"let g:LanguageClient_rootMakers = ['*.cabal', 'stack.yaml']
"let g:LanguageClient_serverCommands = { 
"			\ 'haskell': ['haskell-language-server-wrapper', '--lsp'],
"			\ 'vue': ['vls'],
"			\ 'sh': ['bash-language-server', 'start'],
"			\ 'c' : ['ccls', '--log-file=/tmp/ccls.log', '--init={"cacheDirectory":"/home/neoterux/.cache/nvim/ccls", "completion": {"filterAndSort": false}}'],
"			\ 'cpp': ['ccls', '--log-file=/tmp/ccls.log', '--init={"cacheDirectory":"/home/neoterux/.cache/nvim/ccls", "completion": {"filterAndSort": false}}']
"			\}

" ============================[ Commentary Settings ]============================


" ============================ [ NERD Commenter ] ============================
" Create default mappings
let g:NERDCreateDefaultMappings = 1

" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" Use compact syntax for prettified multi-line comments
let g:NERDCompactSexyComs = 1

" Align line-wise comment delimiters flush left instead of following code indentation
let g:NERDDefaultAlign = 'left'

" Set a language to use its alternate delimiters by default
let g:NERDAltDelims_java = 1

" Add your own custom formats or override the defaults
let g:NERDCustomDelimiters = { 'c': { 'left': '/**','right': '*/' } }

" Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDCommentEmptyLines = 1

" Enable trimming of trailing whitespace when uncommenting
let g:NERDTrimTrailingWhitespace = 1

" Enable NERDCommenterToggle to check all selected lines is commented or not 
let g:NERDToggleCheckAllLines = 1


" ============================[ Smoothie Settings ]============================
let g:smoothie_enabled = 1


hi link ALEError Error
hi Warning term=underline cterm=underline ctermfg=Yellow gui=undercurl guisp=Gold
hi link ALEWarning Warning
hi link ALEInfo SpellCap

