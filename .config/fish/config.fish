
### THEME CONFIGURATION
## Git Options
set -g theme_display_git yes
set -g theme_git_default_branches master main
set -g theme_display_git_default_branch yes
#set -g theme_git_worktree_support yes
set -g theme_display_git_dirty yes
set -g theme_display_git_untracked yes


# Function to generate random

## Title Options
set -g theme_title_display_process no
set -g theme_title_display_path yes
set -g theme_title_display_user no
set -g theme_title_use_abbreviated_path yes

## Prompt options
# var:
# Icons by nerd font
set icons '\uf2dc' '\uf096' '\ue266' '\ue272' '\ue24f'
set rd_icon "\e[36;147m["(printf $icons[(random 1 5)])"]\e[0m"
set cprompt_custom '\e[34;5;1m>\e[0m\e[5;32;1m>\e[0m\e[5;33;1m>\e[0m\e[5;31;1m>\e[0m' 
set -g theme_display_hostname yes
set -g theme_show_exit_status yes
set -g theme_newline_cursor yes
# set -g theme_newline_prompt "\e[1m$rd_icon$cprompt_custom \e[0m" 
set -g theme_newline_prompt "\e[1m$rd_icon$cprompt_custom \e[0m"

#
### CUSTOM ENV VARS
set AOCL_AOCC_LIB /opt/aocl-aocc/lib/
set AOCL_GCC_LIB /opt/aocl-gcc/lib
set AOCL_AOCC_INC /opt/aocl-aocc/include
set AOCL_GCC_INC /opt/aocl-gcc/include
set AOCC_LIBS /opt/aocc/lib
set AOCC_INC /opt/aocc/include
set AOCC_BIN /opt/aocc/bin

### CUSTOM ALIAS
#
# alias pacman "pacman -S --needed"
alias rdir "rm -rf"
alias cpr "cp -r"
# alias clear "clear ; neofetch "
alias ss "~/./launch_flameshot.sh"
alias yayi "yay -S"
alias upkgs "yay -Syyu ; sudo pacman -Syyu"
alias parui "paru -S"

# tabtab source for electron-forge package
# uninstall by removing these lines or running `tabtab uninstall electron-forge`
#[ -f /home/neoterux/.npm/_npx/6913fdfd1ea7a741/node_modules/tabtab/.completions/electron-forge.fish ]; and . /home/neoterux/.npm/_npx/6913fdfd1ea7a741/node_modules/tabtab/.completions/electron-forge.fish# ghcup-env
#set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME
#test -f /home/neoterux/.ghcup/env ; and set -gx PATH $HOME/.cabal/bin /home/neoterux/.ghcup/bin $PATH

# neofetch

#### C/C++ Flags
set -x CFLAGS "-march=znver3 -mtune=znver3 -O2 -pipe -ftree-vectorize -Wall"
set -x CXXFLAGS "$CFLAGS"

### ALIASES
alias ghcd="ghc -dynamic "
alias ssh="kitty +kitten ssh"
alias rankpkg="sudo sh -c 'rankmirrors -n 30 /etc/pacman.d/mirrorlist.pacnew > /etc/pacman.d/mirrorlist'"
alias ipac="sudo pacman -S"
alias qmk="CFLAGS='' CXXFLAGS='' LDFLAGS='' ~/.local/bin/qmk"

### Custom Path additions
set -x PATH $PATH "$HOME/.cabal/bin" "$HOME/.ghcup/bin" "$HOME/.stack/bin" "$HOME/.local/bin" "/lib/jvm/default/bin" "~/.local/share/gem/ruby/3.0.0/bin"

## Proton especific Variables
set -x STEAM_COMPAT_DATA_PATH ~/.proton
set -x STEAM_COMPAT_CLIENT_INSTALL_PATH ~/.local/share/Steam
alias proton="~/.steam/steam/steamapps/common/Proton\ -\ Experimental/proton"
alias icat="kitty +kitten icat"



#### Environment variables
set -x PKG_CONFIG_PATH $PKG_CONFIG_PATH "/usr/lib/pkgconfig" "/usr/share/pkgconfig"

### Keyring [GNOME]
#if test -n "$DESKTOP_SESSION"
#    set -x (gnome-keyring-daemon --start | string split "=")
#end
set -x GCM_CREDENTIAL_STORE secretservice
