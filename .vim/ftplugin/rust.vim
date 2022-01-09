" Author        : Neoterux
" Created       : 13/12/2021
" License       : MIT
" Description   : 

let b:ale_linters = ['cargo', 'rustc', 'rls']

let b:ale_fixers = ['rustfmt', 'remove_trailing_lines', 'trim_whitespace']
let g:ale_rust_rls_toolchain = 'stable'
let g:ale_sign_error = '✗'
let g:ale_sign_warning = ' '

inoremap <silent><expr><TAB>
    \ pumvisible() ? “\<C-n>” : “\<TAB>”

set omnifunc=ale#completion#OmniFunc
