#!/usr/bin/env bash
# base from http://mrtango.planetcrazy.de/dynamic-screen-definitions-in-i3wm.html

SCRIPT_DIR="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
DIR_UP="$(dirname -- "$SCRIPT_DIR")"
#####################################

# import common:
if ! type __COMMONS_LOADED_MARKER > /dev/null 2>&1; then
    if [[ -r "$_SCRIPTS_COMMONS" ]]; then
        source "$_SCRIPTS_COMMONS"
    else
        echo -e "\n    ERROR: common file [$_SCRIPTS_COMMONS] not found! Abort."
        exit 1
    fi
fi

###############

report "dir is [$SCRIPT_DIR]"
#### Entry ####
"$SCRIPT_DIR"/gen-conf.sh > "$DIR_UP"/config.d/10-generated || exit 1
update-conf.py -f "$DIR_UP"/config || exit 1

exit 0

