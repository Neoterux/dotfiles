#!/usr/bin/sh

SCRIPT=$(readlink -f $0)
DOTFILES=$(dirname "$SCRIPT")

# Deleting previous files that could exists in the home directory

rm -rf $HOME/.vim 2> /dev/null

rm $HOME/.vimrc 2> /dev/null

# Now we make a link to the home directory
echo "Copying files from $DOTFILES to $HOME"

echo "linking .vimrc file"
ln -s $DOTFILES/.vimrc $HOME/.vimrc
echo "linking .vim directory"
ln -s $DOTFILES/.vim  $HOME/.vim
# in case that not exists .config
mkdir -p $HOME/.config
echo "linking nvim config files"
ln -s $DOTFILES/.config/nvim $HOME/.config/nvim

echo "Installing Vim-Plug"
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'


