" Author        : Neoterux
" Created       : 11/12/2021
" License       : MIT
" Description   :  Haskell ftplugin configuration

let b:ale_linters = ['cabal_ghc', 'stack_ghc', 'hls', 'hlint']

let b:ale_fixers = ['hlint']
let b:ale_preview = 1
let b:ale_cursor_detail = 1

let g:haskell_enable_quantification = 1   " to enable highlighting of `forall`
let g:haskell_enable_recursivedo = 1      " to enable highlighting of `mdo` and `rec`
let g:haskell_enable_arrowsyntax = 1      " to enable highlighting of `proc`
let g:haskell_enable_pattern_synonyms = 1 " to enable highlighting of `pattern`
let g:haskell_enable_typeroles = 1        " to enable highlighting of type roles
let g:haskell_enable_static_pointers = 1  " to enable highlighting of `static`
let g:haskell_backpack = 1                " to enable highlighting of backpack keywords
let g:haskell_indent_if = 3
let g:haskell_indent_case = 2
let g:haskell_indent_let = 4
