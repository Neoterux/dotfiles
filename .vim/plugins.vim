set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()

" Syntax
Plugin 'junegunn/fzf'
Plugin 'neovimhaskell/haskell-vim'
Plugin 'posva/vim-vue'
Plugin 'cespare/vim-toml'
" Plugin 'sheerun/vim-polyglot'
"Plugin 'octol/vim-cpp-enhanced-highlight'
Plugin 'jackguo380/vim-lsp-cxx-highlight'
Plugin 'shirk/vim-gas'
" Plugin 'jeaye/color_coded'

" Vundle manage Vundle
Plugin 'VundleVim/Vundle.vim'

" Themes & Visual
Plugin 'morhetz/gruvbox'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'ryanoasis/vim-devicons'
Plugin 'stevearc/dressing.nvim'
Plugin 'xuyuanp/nerdtree-git-plugin'

" Tmux
Plugin 'benmills/vimux'

" Addons
Plugin 'scrooloose/nerdtree'
Plugin 'tibabit/vim-templates'
Plugin 'tpope/vim-surround'
Plugin 'jiangmiao/auto-pairs'
Plugin 'psliwka/vim-smoothie'
Plugin 'tani/ddc-fuzzy'
Plugin 'matsui54/denops-popup-preview.vim'
Plugin 'statiolake/ddc-ale'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'
Plugin 'Shougo/pum.vim'

" IDE like plugins
Plugin 'dense-analysis/ale'
Plugin 'Shougo/ddc-around'
Plugin 'Shougo/ddc-matcher_head'
Plugin 'matsui54/ddc-buffer'
Plugin 'Shougo/ddc-sorter_rank'
Plugin 'vim-denops/denops.vim'
Plugin 'Shougo/ddc.vim'
Plugin 'preservim/nerdcommenter'
Plugin 'Yggdroot/indentLine'
Plugin 'mattn/emmet-vim'
Plugin 'preservim/tagbar'
if has('nvim')
    Plugin 'neovim/nvim-lsp'
    Plugin 'neovim/nvim-lspconfig'

endif

" This is a test surround

" Git
Plugin 'tpope/vim-fugitive'
Plugin 'mhinz/vim-signify'
Plugin 'airblade/vim-gitgutter'

" Other
Plugin 'mhinz/vim-startify'
Plugin 'editorconfig/editorconfig-vim'
call vundle#end()

lua << EOF
require'nvim_lsp'.ccls.setup{

}
EOF
