#
# $1 - name of the function whose args are completed
# $2 - word being completed
# $3 - word preceding the word being completed on the current command line, think it's same as ${COMP_WORDS[COMP_CWORD-1]}
#
# note there's also a counterpart in zsh side of the world
_complete_dirs_in_pwd() {
    local curw wordlist d prefix p i

    if [[ "$DEBUG" -eq 1 ]]; then
        err "\$1: [$1]"  # always funcname
        err "\$2: [$2]"  # think its what's on cml at the time you press tab, even if it gets completed immediately; separate last part, not entirety that's on CLI
        err "\$3: [$3]"  # last completed word? even if its not valid completion
    fi
    curw=${COMP_WORDS[COMP_CWORD]}  # think it's the same as $2?

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

        [[ "$input" == '~'* ]] && input="${HOME}${input:1}"
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
        __define_d 1
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

