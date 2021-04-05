call plug#begin('~/.vim/plugged')
 	
	Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
	Plug 'neoclide/coc.nvim', {'branch': 'release'}
	Plug 'arcticicestudio/nord-vim'
	Plug 'preservim/nerdtree'
	Plug 'townk/vim-autoclose'
	Plug 'ryanoasis/vim-devicons'
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
	Plug 'chrisbra/csv.vim'
	Plug 'vim-scripts/DoxygenToolkit.vim'
	Plug 'zchee/deoplete-clang'
	Plug 'nathanaelkane/vim-indent-guides'
	Plug 'udalov/kotlin-vim'
	Plug 'ncm2/ncm2'
	Plug 'roxma/nvim-yarp'
	Plug 'ncm2/ncm2-path'
	Plug 'ncm2/ncm2-syntax'
	Plug 'ncm2/ncm2-pyclang'
	Plug 'ObserverOfTime/ncm2-jc2'
	Plug 'ncm2/ncm2-jedi'
	Plug 'ncm2/ncm2-tern'
	Plug 'ncm2/ncm2-cssomni'
	Plug 'ncm2/ncm2-ultisnips'



call plug#end()

"execute pathogen#infect()

"Use nord-vim theme"
colorscheme monokai


" --- AIRLINE CONFIG
"let g:airline_section_b = '%{strftime("%c")}'

let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline_theme = 'base16_gruvbox_dark_hard'

" --- NERDTREE CONFIG
" - Start NERDTree. If a file is specified, move the cursor to its window.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif
" - Show hidden files
let NERDTreeShowHidden = 0

" Custom icons for expandable/expanded directories
let g:NERDTreeDirArrowExpandable = '⬏'
let g:NERDTreeDirArrowCollapsible = '⬎'

" Hide certain files and directories from NERDTree
let g:NERDTreeIgnore = ['^\.DS_Store$', '^tags$', '\.git$[[dir]]', '\.idea$[[dir]]', '\.sass-cache$']

" --- NEOVIM CONFIGURATION"

"Activate line number"
set number
set t_Co=256
set encoding=UTF-8
set ruler
set incsearch
set cursorline

syntax on

set mouse=a

" --- DoxygenToolkit config
"
let g:DoxygenToolkit_briefTag_pre="@Synopsis  "
let g:DoxygenToolkit_paramTag_pre="@Param "
let g:DoxygenToolkit_returnTag="@Returns   "
let g:DoxygenToolkit_blockHeader="-------------------------------"
let g:DoxygenToolkit_blockFooter="---------------------------------"
let g:DoxygenToolkit_authorName="Neoterux"

" --- NCM2 Config
 " enable ncm2 for all buffers
    autocmd BufEnter * call ncm2#enable_for_buffer()
    set completeopt=noinsert,menuone,noselect
