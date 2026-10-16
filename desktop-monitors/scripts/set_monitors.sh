#!/bin/sh
set -eu

# This desktop: portrait left, primary landscape middle, landscape right.
# Use each output's highest reported refresh rate at 2560x1440.
# Inherit DISPLAY/XAUTHORITY from the Awesome session; do not hardcode them.
outputs=$(xrandr --query)
for output in HDMI-A-0 DisplayPort-2 DisplayPort-1; do
    if ! printf '%s\n' "$outputs" | grep -q "^${output} connected"; then
        printf 'Monitor %s is not connected; leaving the layout unchanged.\n' "$output" >&2
        exit 1
    fi
done

# Pass --dryrun to check the requested configuration without applying it.
exec xrandr "$@" \
    --output HDMI-A-0 --mode 2560x1440 --rate 59.95 --rotate left --pos 0x0 \
    --output DisplayPort-2 --mode 2560x1440 --rate 74.92 --rotate normal --primary --pos 1440x473 \
    --output DisplayPort-1 --mode 2560x1440 --rate 74.92 --rotate normal --pos 4000x473
