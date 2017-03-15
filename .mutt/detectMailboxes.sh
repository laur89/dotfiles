#!/bin/bash
#
# This script decides which mailboxes to monitor, based on system we're currently on.
#
# sourced by muttrc.
# hostnames are configured in .bash_env_vars
#
########################################################################
# env vars import has to be the first thing:
if [[ "$__ENV_VARS_LOADED_MARKER_VAR" != "loaded" ]]; then
    USER_ENVS=/etc/.bash_env_vars

    if [[ -r "$USER_ENVS" ]]; then
        source "$USER_ENVS"
    else
        echo -e "\n    ERROR: env vars file [$USER_ENVS] not found! Abort."
        #exit 1  # TODO: exit?
    fi
fi

# import common:
if ! type __COMMONS_LOADED_MARKER > /dev/null 2>&1; then
    if [[ -r "$_SCRIPTS_COMMONS" ]]; then
        source "$_SCRIPTS_COMMONS"
    else
        echo -e "\n    ERROR: common file [$_SCRIPTS_COMMONS] not found or isn't readable! Abort."
        exit 1
    fi
fi

########################################################################
personalBox=~/.mutt/accounts/mailboxes.personal
workBox=~/.mutt/accounts/mailboxes.work
boxSeparator="mailboxes +work/--------------"
commands=
########################################################################

if is_work; then
    commands="$(cat -- "$workBox")"
elif [[ "$HOSTNAME" == "$PERSONAL_DESKTOP_HOSTNAME" ]]; then
    commands="$(cat -- "$personalBox")"
else
    # select all
    commands="$(cat -- "$personalBox")"
    commands+="$boxSeparator"
    commands+="$(cat -- "$workBox")"
    # override spool:
    commands+="set spoolfile = +gmail/INBOX  # default inbox; so-called startup folder"
fi

echo -e "$commands"

