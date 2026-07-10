
# other shell completions:
# use this if grep w/ perl regex not avail:
#[[ -f ~/.ssh/config ]] && complete -o default -o nospace -W "$(grep -i -e '^host ' ~/.ssh/config | awk '{print substr($0, index($0,$2))}' ORS=' ')" sshpearl
#
[[ -f ~/.ssh/config ]] && complete -o default -o nospace -W "$(grep -Poi '^host\s+\K\S+' ~/.ssh/config | grep -vFx '*')" sshpearl


# cd-s to directory by partial match; if multiple matches, opens input via fzf. smartcase.
#
#  g /data/partialmatch               # searches for partialmatch in /data.
#  g /  da  part                      # same as previous; note that partialmatches can
#                                     # be separated by whitespace instead of slashes.
#  g /partialmatch_1/partialmatch     # searches for partialmatch in directory resolved
#                                     # from partialmatch_1 in /.
#  g partialmatch_1  partialmatch     # searches for partialmatch in directory resolved
#                                     # from partialmatch_1 in our current dir.
#  g ../partialmatch                  # searches for partialmatch in parent directory.
#  g ...../partialmatch               # searches for partialmatch in directory that's
#                                     # 4 levels up.
#  g partialmatch                     # searches for partialmatch in current dir.
#  g                                  # if no input, then searches all directories in current dir.
#
# see also gg()
g() {
    local paths input i dir is_backing has_fzf

    # TODO: support fd if avail?
    __find_fun() {
        local pattern dir iname_arg
        pattern="$1"
        dir="${2:-.}"

        [[ "$(tolowercase "$pattern")" == "$pattern" ]] && iname_arg='iname'
        [[ "$dir" != */ ]] && dir+='/'
        find -L "$dir" -maxdepth 1 -mindepth 1 -type d -${iname_arg:-name} "*${pattern}*" -print0
    }

    # note this function sets the parent function's dir variable.
    __select_dir() {
        local pattern start_dir _dir matches i
        readonly pattern="$1"
        readonly start_dir="${2:-.}"

        # debug:
        #report "patt: '$pattern'; dir: '$start_dir'" -1

        # first check whether exact node name was given (including [..], given is_backing=1);
        # then we can define [dir] without invoking find:
        [[ "$start_dir" != '/' ]] && _dir="$start_dir"  # avoid building double slashes
        ! [[ "$is_backing" -eq 0 && "$pattern" == '..' ]] && [[ "$pattern" != '.' && -d "$_dir/$pattern" ]] && { dir="$_dir/$pattern"; return 0; }

        if [[ "$has_fzf" -eq 0 ]]; then
            declare -a matches=()
            while IFS= read -r -d $'\0' i; do
                matches+=("$i")
            done < <(__find_fun "$pattern" "$start_dir")

            select_items -s "${matches[@]}" || return 1
            dir="${__SELECTED_ITEMS[*]}"
        else
            dir="$(__find_fun "$pattern" "$start_dir" | fzf --select-1 --read0 --exit-0)" || return 1
        fi

        [[ -z "$dir" ]] && { err 'no matches found' -1; return 1; }
        [[ -d "$dir" ]] || { err "no such dir like [$dir] in $start_dir" -1; return 1; }
    }

    # note this function sets the parent function's $dir variable.
    __go_up() {
        local pattern i
        pattern="$1"  # dots only; guaranteed to be minimum of 3 dots.
        for ((i=0; i <= (${#pattern} - 2); i++)); do
            dir+='../'
        done
    }

    for i in "$@"; do
        input+="$i"
        [[ "$i" != */ ]] && input+='/'
    done

    #[[ -d "$input" && ! "$input" =~ ^.*/\.+/$ ]] && { cd -- "$input"; return; }
    is_backing=1  # default to assume first directory navigations are going up the tree;
    [[ -z "$input" ]] && input='*'
    [[ "$input" == /* ]] && { input="${input:1}"; is_backing=0; dir='/'; }
    command -v fzf > /dev/null 2>&1 && readonly has_fzf=1 || readonly has_fzf=0

    IFS='/' read -ra paths <<< "$input"
    #echo "paths: [${paths[@]}]"  # debug

    # clean paths:
    # TODO: what if the first path element is '.'? '26 edit: should be fine, no?
    for i in "${!paths[@]}"; do
        [[ -z "${paths[$i]}" || "${paths[$i]}" == . ]] && unset 'paths[i]'
    done
    [[ "${#paths[@]}" -eq 0 ]] && paths=('*')
    #echo "cleaned paths: [${paths[@]}]"

    for i in "${paths[@]}"; do
        [[ -z "$dir" && "$i" =~ ^\.{3,}$ ]] && { __go_up "$i"; is_backing=0; continue; }
        [[ "$i" != '..' ]] && is_backing=0
        __select_dir "$i" "$dir" || { unset __find_fun __select_dir __go_up; return 1; }
    done

    unset __find_fun __select_dir __go_up
    #echo "cd to: [$dir]"  # debug
    cd -- "$dir"
}  # /g()


# {{{  # dir-completion
# $1 - name of the function whose args are completed
# $2 - word being completed
# $3 - word preceding the word being completed on the current command line, think it's same as ${COMP_WORDS[COMP_CWORD-1]}
#
# note there's also a counterpart in zsh side of the world
_complete_dirs_in_pwd() {
    local curw wordlist d prefix p i

    curw=${COMP_WORDS[COMP_CWORD]}  # think it's the same as $2?
    if [[ "$DEBUG" -eq 1 ]]; then
        display_message "\$1: [$1]; \$2: [$2]; \$3: [$3]; \$curw: [$curw]"
    fi

    __go_up() {
        local dots i d
        dots="$*"  # guaranteed to be _minimum_ of 3 dots.
        for ((i=0; i <= (${#dots} - 2); i++)); do
            d+='../'
        done
        echo -n "$d"
    }

    # defines global/outer $d
    __define_d() {
        local I input paths i

        I="$1"
        for i in "${COMP_WORDS[@]:1:${#COMP_WORDS[@]}-I}"; do
            input+="$i"
            [[ "$i" != */ ]] && input+='/'
        done

        [[ "$input" == '~'* ]] && input="${HOME}${input:1}"  # or: input="${input/#\~/$HOME}"
        [[ "$input" == /* ]] && { input="${input:1}"; d='/'; }
        #[[ -z "$input" ]] && input='.'  # TODO  do we want this?

        IFS='/' read -ra paths <<< "$input"

        for i in "${paths[@]}"; do
            [[ -z "$i" || "$i" == . ]] && continue   # TODO: what if the first path element is '.'?

            [[ -z "$d" && "$i" =~ ^\.{3,}$ ]] && { d="$(__go_up "$i")"; continue; }
            [[ "$i" == \$* ]] && i="$(envsubst <<< "$i")"  # need to manually expand env vars
            [[ -n "$d" && "$d" != */ && "$i" != /* ]] && d+='/'
            d+="$i"
        done
        [[ "$DEBUG" -eq 1 ]] && display_message "define_d(): [$d]"
    }


    if [[ "$COMP_CWORD" -eq 1 && ! "$curw" =~ ^\.{3,} ]]; then
        [[ "$DEBUG" -eq 1 ]] && display_message 1st
        return 0  # if [^...] then those need to be expanded, hence can't return here
    elif [[ "$2" == */ ]]; then  # ie all's confirmed directory path i suppose? as in no further completion needed here
        [[ "$DEBUG" -eq 1 ]] && display_message 2nd
        curw="$2\ "
        COMPREPLY=($(compgen -W "$curw" -- "$curw"))
        return 0
    elif grep -qE '\S+/\S+' <<< "$curw"; then
        if [[ "$COMP_CWORD" -eq 1 ]]; then
            # TODO: is this block even reachable, doesn't the very first condition cover this?
            [[ "$DEBUG" -eq 1 ]] && display_message 3rd
            __define_d 1
            d="${d%/*}/"
            curw="${curw##*/}"  # everything after very last slash
            prefix="$d"
        else
            [[ "$DEBUG" -eq 1 ]] && display_message 4th
            __define_d 2

            IFS='/' read -ra p <<< "${curw%/*}"  # split up everything before last slash
            curw="${curw##*/}"  # everything after very last slash

            for i in "${p[@]}"; do
                [[ -z "$i" || "$i" == . ]] && continue   # TODO: what if the first path element is '.'?
                [[ "$i" == \$* ]] && i="$(envsubst <<< "$i")"  # need to manually expand env vars
                [[ "$i" != */ ]] && i+='/'
                [[ "$d" != */ ]] && d+='/'
                d+="$i"
                prefix+="$i"
            done
        fi
    else
        [[ "$DEBUG" -eq 1 ]] && display_message 5th
        __define_d 1        # TODO: shouldn't this be  __define_d 2 ??
        if [[ -n "$2" ]]; then  # if we're currently trying to auto-complete something
            curw="${d##*/}"  # everything after very last slash
            d="${d%/*}"  # get everything before the very last slash
            [[ "$d" != */ ]] && d+='/'
            [[ "$COMP_CWORD" -eq 1 && "$2" =~ ^\.{3,} ]] && prefix="$d"  # expand the ...+ on command line if we're only completing that
        fi
    fi

    # TODO: currently when doing  $g /dev dir word<TAB>   while /dev/dir is partial, then find here would
    # try to search where $d=/dev/dir; not a deal-breaker, but some recursive completion for this would be cool
    wordlist=$(find -L "${d:-.}" -mindepth 1 -maxdepth 1 -type d -printf "${prefix}%f\n" 2>/dev/null)

    # TODO: how to make sure our current dir's contents aren't offered
    # in case target dir no longer has candidates? setting COMPREPLY here to
    # empty val sort of works, but not ideal:
    [[ -z "$wordlist" ]] && COMPREPLY=('') && return 0

    # COMPREPLY is the output of completion attempt
    COMPREPLY=($(compgen -W '${wordlist[@]}' -- "${prefix}$curw"))
    #report "comprelpy: [${COMPREPLY[*]}]"
    return 0
}

#complete -o dirnames -o filenames -o nospace -F _complete_dirs_in_pwd g  # autocomplete on directories
#complete -o dirnames -o filenames -F _complete_dirs_in_pwd g             # autocomplete on directories
complete -o dirnames -F _complete_dirs_in_pwd g
# }}}  /dir-completion


########################################## fasd {{{  # fasd init caching and loading:  (https://github.com/clvv/fasd) !! note we also modify the cache here
#if command -v fasd > /dev/null; then
#    fasd_cache="$HOME/.fasd-init-bash.cache"
#
#    if [[ ! -s "$fasd_cache" || "$(command -v fasd)" -nt "$fasd_cache" ]]; then
#        fasd --init posix-alias bash-hook bash-ccomp bash-ccomp-install >| "$fasd_cache"
#
#        # comment out some of the default aliases, as our bash_functions (likely) provide our own:
#        # (alternatively we could remove 'posix-alias' from the fasd --init command)
#        sed -i --follow-symlinks 's/^alias d=/#alias d=/' "$fasd_cache"
#        sed -i --follow-symlinks 's/^alias z=/#alias z=/' "$fasd_cache"  # zoxide defines conflicting z alias, and we weren't using this alias anyway
#
#        fasd_completion_replacement='
#        # manage how --complete figures out which types of files to complete for;
#        # note default solution expands the completable command - a shell alias - and
#        # passes it to fasd --complete, which then takes the $2 as option, which means
#        # it should likely be something like -d or -f; we expand this logic in order
#        # to be able to also define functions, not only aliases; for that we utilize
#        # the FASD_FUN_FLAG_MAP for lookup
#        local _r
#        if declare -Ff "$COMP_WORDS" > /dev/null; then  # is function
#            _r="fasd ${FASD_FUN_FLAG_MAP[$COMP_WORDS]:-"-d"}"  # note we default to -d
#        else  # the original solution, which expands the alias in order for --complete to extract the used fasd flag(s) from the alias
#            _r="$(alias -p $COMP_WORDS \\
#                2>> "/dev/null" | sed -n "\\\$s/^.*'"'"'\\\\(.*\\\\)'"'"'/\\\\1/p")"
#        fi
#        local RESULT=$( fasd --complete "$_r'
#
#        fasd_completion_replacement="$(sed ':a $!{N; ba}; s/\n/\\n/g' <<< "$fasd_completion_replacement")"  # replace newlines with \n; this is so sed replacement can work
#
#        # replace the bash completion logic to also support functions, not only aliases;
#        # note this replacement will span 2 lines:
#        #sed -i --follow-symlinks ":a;N;$!ba;s+local RESULT.*2.*sed -n.*p\")$+$fasd_completion_replacement+" "$fasd_cache"
#        sed -i --follow-symlinks "N;s+local RESULT.*2.*sed -n.*p\")$+$fasd_completion_replacement+" "$fasd_cache"
#
#        unset fasd_completion_replacement
#    fi
#
#    # lookup map to show which types of files tab completion should complete for
#    # for given function; used by fasd completion logic we modify above:
#    declare -rA FASD_FUN_FLAG_MAP=(
#        [e]='-f'
#        [se]='-f'
#        [es]='-f'
#        [goto]='-a'
#        [gt]='-a'
#        [d]='-d'
#    )
#
#    source "$fasd_cache"
#    unset fasd_cache
#
#    # add tab completion support to all our own-defined fasd aliases (as per fasd readme):
#    _fasd_bash_hook_cmd_complete  e se es goto gt  # completion for d is already added by cache, no point in duplicating
#fi
# }}}  /fasd

