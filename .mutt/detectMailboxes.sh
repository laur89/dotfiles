#!/bin/bash

#work_hostname=WHOD5001556
#personal_hostname=aliste
personalBox=~/.mutt/accounts/mailboxes.personal
workBox=~/.mutt/accounts/mailboxes.work
boxSeparator="mailboxes +work/--------------"
commands=

if [[ "$HOSTNAME" == "$WORK_DESKTOP_HOSTNAME" ]]; then
    commands="$(cat $workBox)"
elif [[ "$HOSTNAME" == "$PERSONAL_DESKTOP_HOSTNAME" ]]; then
    commands="$(cat $personalBox)"
else
    # select all
    commands="$(cat $personalBox)"
    commands+="$boxSeparator"
    commands+="$(cat $workBox)"
    # override spool:
    commands+="set spoolfile = +gmail/INBOX # default inbox; so-called startup folder"
fi

echo -e "$commands"

