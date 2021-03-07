#!/usr/bin/env bash
# base from http://mrtango.planetcrazy.de/dynamic-screen-definitions-in-i3wm.html

SCRIPT_DIR="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
DIR_UP="$(dirname -- "$SCRIPT_DIR")"
#####################################

source /etc/.global-bash-init
_init || exit 1
###############

report "dir is [$SCRIPT_DIR]"
#### Entry ####
"$SCRIPT_DIR"/gen-conf.sh > "$DIR_UP"/config.d/10-generated || exit 1
update-conf.py -f "$DIR_UP"/config || exit 1

exit 0

