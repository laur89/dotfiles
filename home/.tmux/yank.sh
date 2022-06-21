#!/usr/bin/env bash
#
# from https://github.com/samoshkin/tmux-config/blob/master/tmux/yank.sh
# note it's really based on
#   https://medium.com/free-code-camp/tmux-in-practice-integration-with-system-clipboard-bcd72c62ff7b
#   and that's based on https://sunaku.github.io/tmux-yank-osc52.html
#    - ssh-tunneling bit is here: https://medium.com/hackernoon/tmux-in-practice-copy-text-from-remote-session-using-ssh-remote-tunnel-and-systemd-service-dd3c51bca1fa
#
#
# alternative: ssh port forwarding (with listener on host side): https://apple.stackexchange.com/a/258168
#
# Basically, this is a utility to handle copying from remote environments;
# will be caused by tmux and vim (and possibly others) with data to be copied.
###################################################

set -eu

is_app_installed() {
  #type "$1" &>/dev/null  # is this OSX-compatible or what?
  command -v "$1" > /dev/null 2>&1
}

# get data either form stdin or from file
buf=$(cat -- "$@")

copy_backend_remote_tunnel_port=$(tmux show-option -gvq '@copy_backend_remote_tunnel_port')

# Resolve copy backend: pbcopy (OSX), reattach-to-user-namespace (OSX), xclip/xsel (Linux)
copy_backend=''
if [[ -n "${DISPLAY-}" ]] && is_app_installed  xsel; then
  copy_backend='xsel -i --clipboard'
elif [[ -n "${DISPLAY-}" ]] && is_app_installed  xclip; then
  copy_backend='xclip -i -f -selection primary | xclip -i -selection clipboard'
elif is_app_installed  pbcopy; then
  copy_backend=pbcopy
# reattach-to-user-namespace is needed if tmux daemon doesn't have access to clipboard.
# explained in the medium article; the executable itself is from https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard
elif is_app_installed  reattach-to-user-namespace; then
  copy_backend='reattach-to-user-namespace pbcopy'

# verify ssh-tunnel setup using netstat...:
#elif [[ -n "${copy_backend_remote_tunnel_port-}" ]] \
#    && (netstat -f inet -nl 2>/dev/null || netstat -4 -nl 2>/dev/null) \
#      | grep -q "[.:]$copy_backend_remote_tunnel_port"; then
#  copy_backend="nc localhost $copy_backend_remote_tunnel_port"
# ...or alternatively, use 'ss' to check:
elif [[ -n "${copy_backend_remote_tunnel_port-}" && \
    "$(ss -n -4 state listening "( sport = :$copy_backend_remote_tunnel_port )" | tail -n +2 | wc -l)" -eq 1 ]]; then
  copy_backend="nc localhost $copy_backend_remote_tunnel_port"
fi

# if copy backend is resolved, copy and exit
if [[ -n "$copy_backend" ]]; then
  printf '%s' "$buf" | eval "$copy_backend"
  exit 0
elif [[ -z "$__REMOTE_SSH" ]]; then  # note this is our own custom addition
  exit 0

# If no copy backends were eligible, decide to fallback to OSC 52 escape sequences.
# Note, most terminals do not handle OSC
elif [[ "$(tmux show-option -gvq '@copy_use_osc52')" != on ]]; then
  exit 0
fi

###################################################
#### Only OSC 52 escape sequence logic follows ####
###################################################

# Copy via OSC 52 ANSI escape sequence to controlling terminal
buflen=$(printf '%s' "$buf" | wc -c)

# https://sunaku.github.io/tmux-yank-osc52.html
# The maximum length of an OSC 52 escape sequence is 100_000 bytes, of which
# 7 bytes are occupied by a "\033]52;c;" header, 1 byte by a "\a" footer, and
# 99_992 bytes by the base64-encoded result of 74_994 bytes of copyable text
readonly maxlen=74994

# warn if exceeds maxlen
if [[ "$buflen" -gt "$maxlen" ]]; then
  printf "input is %d bytes too long" "$(( buflen - maxlen ))" >&2
fi

# build up OSC 52 ANSI escape sequence
esc="\033]52;c;$(printf '%s' "$buf" | head -c "$maxlen" | base64 | tr -d '\r\n')\a"
esc="\033Ptmux;\033${esc}\033\\"

# resolve target terminal to send escape sequence.
# if we are on remote machine, send directly to SSH_TTY to transport escape sequence
# to terminal on local machine, so data lands in clipboard on our local machine.
target_tty="$SSH_TTY"
if [[ -z "$target_tty" ]]; then
    # we're not in remote shell, set target_tty to our active tmux pane tty:
    target_tty="$(tmux list-panes -F '#{pane_active} #{pane_tty}' | awk '$1=="1" { print $2 }')"
fi

[[ -n "$target_tty" ]] && printf -- "$esc" > "$target_tty"

