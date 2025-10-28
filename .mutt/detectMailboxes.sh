#!/usr/bin/env bash
#
# This script decides which mailboxes to monitor, based on system we're currently on.
#
# sourced by muttrc.
# hostnames are configured in .bash_env_vars
#
# - see also 'named-mailboxes' that takes pairs of params and allows to choose the
#   display name for each:   named-mailboxes "Work (boo!)" =work
#
########################################################################
source /etc/.global-bash-init || exit 1

########################################################################
readonly PERSONAL_BOX="$HOME/.mutt/accounts/mailboxes.personal"
readonly WORK_BOX="$HOME/.mutt/accounts/mailboxes.work"
# note as per https://github.com/neomutt/neomutt/issues/1901#issuecomment-547676531
# the fake separator-dirs need to exist:
readonly WORK_BOX_SEPARATOR="\nmailboxes +work/--------------"
########################################################################

if is_work; then
    commands="$(cat -- "$WORK_BOX")"
    #commands+="$PERSONAL_BOX_SEPARATOR"
    #commands="$(cat -- "$PERSONAL_BOX")"
    commands+="\nset spool_file = +work/Inbox"
#elif ! is_laptop; then
    #commands="$(cat -- "$PERSONAL_BOX")"
else
    # select all
    commands="$(cat -- "$PERSONAL_BOX")"
    if [[ -d "$HOME/mail/work" && -s "$WORK_BOX" ]]; then
        commands+="$WORK_BOX_SEPARATOR"
        commands+="$(cat -- "$WORK_BOX")"
    fi
    commands+="\nset spool_file = +personal/INBOX"
fi

echo -e "$commands"

