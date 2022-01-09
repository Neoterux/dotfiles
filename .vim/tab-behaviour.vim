" more info at: https://stackoverflow.com/questions/1878974/redefine-tab-as-4-spaces


" Haskell tab configuration
autocmd Filetype haskell,lhaskell setlocal tabstop=2 shiftwidth=3 softtabstop=2 expandtab smarttab


" python tab configuration
autocmd Filetype python setlocal tabstop=4 shiftwidth=4 softtabstop=4

" C/C++ tab configuration

autocmd Filetype c,cpp setlocal tabstop=4 shiftwidth=4 softtabstop=0 expandtab smarttab

autocmd Filetype c,cpp setlocal equalprg=clang-format

"augroup rainbow_lisp
"	autocmd!
"	autocmd FileType c,cpp RainbowParentheses
"augroup END
