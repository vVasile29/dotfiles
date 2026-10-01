#!/bin/bash

export DISPLAY=:0

# Set background image for both monitors
#feh --bg-fill --randomize ~/Pictures/Wallpapers/minimalistMountains/*

# Check if external monitor is connected
if xrandr | grep -q "DP1 connected"; then
    # External monitor is connected
    xrandr --output DP1 --auto --primary --right-of eDP1
else
    # External monitor is not connected
    xrandr --output DP1 --off
    xrandr --output eDP1 --auto --primary
fi

feh --bg-fill ~/Pictures/Wallpapers/darkelch.png
#xinput map-to-output 11 eDP1
#xinput map-to-output 12 eDP1
#xinput map-to-output 17 eDP1
