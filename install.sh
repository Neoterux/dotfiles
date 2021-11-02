#!/bin/sh

BASEDIR=$(pwd)

echo "This script would remove previus existing files and folders"
read -p "Are you  secure that would continue [y/N]: " del_all
del_all=$(echo "${del_all,,}")

if [[ $del_all == "y" ]]
then
rm -rf ~/.vim
rm ~/.vimrc

# Install vim configuration files
echo "installing .vim directory"
ln -s $BASEDIR/.vim ~/.vim
echo "installing .vimrc file"
ln -s $BASEDIR/.vimrc ~/.vimrc


# TODO: install fish, zsh, etc

else
echo "This script does nothing"
fi