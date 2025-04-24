#!/usr/bin/env bash
# base from http://mrtango.planetcrazy.de/dynamic-screen-definitions-in-i3wm.html
#
# Note this script's stdout will be set as i3 config file!
#####################################

source /etc/.global-bash-init || exit 1
###############


#### Entry ####
echo '# vim:filetype=i3'
echo '#'
echo "set \$hostname $HOSTNAME"
xrandr --listactivemonitors | awk '$1 ~ /^0/ {print "set $mainscreen " $4}'
xrandr --listactivemonitors | awk '$1 ~ /^1/ {print "set $sidescreen " $4}'

exit 0

