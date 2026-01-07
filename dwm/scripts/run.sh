#!/bin/sh

xrdb merge ~/.Xresources 
xbacklight -set 10 &
feh --bg-fill "/home/hectorio23/Desktop/wallpapers/Art digital/0023.png" &
xset r rate 200 50 &
picom --vsync &


dash ~/.config/dwm/scripts/bar.sh &
while type chadwm >/dev/null; do chadwm && continue || break; done
