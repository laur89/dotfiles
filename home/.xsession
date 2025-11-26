#!/usr/bin/env sh
############################
# from https://github.com/infokiller/config-public/blob/master/.xsession
# this file is ran when startx is executed.
# some documentation: https://wiki.debian.org/Xsession
#
# note it's possible, at least on Debian, that this file would not get executed if
# ~/.xsessionrc exists; see https://wiki.debian.org/Xsession#User_configuration
############################

# This file is usually sourced from the display manager (at least this is the
# case with LightDM). However, the xsession script assumes it's executed in
# bash, and the display manager may use another shell. In addition, some things
# are better when the script is executed in isolation- for example, reported
# line numbers. Therefore, the actual xsession is executed from this script,
# where it will be executed in an isolated and guaranteed bash environment.
exec "$HOME/.xsession_real" "$@"
#exec urxvt

