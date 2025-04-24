#!/usr/bin/env bash
#
# This script decides which mailboxes to monitor, based on system we're currently on.
#
# sourced by muttrc.
# hostnames are configured in .bash_env_vars
#
########################################################################
source /etc/.global-bash-init || exit 1

########################################################################
readonly PERSONAL_BOX=~/.mutt/accounts/mailboxes.personal
readonly WORK_BOX=~/.mutt/accounts/mailboxes.work
readonly WORK_BOX_SEPARATOR="\nmailboxes +work/--------------"
########################################################################

if is_work; then
    commands="$(cat -- "$WORK_BOX")"
    #commands+="$PERSONAL_BOX_SEPARATOR"
    #commands="$(cat -- "$PERSONAL_BOX")"
    commands+="\nset spoolfile = +work/Inbox"
#elif ! is_laptop; then
    #commands="$(cat -- "$PERSONAL_BOX")"
else
    # select all
    commands="$(cat -- "$PERSONAL_BOX")"
    commands+="$WORK_BOX_SEPARATOR"
    commands+="$(cat -- "$WORK_BOX")"
    commands+="\nset spoolfile = +personal/INBOX"
fi

echo -e "$commands"

