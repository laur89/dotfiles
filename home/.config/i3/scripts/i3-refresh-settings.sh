#!/usr/bin/env bash
#
# base from http://mrtango.planetcrazy.de/dynamic-screen-definitions-in-i3wm.html
#####################################

readonly SELF=${0##*/}
#####################################
source /etc/.global-bash-init || exit 1

#SCRIPT_DIR="$(resolve_real_path "${BASH_SOURCE[0]}")"  # resolves to ~/.homesick/repos/...
SCRIPT_DIR="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"  # resolves to ~/.config/...  -- in this case this is what we want!
DIR_UP="$(dirname -- "$SCRIPT_DIR")"

report "execution dir is [$SCRIPT_DIR]" "$SELF"

"$SCRIPT_DIR/gen-conf.sh" >| "$DIR_UP/config.d/10-generated.i3config" || exit 1
update-conf.py -f "$DIR_UP/config" || exit 1

exit 0

