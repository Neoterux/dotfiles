" Pre load setting
let g:polyglot_disabled = ['noexpandtab']
"Load Plugins
so ~/.vim/plugins.vim

set number                                          " Enable the number column
set mouse=a                                         " Enable mouse scrolling
set numberwidth=2                                   " Set the minimum width of the number col
set clipboard+=unnamedplus                          " Use system clipboard by default
syntax on                                           " Enable syntax highlight
set noshowcmd                                       " get rid of display of last command
set showmatch                                       " Show the matched pair of brackets
set ruler                                           " Show the column & row position of the cursor
set title                                           " Tab title asfile name
set noshowmode                                      " Dont show current mode below statusline
set tabstop=4 softtabstop=4 shiftwidth=4 autoindent " Tab widths
set expandtab smarttab                              " Tab key actions
set wrap breakindent                                " wrap long lines to the width set by tw
set conceallevel=2                                  " This is to not break the indentation plugin
set tw=90                                           " Auto wrap lines that are longer to that
set emoji                                           " Enable emoji
set backspace=indent,eol,start                      " Sensible backspacing
set undodir=/tmp                                    " Undo temp file directory
set foldlevel=0                                     " Open all folds by default
set inccommand=nosplit                              " visual feedback while substituting
set showtabline=0                                   " Always show tabline
set shiftround                                      " round indent to multiple of 'shiftwidth'
set encoding=utf-8                                  " Set the deault encoding as utf-8
" set termguicolors                                   " Opaque background
set signcolumn=auto:1                               " Set the warning/error sign column  width
set fillchars+=vert:\                               " Requires patched nerd font
set undofile                                        " Enable persistent undo
set list listchars=eol:,trail:»,tab:\|\-           " Use to navigate in list mode
set incsearch ignorecase smartcase hlsearch         " Highlight text while search
set cursorline
filetype plugin indent on

" Performance
" set nocursorcolumn
set scrolljump=5
set lazyredraw
set redrawtime=10000
set synmaxcol=180
set re=1

" CoC required configuration
"set hidden
"set nobackup
"set nowritebackup
"set cmdheight=1
"set updatetime=300
"set shortmess+=c
" set signcolumn=yes

" Vim plugin configuration files
so ~/.vim/plugin-config.vim
" Vim key mapping file
so ~/.vim/maps.vim
" Vim tab configuration by Filetype
so ~/.vim/tab-behaviour.vim

" Theme configuration
colorscheme gruvbox

" Pop-up menu color
hi Pmenu guibg=#00010a guifg=white ctermbg=239
" Italic comment
hi Comment gui=italic cterm=italic
" Search string highlight color
hi Search guibg=#b16286 guifg=#ebdbb2 gui=bold cterm=bold 
" Clear  color on current line
" hi clear CursorLineNr
" Add background to line number col
hi LineNr ctermbg=235 guibg=#202020 guifg=#cacaca
hi SignColumn guibg=#202020 ctermbg=235
" Make Current line number bold
hi CursorLineNr gui=bold term=bold cterm=bold

" Mispelled words
hi SpellBad guifg=NONE gui=bold,undercurl cterm=bold,undercurl


" let g:gruvbox_contrast_dark = "hard"

highlight Normal ctermbg=NONE
set laststatus=2

" [Unknown]
" hi keyword ctermfg=darkcyan
" hi Constant ctermfg=5*
" hi Comment ctermfg=2*
" hi Normal ctermbg=none
" hi LineNr ctermfg=Grey ctermbg=237 guifg=#aaaaaa gui=bold

" [ALE]
packloadall
silent! helptags ALL
