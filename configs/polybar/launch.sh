#!/usr/bin/env sh
#
# https://github.com/jaagr/polybar/wiki

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -x polybar >/dev/null; do sleep 1; done

# Launch bar(s):
polybar -r top &


echo "Bar(s) launched..."
