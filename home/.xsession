#!/bin/sh
#
# this file is ran when xstart is executed.
#
# see https://goral.net.pl/post/systemd-x-sessions/
# also https://github.com/vincentbernat/i3wm-configuration/blob/master/dotfiles/xsession
# to auto-login, see https://vincent.bernat.ch/en/blog/2021-startx-systemd

systemctl --user import-environment
systemctl --user daemon-reload

#source "$HOME/.common_startup"

# note we add the 'wait' flag, which disallows immediate exit, which in turn would stop X session right after it.
exec systemctl --user start --wait xsession.target
