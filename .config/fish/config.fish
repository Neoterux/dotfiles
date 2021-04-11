
### THEME CONFIGURATION
## Git Options
set -g theme_git_default_branch yes
set -g theme_git_default_branches main

## Title Options
set -g theme_title_display_process no
set -g theme_title_display_path yes
set -g theme_title_display_user no
set -g theme_title_use_abbreviated_path yes

## Prompt options
# var:
set cprompt_custom '\e[34;5;1m>\e[0m\e[5;32;1m>\e[0m\e[5;33;1m>\e[0m\e[5;31;1m>\e[0m' 
set -g theme_display_hostname yes
set -g theme_show_exit_status yes
set -g theme_newline_cursor yes
set -g theme_newline_prompt "\e[1m$cprompt_custom \e[0m" 
neofetch

### CUSTOM ALIAS
#
# alias pacman "pacman -S --needed"
alias rdir "rm -rf"
alias cpr "cp -r"
alias clear "clear ; neofetch "
#alias yay "yay -S"

# tabtab source for electron-forge package
# uninstall by removing these lines or running `tabtab uninstall electron-forge`
[ -f /home/neoterux/.npm/_npx/6913fdfd1ea7a741/node_modules/tabtab/.completions/electron-forge.fish ]; and . /home/neoterux/.npm/_npx/6913fdfd1ea7a741/node_modules/tabtab/.completions/electron-forge.fish# ghcup-env
set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME
test -f /home/neoterux/.ghcup/env ; and set -gx PATH $HOME/.cabal/bin /home/neoterux/.ghcup/bin $PATH
