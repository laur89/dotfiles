#!/bin/zsh
# from https://github.com/marlonrichert/zsh-launchpad/blob/main/.zshenv
# other dotfile sources to check out:
# - https://github.com/KulkarniKaustubh/dotfiles/blob/main/zsh/.zshrc

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
#ZDOTDIR=${XDG_CONFIG_HOME:=~/.config}/zsh

# ${X:=Y} specifies a default value Y to use for parameter X, if X has not been
# set or is null. This will actually create X, if necessary, and assign the
# value to it.
# To set a default value that is returned *without* setting X, use ${X:-Y}
# instead.
# As in other shells, ~ expands to $HOME _at the beginning of a value only._
