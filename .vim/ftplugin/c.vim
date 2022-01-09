let b:ale_fixers = ['clang-format', 'astyle']

let b:ale_linters = ['ccls'] "'clangd', 'cc']
aksdjfl
" let g:ale_lint_on_text_changed = 'always'

let g:ale_c_cc_options = '-std=c11 -Wpendatic -Wall -march=znver3 -mtune=znver3'
let g:ale_cpp_cc_options = '-std=c++14 -Wall -Wpendatic -pendatic -march=znver3 -mtune=znver3'

let g:ale_cpp_ccls_init_options = {
            \ 'cache': {
                \'directory': '/tmp/ccls/cache'
                \},
                \'clang':{
                \ 'extraArgs': ['-march=znver3', '-mtune=znver3', '-std=gnu11', '-Wall']
                \}
            \}
" call ddc#custom#patch_global('completionMenu', 'native')
" call ddc#custom#patch_global('completionMode', 'manual')
" call ddc#custom#patch_filetype(['c', 'cpp'], 'sources', ['ale', 'clangd'])
"call ddc#custom#patch_filetype(['c', 'cpp'], 'sourceOptions', {
"             \'clangd': {'mark': 'C'}
"             \})
syntax match cType "\<[a-zA-Z_][a-zA-Z0-9_]*_[ft]\>"
let g:ale_fix_on_save = 0
let g:ale_cursor_detail = 1

" augroup ale_hover_cursor
"    autocmd!
"    autocmd CursorHold * ALEHover
"augroup END

" Custom remaps
