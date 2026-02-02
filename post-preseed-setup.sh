#!/usr/bin/env bash
#
# To be executed from preseed like:
#    in-target wget -qO- https://github.com/laur89/dotfiles/raw/master/post-preseed-setup.sh | /bin/bash
#
# !!! careful with renaming this file, as it's referenced from preseed script !!!
#
# reason why we want our sources to be set up prior to running bootstrap logic,
# is some dependencies might not be avail in testing repos but in unstable, so
# bootstrap's dependency check & install will already fail, as unstable/sid
# sources have not yet been set up by that moment.
#
# note this is effectively same as setup_apt() in our bootstrap script
setup_apt() {
    install -Tm644 <(wget -qO- 'https://github.com/laur89/dotfiles/raw/master/backups/apt_conf/00-main.pref') \
        /etc/apt/preferences.d/00-main.pref
    install -Tm644 <(wget -qO- 'https://github.com/laur89/dotfiles/raw/master/backups/apt_conf/debian.sources') \
        /etc/apt/sources.list.d/debian.sources

    # update index so new sources are made avail:
    apt-get update
}

setup_apt
exit 0  # note we don't want this script to ever exit erroneously
