set number
set mouse=a
set numberwidth=1
set clipboard=unnamed
syntax on
set showcmd
set showmatch
set ruler
set cursorline
set smarttab
set smartcase
set smartindent
set shiftwidth=2
set encoding=utf-8
set sw=2
set relativenumber
set signcolumn=yes
set termguicolors
filetype plugin indent on

" Vim plugin declaration file
so ~/.vim/plugins.vim
" Vim plugin configuration files
so ~/.vim/plugin-config.vim
" Vim key mapping file
so ~/.vim/maps.vim

colorscheme gruvbox
" colorscheme bat

let g:gruvbox_contrast_dark = "hard"

highlight Normal ctermbg=NONE
set laststatus=2
set noshowmode

"" Search
set hlsearch 	" higlight matches
set incsearch 	" incremental searching
set ignorecase 	" search case insensitive

" [Unknown]
hi keyword ctermfg=darkcyan
hi Constant ctermfg=5*
hi Comment ctermfg=2*
hi Normal ctermbg=none
hi LineNr ctermfg=darkgrey
