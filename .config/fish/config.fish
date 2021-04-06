
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
