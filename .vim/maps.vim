let mapleader = " "

" split resize
nnoremap <Leader>> 10<C-w>>
nnoremap <Leader>< 10<C-w><

" quick command
" save/quit
nnoremap <Leader>w :w<CR>
nnoremap <Leader>q :q<CR>

" shorter commands
cnoreabbrev tree NERDTreeToggle
cnoreabbrev diff Gdiff
cnoreabbrev fzf FZF

" Tagbar key maps
nmap <F6> :TagbarToggle<CR>

" fuzzy finder maps
nnoremap <F5> :FZF<CR>

" IDE like mapping
nnoremap <Tab> >>_
nnoremap <S-Tab> <<_
inoremap <S-Tab> <C-D>
vnoremap <Tab> >gv
vnoremap <S-Tab> <gv

inoremap <silent> <C-Space> <C-\><C-O>:ALEComplete<CR>
imap <C-Space> <Plug>(ale_complete)
" inoremap <Leader>d :t.<CR>
nnoremap <Leader>d :t.<CR>
" Remap keys for gotos
" nmap <silent> gd <Plug>(coc-definitions)
" nmap <silent> gy <Plug>(coc-type-definitions)
" nmap <silent> gi <Plug>(coc-implementation)
" nmap <silent> gr <Plug>(coc-references)

" Maps for completition
" if has("nvim")
" 	inoremap <silent><expr><c-space> coc#refresh()
" else
" 	inoremap <silent><expr> <c-@> coc#refresh()
" endif
" autocmd CursorHold * silent call CocActionAsync('highlight')
"
" Symbol renaming
nmap <leader>rn <Plug>(ale_rename)
xmap <Leader>r <Plug>(ale_rename)

" formatting
xmap <Leader>f :ALEFix<CR>
nmap <Leader>f :ALEFix<CR>

" Remap for Language Client plugin
" nnoremap <F5> :call LanguageClient_contextMenu()<CR>
" map <Leader>lk :call LanguageClient#textDocument_hover()<CR>
" map <Leader>lg :call LanguageClient#textDocument_definition)<CR>
" map <Leader>lf :call LanguageClient#textDocument_formatting()<CR>

" Special character insertion
inoremap <C-~>  ` `<CR>

" NERDTree toggle map
map <silent> <Leader>t :NERDTreeToggle<CR>

" ============================ [ SPECIAL FUNCTIONS/MAPS ] ============================
set splitright
function! OpenTerminal()
	" move to right most buffer
	execute "normal \<C-l>"
	execute "normal \<C-l>"
	execute "normal \<C-l>"
	execute "normal \<C-l>"

	let bufNum = bufnr("%")
	let bufType = getbufvar(bufNum, "&buftype", "not found")
	if bufType == "terminal"
		" close existing terminal
		execute "q"
	else 
		"open terminal
		execute "vsp term://$SHELL"
		execute "set nonu"
		execute "set nornu"

		" toggle insert on enter/exit
		silent au BufLeave <buffer> stopinsert!
		silent au BufWinEnter,WinEnter <buffer> startinsert!

		" Set maps inside terminal buffer
		execute 'tnoremap <buffer> <C-h>  <C-\\><C-n><C-w><C-h>'
		execute 'tnoremap <buffer> <C-t>  <C-\\><C-n>:q<CR>'
		execute 'tnoremap <buffer> <C-\\><C-\\>  <C-\\><C-n>'

		startinsert!

	endif
endfunction

nnoremap <C-t> :call OpenTerminal()<CR>
