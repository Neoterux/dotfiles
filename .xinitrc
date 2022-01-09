#!/bin/sh

[-f /etc/xprofile ] && . /etc/xprofile
[-f ~/.xprofile ] && . ~/.xprofile

## Setup keyboard layout
setxkbmap us intl-unicode &

# Script to fix screen settings
$HOME/.config/config_monitors &

feh --bg-scale /home/neoterux/Pictures/wallpaper.png &

# Compositor 
picom --config ~/.config/picom/picom.conf &

#
# Xmonad
#

xmobar &
exec xmonad

#
# Bspwm
# 

# exec bspwm

