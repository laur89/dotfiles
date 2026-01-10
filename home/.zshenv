#!/bin/zsh
# from https://github.com/marlonrichert/zsh-launchpad/blob/main/.zshenv
# other dotfile sources to check out:
# - https://github.com/KulkarniKaustubh/dotfiles/blob/main/zsh/.zshrc
# - https://github.com/infokiller/config-public/blob/master/.config/zsh/.zshenv

# see https://unix.stackexchange.com/questions/72559/how-to-avoid-parsing-etc-files
#
# also note per https://unix.stackexchange.com/questions/685504/what-sources-etc-profile#comment1295426_685505 :
# > /etc/profile is used by all Bourne-shell compatible shells - including bash, ash, dash, ksh, and zsh
# This statement however is contradicted by https://unix.stackexchange.com/a/537829/47501 :
# > If you want zsh to source /etc/profile when in login mode, you'd need to add a...
#
# https://www.madhur.co.in/blog/2023/05/10/zsh-and-etc-profile.html also states a
# case where bunch of shit from /etc/profile* was not sourced, so emulation was
# needed in /etc/zsh/zprofile
#
# see also docs for config sourcing: https://zsh.sourceforge.io/Doc/Release/Files.html#index-NO_005fGLOBAL_005fRCS_002c-use-of
setopt no_global_rcs

##
# This file, .zshenv, is the first file sourced by zsh for EACH shell, whether
# it's interactive or not.
# This includes non-interactive sub-shells!
# So, put as little in this file as possible, to avoid performance impact.
#

# Note: The #!/bin/zsh shebang is strictly necessary for executable scripts
# only, but without it, you might not always get correct syntax highlighting
# when viewing the code.

# By default, Zsh will look for dotfiles in $HOME (and find this file), but
# once $ZDOTDIR is defined, it will start looking in that dir instead.
ZDOTDIR=${XDG_CONFIG_HOME:=~/.config}/zsh
# alternatively set ZSHENV_DIR to the directory of this file after resolving symlinks,
# which should normally point at "${XDG_CONFIG_HOME}/zsh":
#ZSHENV_DIR="${${${(%):-%x}:P}:h}"
#export ZDOTDIR="${ZDOTDIR:-${ZSHENV_DIR}}"

# ${X:=Y} specifies a default value Y to use for parameter X, if X has not been
# set or is null. This will actually create X, if necessary, and assign the
# value to it.
# To set a default value that is returned *without* setting X, use ${X:-Y}
# instead.
# As in other shells, ~ expands to $HOME _at the beginning of a value only._

# Disable Ubuntu's global compinit call in /etc/zsh/zshrc, which slows down
# shell startup time significantly; see https://github.com/zdharma-continuum/zinit#disabling-system-wide-compinit-call
# Note that this doesn't have an effect when NO_GLOBAL_RCS is set, but can't hurt:
skip_global_compinit=1

# commented out, as also set in ~/.profile:
#umask 0077  # keep this in sync with what we set via systemd!
