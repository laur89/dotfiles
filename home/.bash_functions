#!/usr/bin/env bash
# shellcheck disable=SC2015
#
# good source to begin with: http://tldp.org/LDP/abs/html/sample-bashrc.html
# TODO: check this!: https://github.com/Cloudef/dotfiles-ng/blob/master/#ARCHCONFIG/shell/functions
# also this for general dotfiles/scripts goodness: https://github.com/Donearm
#
#
# =====================================================================
# import common:
# !! do _not_ replace this block with the common /etc/.global-bash-init sourcing !!
[[ ! -e /etc/.global-bash-init ]] || source /etc/.global-bash-init #|| exit 1
# =====================================================================



# Find a file with a pattern in name (inside wd);
# essentially same as ffind(), but a bit simplified:
#function ff() {
    #find . -type f -iname '*'"$*"'*'  -ls
#}

# + to get pid of a program:
#   - pgrep -x bctld
#   - ps -C bctld -o pid=
# + other relevant cmds:
#   - print process tree up from given PID:  $ pstree -aps $pid
#   - procs: add ppid to output:  $ procs -i Ppid
#   - procs: search for 'tmux' and print only ppid:  $ procs --no-header -i Ppid --only Ppid -- tmux
ffindproc() {
    [[ "$#" -ne 1 ]] && { err "exactly one arg (process name to search) allowed"; return 1; }
    [[ -z "$1" ]] && { err "process name required"; return 1; }

    #if command -v procs > /dev/null; then
        #procs --no-header -- "$1" | grep -v '\bgrep\b' | grep -i --color=auto -- "$1"
        #procs --no-header  -i Ppid -i Pgid -i Group -- "$1"
    #else
        ## last grep for re-coloring:
        #ps -ef | grep -v '\bgrep\b' | grep -i --color=auto -- "$1"
    #fi
    ps --no-headers -eo pid,ppid,pgid,egroup,command | \
        grep -v "$USER     \bgrep\b .*$(rgxesc "$1")" | grep -i --color=auto -- "$1"
}


aptsearch() {
    [[ -z "$@" ]] && { err "provide partial package name to search for."; return 1; }
    check_progs_installed  apt-cache || return 1

    apt-cache search -- "$@"
    #apt search -- "$@"
    #aptitude search -- "$@"
}

aptsrc() { aptsearch "$@"; }  # alias

# list packages that did not come from Debian
# from https://www.debian.org/releases/trixie/release-notes/upgrading.en.html#remove-non-debian-packages
#
# other cmds:
# - show pkgs which have a status of Half-Installed or Failed-Config:
#    dpkg --audit
# - inspect state of all pkgs:
#    dpkg -l
#    dpkg --get-selections '*' | bat
#    apt list --installed | bat
# - find biggest packages:
#    dpigs
#    or:
#    wajig size
#    or:
#    start aptitude, select Views > New Flat Package List, plress l and enter ~i, press S and enter ~installsize
nondebpkgs() {
    apt list '?narrow(?installed, ?not(?origin(Debian)))'
    # or:
    #apt-forktracer | sort
}

aptclean() {
    local apt_lists_dir

    readonly apt_lists_dir='/var/lib/apt/lists'

    report "note that sudo passwd is required"

    sudo apt-get clean
    sudo apt-get autoremove  # remove forgotten packages, i.e. dependencies of already-removed packages

    # TODO: instead of nuking $apt_lists_dir contents, consider  # apt-get distclean
    if [[ -d "$apt_lists_dir" ]]; then
        if ! is_dir_empty "$apt_lists_dir"; then
            report "deleting contents of [$apt_lists_dir]"
            sudo rm -rf "$apt_lists_dir"/*
        fi
    else
        err "[$apt_lists_dir] is not a dir; can't delete the contents in it."
    fi

    sudo apt-get update
}

aptlargest()  {
    local num

    num="$1"
    [[ -z "$num" ]] && num=10
    is_digit "$num" && [[ "$num" -gt 0 ]] || { err "nr of largest apt packages needs to be a positive digit, but was [$num]"; return 1; }

    aptitude search --sort '~installsize' --display-format '%p %I' '~i' | head -n "$num"
}

aptbiggest() { aptlargest "$@"; }  # alias


# to list 'Obsolete and Locally Created Packages':
#   aptitude search '~o'
#   or:
#   apt list '~o'
# to purge said packages:
#   aptitude purge '~o'
#   or:
#   apt purge '~o'
# display list of removed pkgs that have config files left that can be purged:
#   apt list '~c'
# purge 'em w/:
#   apt purge '~c'
#
# provide -f flag to allow for release codename change (ie to upgrade to new codename)
# TODO: remove -f support here as it's also defined on update()?
upgrade() {
    local f usage start res fmt opt OPTIND full

    f="$(funname)"
    readonly usage="\n$f: upgrade OS
    Usage: $f  [-f]
        -f  full upgrade, ie allow bumping releaseinfo/codename"

    while getopts 'fh' opt; do
        case "$opt" in
           f) full=TRUE ;;
           h) echo -e "$usage"
              return 0 ;;
           *) echo -e "$usage"
              return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    sudo echo
    report "started at $(date)"
    start="$(date +%s)"

    # note we run [upgrade --without-new-pkgs] before dist-upgrade as per https://www.debian.org/releases/bullseye/amd64/release-notes/ch-upgrading.en.html#minimal-upgrade
    sudo -s -- <<EOF
        rep_() { echo -e "\033[1m -> \$*...\033[0m"; }

        rep_ running apt-get autoclean && \
        apt-get autoclean -y && \
        rep_ running apt-get ${full:+--allow-releaseinfo-change }update && \
        apt-get ${full:+--allow-releaseinfo-change} -y update && \
        rep_ running apt-get upgrade --without-new-pkgs && \
        NEEDRESTART_MODE=l  apt-get upgrade --without-new-pkgs -y && \
        rep_ running apt-get dist-upgrade && \
        NEEDRESTART_MODE=l  apt-get dist-upgrade -y && \
        #NEEDRESTART_MODE=l  apt full-upgrade  # alternative to apt-get dist-upgrade
        rep_ running apt-get autoremove --purge && \
        NEEDRESTART_MODE=l  apt-get autoremove --purge -y || exit \$?

        # nuke removed packages' configs:  TODO: isn't there 'apt-get autopurge' for this? note autopurge is same as 'autoremove --purge'
        #__prgs_to_purge="\$(dpkg -l | awk '/^rc/ { print \$2 }')" || exit \$?

        #if [[ -n "\$__prgs_to_purge" ]]; then
            #rep_ running apt-get purge
            #NEEDRESTART_MODE=l  apt-get -y purge \$__prgs_to_purge
            #exit \$?
        #fi
EOF

    res="$?"
    [[ "$res" -eq 0 ]] && fmt=GREEN || fmt=RED
    fmt="${COLORS[$fmt]}${COLORS[BOLD]}$res${COLORS[OFF]}"
        #apt-get -y purge $(dpkg -l | awk '/^rc/ { print $2 }')  <- doesn't work for some reason (instead of the last line prior EOF)

    report "ended at [${COLORS[BLUE]}$(date)${COLORS[OFF]}] with code [$fmt], completed in ${COLORS[YELLOW]}${COLORS[BOLD]}$(($(date +%s) - start))${COLORS[OFF]} sec"
    return $res
}


# provide -f flag to allow for release codename change (ie to upgrade to new codename)
update() {
    local opt full OPTIND start res fmt

    while getopts 'f' opt; do
        case "$opt" in
           f) full=TRUE
              ;;
           *) err "unsupported option [$opt]";
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    sudo echo
    report "started at $(date)"
    start="$(date +%s)"

    sudo apt-get ${full:+--allow-releaseinfo-change} -y update
    res="$?"
    [[ "$res" -eq 0 ]] && fmt=GREEN || fmt=RED
    fmt="${COLORS[$fmt]}${COLORS[BOLD]}$res${COLORS[OFF]}"

    report "ended at [${COLORS[BLUE]}$(date)${COLORS[OFF]}] with code [$fmt], completed in ${COLORS[YELLOW]}${COLORS[BOLD]}$(($(date +%s) - start))${COLORS[OFF]} sec"
}


# nuke SNAPSHOT versions from local maven repo
mvnclean() {
    local mvn_conf ptrn m_repo noop opt OPTIND

    readonly mvn_conf="$HOME/.m2/settings.xml"
    ptrn='*SNAPSHOT'

    while getopts 'np:' opt; do
        case "$opt" in
           n) noop=1
              ;;
           p) ptrn="$OPTARG"
              [[ -z "$ptrn" ]] && { err "[pattern] arg cannot be empty"; return 1; }
              ;;
           *) return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ -f "$mvn_conf" ]] && m_repo="$(grep -Po '^\s*<localRepository>\K.*(?=<)' "$mvn_conf")"  # try to see if we're setting localRepo path in maven config
    [[ "$?" -eq 0 && -d "$m_repo" ]] || m_repo="$HOME/.m2/repository"  # default if not found in settings.xml
    [[ -d "$m_repo" ]] || { err "maven repo [$m_repo] not a dir"; return 1; }

    if [[ "$noop" -eq 1 ]]; then
        report "following directories would be removed:"
        find "$m_repo" -name "$ptrn" -type d -printf '  -> %p\n'
    else
        confirm "wish to delete all [$ptrn] vers under [${COLORS[YELLOW]}${m_repo}${COLORS[OFF]}]?" || return 0

        #find "$m_repo" -name "$ptrn" -type d -print0 | xargs -0 rm -rf
        find "$m_repo" -name "$ptrn" -type d -exec rm -rf -- '{}' \+
    fi
}


#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of grep).
# TODO: find whether we could stop using find here and use grep --include & --exclude flags instead.
ffstr() {
    local grepcase OPTIND usage opt max_result_line_length caseOptCounter force_case regex i
    local iname_arg maxDepth maxDepthParam defMaxDeptWithFollowLinks follow_links
    local pattern file_pattern collect_files open_files dir f

    caseOptCounter=0
    OPTIND=1
    max_result_line_length=300      # max nr of characters per grep result line; TODO: make it dynamic for current term window?
    defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) option selected;

    f="$(funname)"
    readonly usage="\n$f: find string in files. smartcase both for filename and search patterns.
    Usage: $f  [opts]  \"pattern\"  [filename pattern]  [starting dir]
        -i  force case insensitive;
        -s  force case sensitivity;
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;
        -L  follow symlinks;
        -c  collect matching filenames into global array instead of printing to stdout;
        -o  open found files;
        -r  enable regex on filename pattern"

    while getopts 'isrm:Lcoh' opt; do
        case "$opt" in
           i)
              [[ "$iname_arg" != '-iname' ]] && let caseOptCounter+=1
              iname_arg='-iname'
              grepcase=' -i '
                ;;
           s)
              [[ "$force_case" -ne 1 ]] && let caseOptCounter+=1
              unset iname_arg grepcase
              force_case=1
                ;;
           r) regex=1
                ;;
           m) maxDepth="$OPTARG"
                ;;
           L) follow_links='-L'
                ;;
           c) collect_files=1
                ;;
           o) open_files=1
              collect_files=1  # so we can use the collected array
                ;;
           h) echo -e "$usage"
              return 0
              ;;
           *) echo -e "$usage"
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    if [[ "$#" -eq 3 && ! -d "${@: -1}" ]]; then
        err "last arg can only be starting dir"
        return 1
    elif [[ "$#" -gt 1 ]]; then
        i="${@: -1}"  # last arg; alternatively ${@:$#}
        if [[ -d "$i" ]]; then
            [[ "$#" -lt 3 ]] && report "assuming starting path [$i] was given\n" && sleep 1.5  # if less than 3 args, we need to assume
            dir="$i"
            set -- "${@:1:${#}-1}"  # shift the last arg
        fi
        unset i
    fi

    pattern="$1"
    file_pattern="$2"

    if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
        err "incorrect nr of arguments."
        echo -e "$usage"
        return 1;
    elif [[ "$caseOptCounter" -gt 1 ]]; then
        err "-i and -s flags are exclusive."
        echo -e "$usage"
        return 1
    fi

    # grep search pattern sanity:
    if [[ "$pattern" == *\** && "$pattern" != *\.\** ]]; then
        err "use .* as wildcards, not a single *"
        return 1
    elif [[ "$(echo "$pattern" | tr -dc '.' | wc -m)" -lt "$(echo "$pattern" | tr -dc '*' | wc -m)" ]]; then
        err "nr of periods (.) was less than stars (*); are you misusing regex?"
        return 1
    fi


    # find metacharacter or regex FILENAME (not search pattern) sanity:
    if [[ -n "$file_pattern" ]]; then
        if [[ "$file_pattern" == */* ]]; then
            err "there are slashes in the filename."
            return 1
        fi

        if [[ "$regex" -eq 1 ]]; then
            if [[ "$file_pattern" == *\** && "$file_pattern" != *\.\** ]]; then
                err 'err in filename pattern: use .* as wildcards, not a single *; you are misusing regex.'
                return 1
            elif [[ "$(echo "$file_pattern" | tr -dc '.' | wc -m)" -lt "$(echo "$file_pattern" | tr -dc '*' | wc -m)" ]]; then
                err "err in filename pattern: nr of periods (.) was less than stars (*); are you misusing regex?"
                return 1
            fi
        else  # no regex, make sure find metacharacters are not mistaken for regex ones:
            if [[ "$file_pattern" == *\.\** ]]; then
                err "err in filename pattern: only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex."
                return 1
            fi

            if [[ "$file_pattern" == *\.* ]]; then
                report "note that period (.) in the filename pattern will be used as a literal period, not as a wildcard. provide -r flag to use regex.\n"
            fi
        fi
    elif [[ "$regex" -eq 1 ]]; then  # -z $file_pattern
        err "with -r flag, filename pattern is required."
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth" || [[ "$maxDepth" -le 0 ]]; then
            err "maxdepth (-m flag) arg value has to be a positive digit, but was [$maxDepth]"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    elif [[ -n "$follow_links" ]]; then
        maxDepthParam="-maxdepth $defMaxDeptWithFollowLinks"
    fi

    # as find doesn't support smart case, provide it yourself:
    if [[ "$(tolowercase "$pattern")" == "$pattern" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        grepcase=' -i '
    fi

    if [[ -n "$file_pattern" && "$(tolowercase "$file_pattern")" == "$file_pattern" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        iname_arg='-iname'
    fi

    [[ "$force_case" -eq 1 ]] && unset grepcase iname_arg

    ## Clean grep-only solution: (in this case the maxdepth option goes out the window)
    #if [[ -z "$file_pattern" ]]; then
        #[[ -n "$follow_links" ]] && follow_links=R || follow_links=r
        #grep -E${follow_links} --color=always -sn ${grepcase} -- "$pattern"

    __find_fun() {
        local file_pattern wildcard

        file_pattern="$1"
        wildcard='*'

        # note exact and regex are mutually exclusive
        if [[ "$regex" -eq 1 ]]; then
            wildcard='.*'
            iname_arg="-regextype posix-extended -${iname_arg:+i}regex"
        fi
        [[ "$file_pattern" == '*' || "$file_pattern" == '.*' ]] && unset file_pattern  # what if we're searching for file starting with dot? (ie should we unset if file_pattern=.*)

        if [[ -n "$file_pattern" ]]; then
            # don't quote $iname_arg!:
            find $follow_links ${dir:-.} $maxDepthParam -type f ${iname_arg:--name} "${wildcard}${file_pattern}${wildcard}" -print0 2>/dev/null
        else
            find $follow_links ${dir:-.} $maxDepthParam -type f -print0 2>/dev/null
        fi
        # TODO: convert to  'find . -name "$ext" -type f -exec grep "$pattern" /dev/null {} +' perhaps?
    }

    if [[ "$collect_files" -eq 1 ]]; then
        _FOUND_FILES=()
        while IFS= read -r -d $'\0' i; do
            _FOUND_FILES+=("$i")
        done < <(__find_fun "$file_pattern" | xargs -0 grep -Esl --null --color=never ${grepcase} -- "$pattern")

        if [[ "${#_FOUND_FILES[@]}" -eq 0 ]]; then
            report "found no files containing [${COLORS[RED]}${COLORS[BOLD]}${pattern}${COLORS[OFF]}]"
            return 1
        else
            report "found ${#_FOUND_FILES[@]} files containing [${COLORS[GREEN]}${COLORS[BOLD]}${pattern}${COLORS[OFF]}]; stored in \$_FOUND_FILES global array."
        fi

        [[ "$open_files" -eq 1 ]] && __fo "${_FOUND_FILES[@]}"
    else
        __find_fun "$file_pattern" | \
            xargs -0 grep -Esn --color=always --with-filename -m 1 ${grepcase} -- "$pattern" | \
            cut -c 1-$max_result_line_length | \
            more
            #less
        #__find_fun "$file_pattern" | \
            #xargs -P10 -n20 -0 grep --line-buffered -Esn --color=always --with-filename -m 1 $grepcase -- "$pattern" | \
            #cut -c 1-$max_result_line_length | \
            #more
     fi

    unset __find_fun
}

__mem_cpu_most_common_fun() {
    local num ps_out first_hdr second_hdr first_ps_col second_ps_col format

    readonly first_hdr="$1"
    readonly second_hdr="$2"
    readonly first_ps_col="$3"
    readonly second_ps_col="$4"

    readonly format='\t%s\t%s\t%s\n'

    [[ "$#" -lt 4 ]] && { err "minimum of 4 args required"; return 1; }
    [[ "$#" -gt 5 ]] && { err "max 5 args supported"; return 1; }
    [[ "$#" -eq 5 ]] && num="${@: -1}"  # last arg; alternatively ${@:$#}

    [[ -z "$num" ]] && num=10

    is_digit "$num" && [[ "$num" -gt 0 ]] || { err "nr of processes to show needs to be a positive digit, but was [$num]" -1; return 1; }
    # note we should try use '--ppid 2 -N' flag to filter out kernel threads (see https://unix.stackexchange.com/questions/258448/is-there-any-way-to-hide-kernel-threads-from-ps-command-results)
    ps_out="$(ps -ax --no-headers -o $first_ps_col,$second_ps_col,args --sort -${first_ps_col},-${second_ps_col})" || { err "ps command failed"; return 1; }
    ps_out="$(head -n "$num" <<< "$ps_out")" || return 1

    # formats the default full ps output (some versions of ps don't offer --sort option)
    #
    #__print_lines_old() {
        #local line cpu mem proc max_proc_len

        #readonly max_proc_len=200

        #while read -r line; do
            #proc="$(echo "$line" | grep -Po '^\s*(\S+\s+){10}[\\_|\s]*\K.*' | cut -c 1-$max_proc_len)"
            #cpu="$(echo "$line" | grep -Po '^\s*(\S+\s+){2}\K\S+(?=.*$)')"
            #mem="$(echo "$line" | grep -Po '^\s*(\S+\s+){3}\K\S+(?=.*$)')"
            #printf "$format" "${COLORS[RED]}${mem}${COLORS[OFF]}" "$cpu" "$proc"
        #done
    #}
    __print_lines() {
        local max_proc_len line primary_col secondary_col proc

        readonly max_proc_len=150

        while read -r line; do
            primary_col="$(echo "$line" | grep -Po '^\s*\K\S+(?=.*$)')"
            secondary_col="$(echo "$line" | grep -Po '^\s*\S+\s*\K\S+(?=.*$)')"
            proc="$(echo "$line" | grep -Po '^\s*(\S+\s*){2}\K.*' | cut -c 1-$max_proc_len)"
            printf "$format" "${COLORS[RED]}${primary_col}${COLORS[OFF]}" "$secondary_col" "$proc"
        done
    }

    printf "$format" "${COLORS[RED]}${first_hdr}${COLORS[OFF]}" "$second_hdr" 'PROC'
    printf "$format" '---' '---' '----------------'
    #echo "$ps_out" | sort -nr -k 4 | head -n $num | __print_lines_old  # legacy format for full ps output (ie no format nor sorting)
    echo "$ps_out" | __print_lines
    unset __print_lines
}

memmost() {
    [[ "$#" -gt 1 ]] && { err "only one arg, number of top mem consuming processes to display, allowed"; return 1; }

    __mem_cpu_most_common_fun MEM CPU pmem pcpu "$@"
}

cpumost() {
    [[ "$#" -gt 1 ]] && { err "only one arg, number of top cpu consuming processes to display, allowed"; return 1; }

    __mem_cpu_most_common_fun CPU MEM pcpu pmem "$@"
}

# $1: percentage of cpu. Default 90%
cpugt() {
    local perc ps_out
    perc="$1"
    [[ -z "$perc" ]] && perc=90

    ps_out=$(ps -auxf) || return 1
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 3 | awk -v "q=$perc" '($3>=q){print $0}'
}

# $1: percentage of memory. Default 90%
memgt() {
    local perc ps_out
    perc="$1"
    [[ -z "$perc" ]] && perc=90

    ps_out=$(ps -auxf) || return 1
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 4 | awk -v "q=$perc" '($4>=q){print $0}'
}


# show every process running as given user
# $1: name of the user
touser(){
    ps -U "$1" -u "$1" u
}

# $1: PID of the process
frompid(){
    is_digit "$1" || return 1
    #ps -p "$1" -o comm=
    ps -p "$1" -o command=
}


# $1: name of the process
topid(){
    ps -C "$1" -o pid=
}


# Swap 2 files around, if they exist (from Uzi's bashrc):
swap() {
    local tmp file_size space_left_on_target first_file sec_file i

    tmp="/tmp/.swap_function_${RANDOM}.tmp"
    first_file="${1%/}"  # strip trailing slash
    sec_file="${2%/}"    # strip trailing slash

    [[ "$#" -ne 2 ]] && err "2 args required" && return 1
    [[ ! -e "$first_file" ]] && err "[$first_file] does not exist" && return 1
    [[ ! -e "$sec_file" ]] && err "[$sec_file] does not exist" && return 1
    [[ "$first_file" == "$sec_file" ]] && err "source and destination cannot be the same" && return 1


    # check write perimssions:
    for i in "$tmp" "$first_file" "$sec_file"; do
        i="$(dirname -- "$i")"
        if [[ ! -w "$i" ]]; then
            err "$i doesn't have write permission. abort."
            return 1
        fi
    done

    # check if $first_file fits into /tmp:
    file_size="$(get_size "$first_file")"
    space_left_on_target="$(space_left "$tmp")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname -- "$tmp") has only [${space_left_on_target}MB] free space left. abort."
        return 1
    fi

    if ! mv -- "$first_file" "$tmp"; then
        err "moving $first_file to $tmp failed. abort."
        return 1
    fi

    # check if $sec_file fits into $first_file:
    file_size="$(get_size "$sec_file")"
    space_left_on_target="$(space_left "$first_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$sec_file size is ${file_size}MB, but $(dirname -- "$first_file") has only [${space_left_on_target}MB] free space left. abort."
        # undo:
        mv -- "$tmp" "$first_file"
        return 1
    fi

    if ! mv -- "$sec_file" "$first_file"; then
        err "moving $sec_file to $first_file failed. abort."
        # undo:
        mv -- "$tmp" "$first_file"
        return 1
    fi

    # check if $first_file fits into $sec_file:
    file_size="$(get_size "$tmp")"
    space_left_on_target="$(space_left "$sec_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname -- "$sec_file") has only [${space_left_on_target}MB] free space left. abort."
        # undo:
        mv -- "$first_file" "$sec_file"
        mv -- "$tmp" "$first_file"
        return 1
    fi

    if ! mv -- "$tmp" "$sec_file"; then
        err "moving [$first_file] to [$sec_file] failed. abort."
        # undo:
        mv -- "$first_file" "$sec_file"
        mv -- "$tmp" "$first_file"
        return 1
    fi
}

# search/list for a file/dir by name from a dir.
# mnemonic: list-grep
#
lgrep() {
    local f src srcdir usage exact OPTIND

    f="$(funname)"
    usage="\n$f  [-e]  filename_to_grep  [dir_to_look_from]
  or:
$f  [-e]  /dir_to_look_from/filename_to_grep
             -e  search for exact filename

        Examples:
            lgrep pattern         searches for pattern in current dir
            lgrep pattern /tmp    searches for pattern in /tmp
            lgrep /tmp/pattern    searches for pattern in /tmp
"

    while getopts 'he' opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           e) exact=1
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    src="$1"
    srcdir="$2"

    # provide syntax for   $FUNCNAME  /valid/path/to/grep/in/<filename_pattern>:
    if [[ "$src" == */* ]]; then
        [[ "$#" -ne 1 ]] && { err "if the path & greppable string is provided in single arg, then additional dir arg is not accepted"; return 1; }
        [[ "$src" == */ ]] && { err "can't provide only directory"; return 1; }
        srcdir="$(dirname -- "$src")"
        src="${src##*/}"  # strip everything before last slash (slash included)
    fi

    # sanity:
    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$src" ]]; then
        echo -e "$usage"
        return 1;
    elif [[ -n "$srcdir" ]]; then
        if [[ ! -d "$srcdir" ]]; then
            err "provided directory to list and grep from [$srcdir] is not a directory"
            echo -e "\n$usage"
            return 1
        elif [[ ! -r "$srcdir" ]]; then
            err "provided directory to list and grep from is not readable. abort."
            return 1
        fi

        [[ "$srcdir" != */ ]] && srcdir+='/'  # add trailing slash if missing; required for gnu find & ls
    fi

    if [[ "$exact" -eq 1 ]]; then
        [[ "$src" == *\.\** ]] && { err "fyi only use asterisks (*) for wildcards, not .*"; return 1; }  # this is because of find
        #src="$(ls -lhA "${srcdir:-.}" | awk '{ print $9 }' | grep -i -- "^$src$")" # ! note it assumes filename is listed in 9th column in ls output; what about spaces in filenames?
        src="$(find "${srcdir:-.}" -maxdepth 1 -mindepth 1 -name "$src" -printf '%f\n' -quit)"  # note we only allow single item!
        [[ $? -ne 0 || -z "$src" ]] && return 1

        #ls -lhA "${srcdir:-.}" | grep -E -- "^(\S+\s+){8}$src$" | grep --color=auto -F -- "$src"  # ! note it assumes filename is listed in 9+th column in ls output
        ls -lhA "${srcdir:-.}" | grep --color=auto -F -- "$src"
    else
        ls -lhA "${srcdir:-.}" | grep --color=auto -i -- "$src"
        #find "${srcdir:-.}" -maxdepth 1 -mindepth 1 -iname '*'"$src"'*' -printf '%f\n' | grep -iE --color=auto "$src|$"
    fi
}


# Make your directories and files access rights sane.
# (sane as in rw for owner, r for group, none for others)
sanitize() {
    local i

    [[ -z "$*" ]] && { err "provide a file/dir name plz."; return 1; }
    for i in "$@"; do
        [[ ! -e "$i" ]] && { err "[$i] does not exist; no permissions were changed"; return 1; }
    done

    #chmod -R u=rwX,g=rX,o= -- "$@";  # symlink targets are not resolved by chmod!
    find -L "$@" \( -type f -o -type d \) -exec chmod 'u=rwX,g=rX,o=' -- '{}' \+
}

# TODO: stop accepting args and hardcode to ~/.ssh?
sanitize_ssh() {
    local node="$*"

    [[ -z "$node" ]] && { err "provide a file/dir name plz. (most likely you want the [.ssh] dir)"; return 1; }
    [[ ! -e "$node" ]] && { err "[$node] does not exist."; return 1; }
    if [[ "$node" != *ssh*  ]]; then
        confirm  "\nthe node name you're about to $(funname)() does not contain string [ssh]; still continue? (y/n)" || return 0
    fi

    [[ -d "$node" && "$node" != */ ]] && node+='/'
    #chmod -R u=rwX,g=,o= -- "$node";  # with recursive opt set, symlink targets are not resolved by chmod
    find -L "$node" \( -type f -o -type d \) -exec chmod 'u=rwX,g=,o=' -- '{}' \+
}

ssh_sanitize() { sanitize_ssh "$@"; }  # alias for sanitize_ssh

myip() {  # Get internal & external ip addies:
    local connected_interface interfaces interface external_ip

    __get_internal_ip_for_if() {
        local interface ip

        interface="$1"

        if command -v ip > /dev/null 2>&1; then
            ip="$(ip addr show "$interface" | awk '/ inet /{print $2}')" || return 1
            ip="${ip%%/*}"  # strip the subnet (eg /24)
        elif [[ -x /sbin/ifconfig ]]; then
            ip="$(/sbin/ifconfig "$interface" | awk '/inet / {print $2}' | sed -e s/addr://)"  # TODO deprecated
        else
            err "nothing to find interface IP with"
            return 1
        fi

        [[ -z "$ip" && "$__REMOTE_SSH" -eq 1 ]] && return  # probaby the interface was not found
        echo -e "${COLORS[YELLOW]}${ip:-${COLORS[RED]}Not connected}${COLORS[OFF]}\t@ $interface"
    }

    connected_interface="$(find_connected_if)"  # note this returns only on own machines, not on remotes.

    if [[ -n "$connected_interface" ]]; then
        interfaces=("$connected_interface")
    else
        read -ra interfaces < <(list_interfaces)
    fi

    #list_contains "$interface" lo loopback || interfaces+=("$interface")  # TODO: atm we're not filtering out loopback; does list_interfaces do that?

    if [[ "$__REMOTE_SSH" -eq 1 && -z "${interfaces[*]}" ]]; then
        # take a blind guess
        interfaces=(eth0 eth1 eth2 eth3 enp0s3)  # TODO: configure for new standardized if names (https://www.freedesktop.org/software/systemd/man/systemd.net-naming-scheme.html)
        report "can't resolve network interfaces; trying these interfaces: [${interfaces[*]}]"
    fi

    if [[ "${#interfaces[@]}" -gt 0 ]]; then
        for interface in "${interfaces[@]}"; do
            __get_internal_ip_for_if "$interface"
        done
    else
        err "internal network not connected? (no network interface could be resolved)"
    fi

    unset __get_internal_ip_for_if

    # finally, try to solve our external address:
    external_ip="$(get_external_ip)" && {
        echo -e "external:\t${COLORS[YELLOW]}${external_ip:-${COLORS[RED]}Not connected to the internet}${COLORS[OFF]}"
    }
}

whatsmyip() { myip; }  # alias for myip

# !! lrzip might offer best compression when it comes to text: http://unix.stackexchange.com/questions/78262/which-file-compression-software-for-linux-offers-the-highest-size-reduction
compress() {
    local usage file type sup def opt OPTIND

    sup='zip|tar|rar|7z'  # supported compression type options
    sup="[${COLORS[YELLOW]}${COLORS[BOLD]}${sup}${COLORS[OFF]}]"
    readonly def=tar  # default compression mode
    readonly usage="$(funname)  fileOrDir  $sup\n\tif optional second arg not provided, compression type defaults to [$def] "

    while getopts 'h' opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    file="$1"
    type="$2"

    [[ $# -eq 1 || $# -eq 2 ]] || { err "gimme file/dir to compress plox.\n"; echo -e "$usage"; return 1; }
    [[ -e "$file" ]] || { err "$file doesn't exist."; echo -e "\n\n$usage"; return 1; }
    [[ -z "$type" ]] && { report "no compression type selected, defaulting to [${COLORS[YELLOW]}${COLORS[BOLD]}$def${COLORS[OFF]}]\n"; type="$def"; }

    case "$type" in
        zip) makezip "$file"
             ;;
        #tar) maketar "$file"
        tar) maketar2 "$file"
             ;;
        rar) [[ -d "$file" ]] || { err "input for rar has to be a dir"; return 1; }
             makerar "$file"
             ;;
        7z)  make7z "$file"
             ;;
        *)   err "compression type [$type] not supported; supported types: $sup\n"
             echo -e "$usage";
             return 1;
             ;;
    esac
}

pack() { compress "$@"; }  # alias for compress

# Creates an archive (*.tar.gz) from given directory.
maketar() { tar cvzf "${1%%/}.tar.gz" -- "${1%%/}/"; }

# Creates an archive (*.tar.bz2) from given directory.
# j - use bzip2 compression rather than z option  (heavier compression)
maketar2() { tar cvjf "${1%%/}.tar.bz2" -- "${1%%/}/"; }

# Create a rar archive.
# -m# - compresson lvl, 5 being max level, 0 just storage;
# TODO: what's the deal with -r flag?
makerar() {
    check_progs_installed rar || return 1

    rar a -r -rr10 -m4 -- "${1%%/}.rar"  "${1%%/}/"
}

# Create a ZIP archive of a file or folder.
makezip() {
    check_progs_installed zip || return 1

    zip -r "${1%%/}.zip" -- "$1"
}

# Create a 7z archive of a file or folder.
# -mx=# - compression lvl, 9 being highest (ultra)
make7z() {
    check_progs_installed 7z || return 1

    7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on -- "${1%%/}.7z" "$1"
}

# alias for extract
unpack() { extract "$@"; }

# TODO: consider atool or aunpack instead
#
# helper wrapper for uncompressing archives. it uncompresses into new directory, which
# name is the same as the archive's, sans the file extension. this avoids situations
# where gazillion files are being extracted into working dir. note that if the dir
# already exists, then unpacking fails (since mkdir fails).
#
# see also:
# - https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/extract/extract.plugin.zsh
extract() {
    local file file_without_extension

    file="$*"
    file_without_extension="${file%.*}"
    #file_extension="${file##*.}"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz."
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "[$file] is not a regular file or read rights not granted."
        return 1
    fi

    __create_target_dir() {
        local dir

        readonly dir="$file_without_extension"
        [[ -e "$dir" ]] && { err "[$dir] already exists" -1; return 1; }
        command mkdir -- "$dir" || return 1
        [[ -d "$dir" ]] || { err "mkdir failed to create [$dir]" -1; return 1; }
        return 0
    }

    case "$file" in
        *.tar.bz2)   file_without_extension="${file_without_extension%.*}"  # because two extensions
                        __create_target_dir && tar xjf "$file" -C "$file_without_extension" || return 1
                        ;;
        *.tar.gz)    file_without_extension="${file_without_extension%.*}"  # because two extensions
                        __create_target_dir && tar xzf "$file" -C "$file_without_extension" || return 1
                        ;;
        *.tar.xz)    file_without_extension="${file_without_extension%.*}"  # because two extensions
                        __create_target_dir && tar xpvf "$file" -C "$file_without_extension" || return 1
                        ;;
        *.bz2)       check_progs_installed bunzip2 || return 1
                        bunzip2 -k -- "$file" || return 1
                        ;;
        *.rar)       check_progs_installed unrar || return 1
                        __create_target_dir && unrar x "$file" "${file_without_extension}"/ || return 1
                        ;;
        *.gz)        check_progs_installed gunzip || return 1
                        gunzip -kd -- "$file" || return 1
                        ;;
        *.tar)       __create_target_dir && tar xf "$file" -C "$file_without_extension" || return 1
                        ;;
        *.tbz|*.tbz2)__create_target_dir && tar xjf "$file" -C "$file_without_extension" || return 1
                        ;;
        *.tgz)       __create_target_dir && tar xzf "$file" -C "$file_without_extension" || return 1
                        ;;
        *.zip)       check_progs_installed unzip || return 1
                        __create_target_dir && unzip -- "$file" -d "$file_without_extension" || return 1
                        ;;
        *.7z)        check_progs_installed 7z || return 1
                        __create_target_dir && 7z x "-o$file_without_extension" -- "$file" || return 1
                        ;;
                        # TODO .Z is unverified how and where they'd unpack:
        *.Z)         check_progs_installed uncompress || return 1
                        uncompress -- "$file"  || return 1
                        ;;
        *)           err "[$file] cannot be extracted; this filetype is not supported."
                        return 1
                        ;;
    esac

    report "extracted [$file] contents into [$file_without_extension]"
    unset __create_target_dir
}

# to check included fonts: xlsfonts | grep fontname
# list all installed fonts: fc-list
fontreset() {
    local dir

    [[ -d ~/.fonts ]] || { err "~/.fonts is not a dir"; return 1; }

    xset +fp ~/.fonts
    mkfontscale ~/.fonts
    mkfontdir ~/.fonts

    pushd ~/.fonts || { err "[pushd ~/.fonts] failed with $?"; return 1; }
    for dir in * ; do
        if [[ -d "$dir" ]]; then
            pushd "$dir"
            xset +fp "$PWD"
            mkfontscale
            mkfontdir
            popd
        fi
    done

    xset fp rehash
    fc-cache -fv
    popd
}

# alias for fontreset:
resetfont() { fontreset; }

# TODO: rewrite this one, looks stupid:
up() {
    local i d limit

    d=""
    is_digit "$1" && limit=$1 || limit=1
    for ((i=1; i <= limit; i++)); do
        d="$d/.."
    done
    d="$(sed 's/^\///' <<< "$d")"

    cd -- "$d" || return 1
    return 0
}

# clock - A bash clock that can run in your terminal window:
clock() {
    while true; do
        clear
        printf "==========\n %s\n==========" "$(date '+%R:%S')"
        sleep 1
    done
}

# format xml into readable shape:
#    xmlformat file1 [file2...]
#    xmlformat '<xml> unformatted </xml>'
xmlformat() {
    local file regex result content

    readonly regex='^\s*<'
    [[ -z "$@" ]] && { echo -e "usage:   $(funname)  <filename>  OR  $(funname)  'raw xml string'"; return 1; }
    check_progs_installed xmllint "$EDITOR" || return 1;

    if [[ "$#" -eq 1 && ! -f "$*" && "$*" =~ $regex ]]; then
        content="$(sed '/^\s*$/d;s/^[[:space:]]*//;s/[[:space:]]*$//' <<< "$*")"  # strip empty lines + leading&trailing whitespace
        result="$(xmllint --format - <<< "$content")" || { err "formatting input xml failed"; return 1; }
        echo
        echo "$result"
        echo
        copy_to_clipboard "$result" && report "formatted xml is on clipboard"
        return 0
    fi

    for file in "$@"; do
        [[ -f "$file" && -r "$file" ]] || { err "provided file [$file] is not a regular file or is not readable. abort."; return 1; }
    done

    xmllint --format "$@" | "$EDITOR"  "+set foldlevel=99" -;
}

xmlf() { xmlformat "$@"; }  # alias for xmlformat;

# TODO: instead of verifying device doesn't end w/ digit, perhaps list devices via:   lsblk -d -n -oNAME,RO | grep '0$' | awk {'print $1'}
createUsbIso() {
    local file device mountpoint cleaned_devicename usage override_dev_partitioncheck
    local reverse inf ouf full_lsblk_output i f OPTIND partition

    f="$(funname)"
    readonly usage="$f: write files onto devices and vice versa.

    Usage:   $f  [options]  source  destination
        -o  allow selecting devices whose name ends with a digit (note that you
            should be selecting a whole device instead of its parition (ie sda vs sda1),
            but some devices have weird names (eg sd cards, optical drives)).

    example: $f  file.iso  /dev/sdh
             $f  /dev/sdb  /tmp/file.iso"

    check_progs_installed   dd lsblk dirname umount sudo || return 1

    while getopts 'ho' opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           o) override_dev_partitioncheck=1
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ "$#" -ne 2 ]] && { err "exactly 2 params required"; return 1; }
    for i in "$@"; do
        if [[ "$i" == /dev/* ]]; then
            [[ "$i" == "$1" ]] && reverse=1  # direction is reversed - device will be written into a file.
            device="${i%/}"  # strip trailing slash
        else
            file="$i"
        fi
    done

    readonly cleaned_devicename="${device##*/}"  # strip everything before last slash (slash included)

    if [[ -z "$file" || -z "$device" || -z "$cleaned_devicename" ]]; then
        err "either file or device weren't provided"
        echo -e "$usage"
        return 1;
    elif [[ ! -f "$file" && "$reverse" -ne 1 ]]; then
        err "[$file] is not a regular file"
        echo -e "$usage"
        return 1;
    elif [[ -f "$file" && "$reverse" -eq 1 ]]; then
        err "[$file] already exists. choose another file to write into, or delete it."
        echo -e "$usage"
        return 1;
    elif [[ "$reverse" -eq 1 && ! -d "$(dirname -- "$file")" ]]; then
        err "[$file] doesn't appear to be defined on a valid path. please check."
        echo -e "$usage"
        return 1;
    elif [[ ! -e "$device" ]]; then
        err "[$device] device does not exist"
        echo -e "$usage"
        return 1;
    elif ! find /dev -name "$cleaned_devicename" -print0 -quit 2> /dev/null | grep -q .; then
        err "[$cleaned_devicename] does not exist in /dev"
        echo -e "$usage"
        return 1;
    elif [[ "$override_dev_partitioncheck" -ne 1 && "$cleaned_devicename" =~ .*[0-9]+$ ]]; then
        # as per arch wiki
        err "please don't provide partition, but a drive, e.g. /dev/sdh instad of /dev/sdh1"
        report "note you can override this check with the -o flag."
        echo -e "$usage"
        return 1
    elif [[ "$override_dev_partitioncheck" -eq 1 && "$cleaned_devicename" =~ .*[0-9]+$ ]]; then
        report "you've selected to override partition check (ie making sure you select device, not its partition.)"
        confirm "are you sure that [$cleaned_devicename] is the device you wish to select?" || return 1
    fi

    #echo "please provide passwd for running fdisk -l to confirm the selected device is the right one:"
    #sudo fdisk -l $device
    readonly full_lsblk_output="$(lsblk)" || { err "issues running lsblk"; return 1; }
    echo "$full_lsblk_output" | grep --color=auto -- "$cleaned_devicename\|MOUNTPOINT"
    confirm  "\nis selected device [$device] the correct one? (y/n)" || { report "aborting, nothing written."; return 1; }

    # find if device is mounted:
    #lsblk -o name,size,mountpoint /dev/sda
    report "unmounting [$cleaned_devicename] partitions... (may ask for sudo password)"
    for partition in ${device}* ; do
        echo "$full_lsblk_output" | grep -Eq "${partition##*/}\b" || continue  # not all partitions are listed by lsblk; dunno what's with that

        mountpoint="$(lsblk -o mountpoint -- "$partition")" || { err "some issue occurred running [lsblk -o mountpoint ${partition}]"; return 1; }
        mountpoint="$(echo "$mountpoint" | sed -n 2p)"
        if [[ -n "$mountpoint" ]]; then
            report "[$partition] appears to be mounted at [$mountpoint], trying to unmount..."
            if ! sudo umount "$mountpoint"; then
                err "something went wrong while unmounting [$mountpoint]. please unmount the device and try again."
                return 1
            fi
            report "...success."
        fi
    done

    [[ "$reverse" -eq 1 ]] && { inf="$device"; ouf="$file"; } || { inf="$file"; ouf="$device"; }

    echo
    confirm "last confirmation: wish to write [$inf] into [$ouf]?" || { report "aborting."; return 1; }
    report "Please provide sudo passwd for running dd:"
    sudo echo
    clear

    report "Running dd, writing [$inf] into [$ouf]; this might take a while..."
    sudo dd if="$inf" of="$ouf" bs=4M status=progress || err "some error occurred while running dd (err code [$?])"
    sync  # to check sync progress in separate terminal, do  $ watch -d grep -e Dirty: -e Writeback: /proc/meminfo
    #eject $device

    # TODO:
    # verify integrity:
    #md5sum mydisk.iso
    #md5sum /dev/sr0
}


# display hardware
# see also: hardinfo, lscpu
#
# all with -s flag to run as sudo (for additional info)
hw() {
    local opt sudo OPTIND

    while getopts 's' opt; do
        case "$opt" in
            s) sudo=sudo ;;
            *) err "incorrect opt [$opt]"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"


    check_progs_installed inxi || return 1
    $sudo inxi -F
}


iostat-monit() {
    local opt OPTIND interval_sec clean path _cmd

    interval_sec=2  # default
    while getopts 'i:c' opt; do
        case "$opt" in
            i) interval_sec="$OPTARG" ;;
            c) clean=TRUE ;;
            *) err "unsupported opt [$opt]"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ "$#" -gt 1 ]] && { err "max 1 arg (path) accepted"; return 1; }
    path="${1:-$HOME}"

    [[ -d "$path" ]] || { err "provided path [$path] is not a dir"; return 1; }
    is_positive "$interval_sec" || { err "interval needs to be positive int, but was [$interval_sec]"; return 1; }
    check_progs_installed  iostat findmnt || return 1

    _cmd() {
        local device
        device="$(findmnt --target "$path" | awk 'END {print $2}')" || return 1
        iostat -xm "$interval_sec" "$device"
        #iostat --human -xm "$interval_sec" "$device"
    }

    # note -F '[ ]' option for awk is to preserve original whitespace
    if [[ -n "$clean" ]]; then
        # terse version, only printing device_name & util:
        _cmd | awk -F '[ ]' '!/^(Device|Linux|$|avg-cpu|\s+)/ {$1="\033[32m" $1 "\033[0m";if($NF<75){$NF="\033[1;34m" $NF "\033[0m"};if($NF>=75 && $NF<90){$NF="\033[1;35m" $NF "\033[0m"};if($NF>=90){$NF="\033[1;31m" $NF "\033[0m"};print $1, $NF}'
        # ...and longer version, preserving the original output:
        #_cmd | awk -F '[ ]' '!/^(Device|Linux|$|avg-cpu|\s+)/ {$1="\033[32m" $1 "\033[0m";if($NF<75){$NF="\033[1;34m" $NF "\033[0m"};if($NF>=75 && $NF<90){$NF="\033[1;35m" $NF "\033[0m"};if($NF>=90){$NF="\033[1;31m" $NF "\033[0m"};print}'
    else
        _cmd
    fi

    unset _cmd
}

#######################
## Setup github repo ##
#######################
mkgit() {
    local user passwd repo dir project_name OPTIND opt usage mainOptCounter http_statuscode
    local newly_created_dir curl_output namespace_id namespace is_private

    mainOptCounter=0
    is_private=true  # by default create private repos
    readonly usage="usage:   $(funname)  -g|-b|-w [-p] <dir> [project_name]
           -g   create repo in github
           -b   create repo in bitbucket
           -w   create repo at work
           -p   create a public repo (default is private)

     if  [project_name]  is not given, then project name will be same as  <dir>"

    while getopts 'hgbwp' opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           g) user=laur89
              namespace="$user"
              repo="github.com"
              let mainOptCounter+=1
              ;;
           b) user=layr
              namespace="$user"
              repo="bitbucket.org"
              let mainOptCounter+=1
              ;;
           w) err 'work profile not enabled';
              return 1

              user=laliste
              repo="$(getnetrc "${user}@git.url.workplace")"
              let mainOptCounter+=1
              ;;
           p) is_private=false
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly dir="${1%/}"  # strip trailing slash
    project_name="$2"
    if [[ -z "$project_name" ]]; then
        # default to $dir:
        [[ -d "$dir" ]] && project_name="$(basename -- "$(realpath -- "$dir")")" || project_name="$dir"  # this is so 'mkgit .' would work
    fi

    readonly curl_output="/tmp/curl_create_repo_output_${RANDOM}.out"

    if [[ "$mainOptCounter" -gt 1 ]]; then
        err "-g, -w and -b flags are exclusive."
        echo -e "$usage"
        return 1
    elif [[ "$mainOptCounter" -eq 0 ]]; then
        err "need to select a repo to create new project in."
        echo -e "$usage"
        return 1
    elif [[ "$#" -gt 2 ]]; then
        err "too many arguments"
        echo -e "$usage"
        return 1
    elif ! check_progs_installed git getnetrc curl jq; then
        return 1
    elif [[ -z "$dir" ]]; then
        err "need to provide dir at minimum"
        echo -e "$usage"
        return 1
    elif [[ -d "$dir/.git" ]]; then
        err "[$dir] is already a git repo. abort."
        return 1
    elif is_git; then
        err "you're already in a git project; don't nest them."
        return 1
    elif [[ "$project_name" == */* ]]; then
        err "project name [$project_name] contains slashes."
        return 1
    elif ! check_connection -w "$repo"; then  # -w as bitbucket.org doesn't respond to ping
        err "no connection to [$repo]"
        return 1
    fi

    if ! [[ -d "$dir" ]]; then
        command mkdir -- "$dir" || { err "[mkdir $dir] failed w/ $?"; return 1; }
        readonly newly_created_dir=1
    fi

    # sanity in case:
    if ! [[ -d "$dir" && -w "$dir" ]]; then
       err "we were unable to create dir [$dir], or it simply doesn't have write permission."
       return 1
    fi

    passwd="$(getnetrc "${user}@${repo}")"
    if [[ "$?" -ne 0 || -z "$passwd" ]]; then
        err "getting password failed. abort."
        [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
        return 1
    fi

    # offers user to choose the gitlab namespace/group to create project in.
    # doesn't return, but defines fun-global vars 'namespace' & 'namespace_id'
    __select_namespace() {
        local gitlab_namespaces_json namespace_to_id is_id_field i j fzf_selection

        # https://forum.gitlab.com/t/create-a-new-project-in-a-group-using-api/1552/2
        #
        # find our namespaces:
        readonly gitlab_namespaces_json="$(curl --fail -sSL --insecure \
            --header "PRIVATE-TOKEN: $passwd" \
            --max-time 5 --connect-timeout 2 \
            "https://${repo}/api/v3/namespaces?per_page=300")"

        [[ "$gitlab_namespaces_json" == '[{"'* ]] || { err "found namespaces curl reply isn't expected json array: $gitlab_namespaces_json"; return 1; }

        is_id_field=0
        declare -A namespace_to_id
        while read -r i; do
            [[ "$is_id_field" -eq 0 ]] && { j="$i"; is_id_field=1; continue; }

            [[ -z "$j" ]] && { err "found namespace name was empty string; gitlab namespaces json response: $gitlab_namespaces_json"; return 1; }
            is_digit "$i" || { err "found namespace id [$i] was not a digit; gitlab namespaces json response: $gitlab_namespaces_json"; return 1; }
            namespace_to_id[$j]="$i"
            fzf_selection+="${j}\n"
            is_id_field=0
        done <  <(echo "$gitlab_namespaces_json" | jq -r '.[] | .path,.id')

        readonly fzf_selection="${fzf_selection:0:$(( ${#fzf_selection} - 2 ))}"  # strip the trailing newline
        namespace="$(echo -e "$fzf_selection" | fzf --exit-0)" || return 1  # TODO: delegate to generic select_items()
        namespace_id="${namespace_to_id[$namespace]}"
        is_digit "$namespace_id" || { err "unable to find namespace id from name [$namespace]"; return 1; }

        return 0
    }

    # create remote repo, if not existing (note: repo existence check doesn't work for gitlab, as $user is really the group/namespace):
    if ! git ls-remote "git@${repo}:${user}/${project_name}" &> /dev/null; then
        case "$repo" in
            'github.com')
                readonly http_statuscode="$(curl --fail -sSL \
                    -w '%{http_code}' \
                    --max-time 4 --connect-timeout 1 \
                    -H 'Accept: application/vnd.github+json' \
                    -H "Authorization: Bearer $passwd" \
                    https://api.github.com/user/repos \
                    -d "{ \"name\":\"$project_name\", \"private\":$is_private }" \
                    -o "$curl_output")"
                ;;
            'bitbucket.org')
                readonly http_statuscode="$(curl --fail -sSL -X POST \
                    -w '%{http_code}' \
                    --max-time 5 --connect-timeout 2 \
                    -H 'Content-Type: application/json' \
                    -H 'Accept: application/json' \
                    -u "$user:$passwd" \
                    "https://api.bitbucket.org/2.0/repositories/$user/$project_name" \
                    -d "{ \"scm\": \"git\", \"is_private\": $is_private, \"fork_policy\": \"no_public_forks\" }" \
                    -o "$curl_output")"
                ;;
            # TODO: remove this work-specific gitlab logic?:
            "$(getnetrc "${user}@git.url.workplace")")
                [[ "$is_private" == true ]] && is_private=0 || is_private=10  # 0 = private, 10 = internal, 20 = public
                __select_namespace || { [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"; unset __select_namespace; return 1; }  # delete the dir we just created
                unset __select_namespace
                readonly http_statuscode="$(curl --fail -sSL --insecure \
                    -w '%{http_code}' \
                    --max-time 5 --connect-timeout 2 \
                    --header "PRIVATE-TOKEN: $passwd" \
                    -X POST "https://${repo}/api/v3/projects?name=${project_name}&namespace_id=${namespace_id}&visibility_level=$is_private" \
                    -o "$curl_output")"
                ;;
            *)
                err "unexpected repo [$repo]"
                [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
                return 1
                ;;
        esac

        if [[ "${#http_statuscode}" -ne 3 || "$http_statuscode" != 20* ]]; then
            err "curl request for creating the repo @ [$repo] failed w/ [$http_statuscode]"
            if [[ -f "$curl_output" ]]; then
                err "curl output can be found in [$curl_output]. contents are:\n\n"
                jq . < "$curl_output"
            fi
            echo
            err "abort"

            [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
            return 1
        fi

        report "created new repo @ [${repo}/${namespace}/${project_name}]"
        echo
    fi

    pushd -- "$dir" &> /dev/null || return 1
    git init || { err "bad return from git init - code [$?]"; return 1; }
    git remote add origin "git@${repo}:${namespace}/${project_name}.git" || { err "adding remote failed. abort."; return 1; }
    echo

    if confirm "add README.md? (recommended)"; then
        report "adding README.md ..."
        touch README.md
        git add README.md
        git commit -a -m 'inital commit, adding readme - automated'
        git push -u origin master  # note 'master' is set in our gitconfig @ init.defaultBranch
    fi

    unset __select_namespace
}

########################################
## Open file inside git tree with vim ##
########################################
gito() {
    local src matches git_root cwd i

    readonly src="$*"

    readonly cwd="$PWD"
    declare -a matches

    if [[ "$__REMOTE_SSH" -ne 1 ]]; then
        check_progs_installed git fzf || return 1
    fi

    is_git || { err "not in git repo."; return 1; }

    readonly git_root="$(get_git_root)" || { err "unable to find project root"; return 1; }

    if [[ -n "$src" ]]; then
        if [[ "$src" == *\** && "$src" != *\.\** ]]; then
            err 'use .* as wildcards, not a single *'
            return 1
        elif [[ "$(echo "$src" | tr -dc '.' | wc -m)" -lt "$(echo "$src" | tr -dc '*' | wc -m)" ]]; then
            err "nr of periods (.) was less than stars (*); are you misusing regex?"
            return 1
        fi
    fi

    # TODO: instead of cd-ing to repo root and running ls-files, you might
    # want to use ls-tree (w/ --full-tree -r --full-name <branch/ref> maybe...)
    __git_ls_fun() {
        git ls-files --recurse-submodules | grep -Ei -- "${src:-$}"
    }

    [[ "$cwd" != "$git_root" ]] && pushd "$git_root" &> /dev/null  # git root
    if ! command -v fzf > /dev/null 2>&1; then
        while read -r i; do
            matches+=("$i")
        done < <(__git_ls_fun)

        select_items "${matches[@]}"  # don't return here as we need to change wd to starting location;
        matches=("${__SELECTED_ITEMS[@]}")
    else
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(__git_ls_fun | fzf --select-1 --multi --exit-0 --print0)
    fi

    [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back
    unset __git_ls_fun
    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found"; return 1; }

    for ((i=0; i <= (( ${#matches[@]} - 1 )); i++)); do
        matches[i]="$git_root/${matches[i]}"  # convert to absolute
    done

    __fo "${matches[@]}"
}

# git untag; git delete tag; git tag delete; delete git tag
gut() {
    local tag

    readonly tag="$*"

    is_git || { err "not in git repo"; return 1; }
    [[ -z "$tag" ]] && { err "need to provide tag to delete."; return 1; }
    git_tag_exists "$tag" || { err "tag [$tag] does not exist. abort."; return 1; }
    git tag -d "$tag" || { err "deleting tag [$tag] locally failed. abort."; return 1; }
    git push origin ":refs/tags/$tag"
    return $?
}

# copy & print latest tag ver:
glt() {
    local last_tag

    is_git || { err "not in git repo"; return 1; }
    last_tag="$(get_git_last_tag)" || return 1

    [[ -z "$last_tag" ]] && { report "no tags found"; return 1; }
    report "latest tag: [$last_tag]"
    copy_to_clipboard "$last_tag" || { err "unable to copy tag to clipboard."; return 1; }
    return $?
}


# Prepares list of logical version increments (from provided version) and prompts
# the user to choose one.
#
# @param {string}  ver   version to increment. may contain postfix.
#
# @returns {void}  doesn't return a value (because involvement of select_items()),
#                  but sets the selected version increment at global $__SELECTED_ITEMS
increment_version() {
    local ver vers

    ver="$1"

    declare -a vers=( $(sort -u < <(
        __increment_version_next_major_or_minor "$ver" 0;
        __increment_version_next_major_or_minor "$ver" 1;
        __increment_version_next_major_or_minor "$ver" 2;
        echo custom)
    ) ) || { err; return 1; }

    select_items -s "${vers[@]}"

    if [[ "$__SELECTED_ITEMS" == custom ]]; then
        read -rp 'enter version: ' ver
        __SELECTED_ITEMS=("$ver")
    fi

    [[ -z "${__SELECTED_ITEMS[*]}" ]] && { err "no version selected"; return 1; }
    return 0
}


# git flow feature start
gffs() {
    local branch

    branch="$1"

    if [[ "$branch" =~ ^features?/[a-zA-Z_-]+$ ]]; then
        branch="${branch##*/}"  # strip everything before last slash (slash included)
    fi

    if [[ -z "$branch" ]]; then
        err "need to provide feature branch name to create/start"
        return 1
    elif [[ "$branch" == */* ]]; then
        err "there are slashes in the branchname. need to provide the child branch name only, not [feature/...]"
        return 1
    elif git_branch_exists "feature/$branch"; then
        err "branch [feature/$branch] already exists on remote."
        return 1
    elif [[ "$(get_git_branch)" != develop ]]; then
        confirm "you're not on develop; note that $(funname)() creates new feature branches off of develop. continue?" || return
    fi

    git checkout master && git pull && git checkout develop && git pull || { err "pulling master and/or develop failed. abort."; return 1; }
    git flow feature start -F "$branch" || { err "starting git feature failed."; return 1; }
    return $?
}


# git flow feature publish
gffp() {
    [[ "$(get_git_branch)" != feature/* ]] && { err "need to be on a feature branch for this."; return 1; }
    git flow feature publish
}


# git flow feature finish
gfff() {
    local branch

    [[ -n "$1" ]] && readonly branch="$1" || readonly branch="$(get_git_branch --child)"

    if [[ "$(get_git_branch)" != feature/* ]]; then
        err "should be on a feature branch"
        return 1
    elif [[ -z "$branch" ]]; then
        err "need to provide feature branch to finish"
        return 1
    elif [[ "$branch" == */* ]]; then
        err "there are slashes in the branchname. need to provide the child branch name only, not [feature/...]"
        return 1
    fi

    git checkout master && git pull && git checkout develop && git pull || { err "pulling master and/or develop failed. abort."; return 1; }
    git flow feature finish -F "$branch" || { err "finishing git feature failed."; return 1; }

    # push the merged develop commit:
    #if [[ "$(get_git_branch --child)" == develop ]]; then
    git push || { err "pushing to [$(get_git_branch)] failed."; return 1; }
    return $?
}


# helper function for gfrs & gfrf.
#
# pass -p or --push as first arg in order to push as well
# (eg no point to push release branches).
#
# ex: f  [-p]  1.2.3  file1  [file2...]
__verify_files_changes_and_commit() {
    local ver files push

    [[ "$1" == "-p" || "$1" == "--push" ]] && { push=1; shift; }
    ver="$1"; shift
    declare -a files=("$@")

    echo
    git diff
    confirm "\nverify changes look ok. continue?" || return 1
    git add "${files[@]}" || return 1
    git commit -m "Bump version to $ver" || { err "git commit failed with [$?]"; return 1; }
    if [[ "$push" -eq 1 ]]; then
        git push
        return $?
    fi
    return 0
}


# git flow release start
gfrs() {
    local tag last_tag expected_tags pom_ver pom pom_wo_postfix i

    tag="$1"
    is_git || { err "not in git repo."; return 1; }

    __ask_ver() {
        if [[ -n "$pom_ver" ]]; then
            [[ "$pom_wo_postfix" =~ ^[0-9\.]+$ ]] || { err "maven/pom ver [$pom_wo_postfix] is in an unexpected format." -1; return 1; }
            confirm "tag as ver [${COLORS[GREEN]}${pom_wo_postfix}${COLORS[OFF]}]? (derived from current pom ver [$pom_ver])" && { tag="$pom_wo_postfix"; return 0; }
        fi

        read -rp 'enter tag ver to create: ' tag
        [[ -z "$tag" ]] && { err "need to provide release tag to create" -1; return 1; }
        return 0
    }

    declare -a expected_tags

    pom="$(get_git_root)/pom.xml" || { err "unable to find git root"; return 1; }
    pom_ver="$(grep -Pos -m 1 '^\s+<version>\K.*(?=</version>.*)' "$pom" 2>/dev/null)"  # ignore errors; if no pom, let the var remain empty.
    pom_wo_postfix="$(grep -Eos '^[0-9\.]+' <<< "$pom_ver" 2>/dev/null)"

    if [[ -z "$tag" ]]; then
        __ask_ver || { unset __ask_ver; return 1; }
    fi
    unset __ask_ver

    if [[ -z "$tag" ]]; then
        err "no tag version specified"; return 1
    elif [[ "$tag" == */* ]]; then
        err "there are slashes in the tag. need to provide the child tag ver only, not [release/...]"
        return 1
    elif git_branch_exists "release/$tag"; then
        err "branch [release/$tag] already exists on remote."
        return 1
    elif git_tag_exists "$tag"; then
        err "tag [$tag] already exists."
        return 1
    fi

    # try to predict logical tag names based on latest tag and, if available, pom file.
    # if provided tag is not one of them, ask for confirmation.
    last_tag="$(get_git_last_tag)" || { err "problems finding latest tag. this was found as latest tag: [$last_tag]"; unset last_tag; }
    if [[ -n "$last_tag" ]]; then  # tag exists
        expected_tags=( $(sort -u < <(
            __increment_version_next_major_or_minor "$last_tag" 0;
            __increment_version_next_major_or_minor "$last_tag" 1;
            __increment_version_next_major_or_minor "$last_tag" 2;
            echo "$pom_wo_postfix";
            )
        ) ) || { err "something blew up"; return 1; }
    else
        expected_tags=("$pom_wo_postfix")  # no biggie if pom_wo_postfix is null
    fi

    if [[ -n "${expected_tags[*]}" ]] && ! list_contains "$tag" "${expected_tags[@]}"; then
        confirm "tag [${COLORS[GREEN]}${COLORS[BOLD]}${tag}${COLORS[OFF]}] is not of expected increment\n   (expected one of  $(build_comma_separated_list "${expected_tags[@]}"))\n\ncontinue anyways?" || return
    fi

    git checkout master && git pull && git checkout develop && git pull || { err "pulling master and/or develop failed. abort."; return 1; }
    git flow release start -F "$tag" || { err "git flow relstart failed"; return 1; }

    if [[ -n "$pom_ver" ]]; then  # we're dealing with a maven project
        [[ "$pom_ver" =~ ^[0-9\.]+(-SNAPSHOT)?$ ]] || { err "fyi: current maven/pom ver [$pom_ver] is in an unexpected format.\n"; sleep 3; }
        # replace pom ver:
        sed -i "0,/<version>.*</s//<version>${tag}</" "$pom" || { err "switching versions with sed failed"; return 1; }
        [[ "$(grep -c '<tag>HEAD</t' "$pom")" -gt 1 ]] && { err "unexpected number of <tag>HEAD</tag> tags in pom"; return 1; }
        sed -i "0,/<tag>HEAD</s//<tag>${tag}</" "$pom" || { err "switching scm tag versions with sed failed"; return 1; }
        __verify_files_changes_and_commit "$tag" "$pom" || return 1
    fi
}


# git flow release finish
gfrf() {
    local tag pom pom_ver next_dev

    is_git || { err "not in git repo."; return 1; }
    [[ -n "$1" ]] && readonly tag="$1" || readonly tag="$(get_git_branch --child)"

    if [[ "$(get_git_branch)" != release/* ]]; then
        err "should be on a release branch"
        return 1
    elif [[ -z "$tag" ]]; then
        err "need to provide release tag to finish"
        return 1
    elif [[ "$tag" == */* ]]; then
        err "there are slashes in the tag. need to provide the child tag ver only, not [release/...]"
        return 1
    fi

    pom="$(get_git_root)/pom.xml" || { err "unable to find git root"; return 1; }
    pom_ver="$(grep -Pos -m 1 '^\s+<version>\K.*(?=</version>.*)' "$pom" 2>/dev/null)"  # ignore errors; if no pom, let the var remain empty.

    if [[ -n "$pom_ver" ]]; then  # we're dealing with a maven project
        # check tests _before_ tagging; TODO: do we want to run test as part of gfrf()?
        #mvn clean install || { err "fix tests"; return 1; }
        true  # TODO: should we run clean install here or not?
    fi
    git flow release finish -F -p "$tag" || { err "finishing git release failed."; return 1; }
    report "pushing tags..."
    git push --tags || { err "...pushing tags failed."; return 1; }
    # now you should be on develop

    if [[ -n "$pom_ver" ]]; then  # we're dealing with a maven project
        report "select next development version"
        increment_version "${tag}-SNAPSHOT" || { err "increment_version() failed."; return 1; }
        next_dev="$__SELECTED_ITEMS"

        # replace pom ver:
        sed -i "0,/<version>${tag}</s//<version>${next_dev}</" "$pom" || { err "switching versions with sed failed"; return 1; }
        sed -i "0,/<tag>${tag}</s//<tag>HEAD</" "$pom" || { err "switching scm tag version with sed failed"; return 1; }
        __verify_files_changes_and_commit --push "$next_dev" "$pom" || return 1

        report "deploying to nexus..."
        git checkout "$tag" || { err "unable to check out [$tag]"; return 1; }
        mvn clean deploy -Dmaven.test.skip=true || { err "mvn deployment failed"; return 1; }
        git checkout develop || { err "unable to check out [develop]"; return 1; }
    fi

    return 0
}


# helper scriplet for git housecleaning
# following git snippets are from   http://railsware.com/blog/2014/08/11/git-housekeeping-tutorial-clean-up-outdated-branches-in-local-and-remote-repositories/
git-show-merged-branches() {
    local branch

    #git branch --merged    for local branches

    # --no-merged for branches that haven't been merged to currently checked out branch;
    for branch in $(git branch -r --merged | grep -v HEAD); do
        echo -e "$(git show --format="%ci %cr %an" $branch | head -n 1) \\t$branch"
    done | sort -r
}


# ag looks for whole file path!
ago() {
    local DMENU match dmenurc editor

    err "ag is not playing along at the moment. see fo()"
    return 1

    readonly dmenurc="$HOME/.dmenurc"
    readonly editor="$EDITOR"

    check_progs_installed ag "$editor" dmenu || return 1
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    [[ -z "$*" ]] && { err "args required."; return 1; }

    match="$(ag -g "$@")" || return 1

    [[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | $DMENU -l 20 -p open)"
    [[ -z "$match" ]] && return 1

    [[ -f "$match" ]] || { err "[$match] is not a regular file."; return 1; }
    $editor "$match"
}


# same as fo(), but opens all the found results; forces regular filetype search.
#
# mnemonic: file open all
foa() {
    local opts default_depth matches i

    opts="$1"

    readonly default_depth="m10"
    declare -a matches=()

    if [[ "$opts" == -* ]]; then
        opts="-L${opts:1}"
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"  # depth opt has to come last
        #echo $opts  # debug

        shift
    else
        opts="-fL${default_depth}"
    fi

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$opts" "$@")

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found"; return 1; }
    __fo "${matches[@]}"
}


# finds files/dirs and DELETES them
# Note: does not dereference links by default.
#
# mnemonic: file open delete
fod() {
    local matches i

    declare -a matches=()

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$@")

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found"; return 1; }

    report "found [${#matches[@]}] nodes:"
    for i in "${matches[@]}"; do
        echo -e "\t${i}"
    done

    if confirm "wish to DELETE them?"; then
        rm -r -- "${matches[@]}" || { _FOUND_FILES=("${matches[@]}"); err "something went wrong while deleting. (stored the files in \$_FOUND_FILES array)"; return 1; }
    fi
}


# finds files/dirs and goes to containing dir (or same dir if found item is already a dir)
# mnemonic: file open go
#
# with fzf, $ _goto <ctrl-t>   offers perhaps better results
fog() {
    local opts default_depth matches i

    opts="$1"

    readonly default_depth="m6"
    declare -a matches=()

    if [[ "$opts" == -* ]]; then
        opts="-L${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-L${default_depth}"
    fi

    [[ "$#" -eq 0 ]] && { err "too few args."; return 1; }

    if ! command -v fzf > /dev/null 2>&1; then
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@")

        select_items -s "${matches[@]}" || return 1
        matches=("${__SELECTED_ITEMS[@]}")
    else
        while read -r i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@" | fzf --select-1 --read0 --exit-0)
    fi

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found"; return 1; }

    _goto "${matches[@]}"
}

# mnemonic: go go
gg() { fog "$@"; }


# open newest file (as in with last mtime);
#
# takes optional last arg (digit) to select 2nd, 3rd...nth newest instead.
#
# if no args provided, then searches for '*';
# if no depth arg provided, then defaults to current dir only.
#
# TODO: the nth result selection only works, if name arg was provided, meaning `fon 2`
# won't give expeted result. edit: imho it's reasonable; we can't limit searching for files by digits.
#
# mnemonic: file open new(est)
fon() {
    local opts default_depth matches newest n i

    opts="$1"

    readonly default_depth="m1"
    declare -a matches=()

    if [[ "$opts" == -* ]]; then
        opts="-L${opts:1}"
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-fL${default_depth}"
    fi

    check_progs_installed stat sort || return 1

    if [[ "$#" -eq 1 ]] && is_digit "$1" && [[ "$1" -gt 0 ]]; then
        report "note if you really wanted the ${1}. newest, then filename pattern should be provided as first arg\n"

    # try to filter out optional last arg defining the nth newest to open (as in open the nth newest file):
    elif [[ "$#" -gt 1 ]]; then
        n="${@: -1}"  # last arg; alternatively ${@:$#}
        if is_digit "$n" && [[ "$n" -ge 1 ]] && [[ "$#" -gt 2 || ! -d "$n" ]]; then  # $# -gt 2   means dir is already being passed to ffind(), so no need to check !isDir
            set -- "${@:1:${#}-1}"  # shift the last arg
        else
            unset n
        fi
    fi

    [[ -z "$n" ]] && readonly n=1

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$opts" "$@")
    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found"; return 1; }

    [[ "$n" -gt "${#matches[@]}" ]] && { err "cannot open [${n}th] newest file, since total nr of found files was [${#matches[@]}]"; return 1; }

    readonly newest="$(stat --format='%Y %n' -- "${matches[@]}" \
            | sort -r -k 1 \
            | sed -n ${n}p \
            | cut -d ' ' -f 2-)"

    [[ -f "$newest" ]] || { err "something went wrong, found newest file [$newest] is not a valid file."; return 1; }
    __fo "$newest"
}


# open file with specified program
#
# program to open file(s) with is to be specified as a last arg
#
# mnemonic: file open with
fow() {
    local opts default_depth prog matches i

    opts="$1"

    readonly default_depth="m10"
    declare -a matches=()

    if [[ "$opts" == -* ]]; then
        opts="-L${opts:1}"
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-fL${default_depth}"
    fi

    [[ "$#" -le 1 ]] && { err "too few args."; return 1; }

    # filter out prog name
    readonly prog="${@: -1}"  # last arg; alternatively ${@:$#}
    [[ -d "$prog" ]] && report "last arg needs to be the program to open with, not dir arg for ffind"
    if ! command -v -- "$prog" >/dev/null; then
        err "[$prog] is not installed."
        return 1
    fi

    set -- "${@:1:${#}-1}"  # shift the last arg

    if ! command -v fzf > /dev/null 2>&1; then
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@")

        select_items "${matches[@]}" || return 1
        matches=("${__SELECTED_ITEMS[@]}")
    else
        while read -r i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@" | fzf --select-1 --multi --read0 --exit-0)
    fi

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found"; return 1; }
    report "opening [${COLORS[YELLOW]}${COLORS[BOLD]}${matches[*]}${COLORS[OFF]}] with [${COLORS[GREEN]}${COLORS[BOLD]}$prog${COLORS[OFF]}]"
    $prog -- "${matches[@]}"
}


# collect all found files into global array
foc() {
    local opts default_depth matches i

    opts="$1"

    readonly default_depth="m10"
    declare -a matches=()

    if [[ "$opts" == -* ]]; then
        opts="-L${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-L${default_depth}"
    fi

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$opts" "$@")

    report "found ${#matches[@]} files; stored in \$_FOUND_FILES arr."
    _FOUND_FILES=("${matches[@]}")

    return
}


# finds files/dirs using ffind() (find wrapper) and opens them.
#
# if no args provided, then defaults to opening regular files in current dir.
#
# mnemonic: file open
fo() {
    local matches opts default_depth

    opts="$1"
    readonly default_depth=m5
    declare -a matches=()

    if [[ -z "$*" ]]; then
        opts='-fLm1'  # note defaulting to -m1
    elif [[ "$opts" == -* ]]; then
        opts="-L${opts:1}"
        [[ "$opts" =~ [fdl] ]] || opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-fL${default_depth}"
    fi

    if ! command -v fzf > /dev/null 2>&1; then
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@")

        select_items "${matches[@]}" || return 1
        __fo "${__SELECTED_ITEMS[@]}"
    else
        #while IFS= read -r -d $'\0' i; do
            #matches+=("$i")
        #done < <(ffind --_skip_msgs "$@" | fzf --select-1 --multi --read0 | __fo)
        ffind --_skip_msgs "$opts" "$@" | fzf --select-1 --multi --read0 --exit-0 | __fo  # add --print0 to fzf once implemented; also update __fo
    fi
}


__fo() {
    local files count filetype editor image_viewer video_player file_mngr
    local pdf_viewer office image_editor pager i

    editor="$EDITOR"
    image_viewer="nsxiv"
    video_player="mpv"
    file_mngr="vifm"
    pdf_viewer="zathura"
    office="libreoffice"
    image_editor="gimp"
    pager="$PAGER"

    declare -a files=()

    check_progs_installed file || return 1

    if [[ -z "$*" ]]; then  # no params provided, meaning expect input via stdin
        #while IFS= read -r -d $'\0' i; do  # TODO enable once fzf gets the --print0 option
        while read -r i; do  # TODO: add -t <sec>  for timeout in read?
            files+=("$i")
        done
    else  # $FUNCNAME was invoked with arguments, not feeding files via stdin;
        files=("$@")
    fi

    [[ "${#files[@]}" -eq 0 ]] && return  # quit silently
    readonly count="${#files[@]}"
    # define filetype only by the first node:  # TODO: perhaps verify all nodes are of same type?
    readonly filetype="$(file -iLb -- "${files[0]}")" || { err "issues testing [${files[0]}] with \$ file cmd" -1; return 1; }

    # report files to be opened
    if [[ "$count" -eq 1 ]]; then
        report "opening [${COLORS[YELLOW]}${COLORS[BOLD]}${files[*]}${COLORS[OFF]}]" -1
    else
        report "opening:" -1
        for i in "${files[@]}"; do
            echo -e "\t${COLORS[YELLOW]}${COLORS[BOLD]}${i}${COLORS[OFF]}"
        done
    fi

    add_nodes_to_fasd "${files[@]}"

    case "$filetype" in
        'image/x-xcf; charset=binary')  # xcf is gimp
            check_progs_installed "$image_editor" || return 1
            "$image_editor" -- "${files[@]}" &
            ;;
        image/*)
            check_progs_installed "$image_viewer" || return 1
            "$image_viewer" -- "${files[@]}" &
            ;;
        application/octet-stream*)
            # should be the logs on app servers; TODO: shall we default to $editor and only use $pager based on... file extension?
            check_progs_installed "$pager" || return 1
            "$pager" -- "${files[@]}"
            ;;
        application/xml*)
            [[ "$count" -gt 1 ]] && { report "won't format multiple xml files! will just open them" -1; sleep 1.5; }
            if [[ "$count" -gt 1 || "$(wc -l < "${files[0]}")" -gt 2 ]]; then  # note if more than 2 lines we also assume it's already formatted;
                # note we're assuming it's already formatted if more than 2 lines;
                check_progs_installed "$editor" || return 1
                "$editor" < /dev/tty -- "${files[@]}"
            else
                xmlformat "${files[@]}"
            fi
            ;;
        video/* | audio/mp4*)
            check_progs_installed "$video_player" || return 1
            "$video_player" -- "${files[@]}" &
            ;;
        text/*)
            # if we're dealing with a logfile (including *.out), force open in pager
            if [[ "${files[0]}" =~ \.(log|out)(\.[.a-z0-9]+)?$ ]]; then
                check_progs_installed "$pager" || return 1
                "$pager" -- "${files[@]}"
            else
                check_progs_installed "$editor" || return 1
                "$editor" < /dev/tty -- "${files[@]}"
            fi
            ;;
        application/pdf*)
            check_progs_installed "$pdf_viewer" || return 1
            "$pdf_viewer" -- "${files[@]}" &
            ;;
        application/x-elc* \
                | application/*json* \
                | 'application/javascript; charset='* \
                | 'inode/x-empty; charset=binary' \
                | *'charset=us-ascii')  # TODO: what exactly is x-elc*?
            check_progs_installed "$editor" || return 1
            "$editor" < /dev/tty -- "${files[@]}"
            ;;
        'application/x-executable; charset=binary'*)
            [[ "$count" -gt 1 ]] && { report "won't execute multiple files! select one please" -1; return 1; }
            confirm "${files[*]} is executable. want to launch it from here?" || return
            report "launching ${files[0]}..." -1
            ${files[0]}
            ;;
        'inode/directory;'*)
            [[ "$count" -gt 1 ]] && { report "won't navigate to multiple dirs! select one please" -1; return 1; }
            check_progs_installed "$file_mngr" || return 1
            "$file_mngr" "${files[0]}"  # optionally 'cd'
            ;;
        # try keeping doc files' definitions in sync with the ones in ffind()
        'application/msword; charset=binary' \
                | 'application/'*'opendocument'*'; charset=binary' \
                | 'application/'*'officedocument'*'; charset=binary' \
                | 'application/'*'ms-office; charset=binary' \
                | 'application/'*'ms-excel; charset=binary')
            check_progs_installed "$office" || return 1
            "$office" "${files[@]}" &  # libreoffice doesn't like option ending marker '--'
            ;;
        *)
            err "dunno what to open this type of file with: [$filetype]" -1
            return 1
            ;;
    esac
}

# note id doesn't have to add _only_ to fasd, can also update other databases
add_nodes_to_fasd() {
    [[ -z "$*" ]] && return
    command -v fasd > /dev/null 2>&1 && fasd -A "$@"
}

sethometime() { setspaintime; }  # home is where you make it;

setromaniatime() {
    __settz Europe/Bucharest
}

setturkeytime() {
    __settz Asia/Istanbul
}

setgeorgiatime() {
    __settz Asia/Tbilisi
}

setestoniatime() {
    __settz Europe/Tallinn
}

setgibtime() {
    __settz Europe/Gibraltar
}

setspaintime() {
    __settz Europe/Madrid
}

# as per /usr/share/doc/tzdata/README.Debian
__settz() {
    local tz zonedir

    readonly tz="$*"
    readonly zonedir='/usr/share/zoneinfo'  # as per file/docs above

    check_progs_installed timedatectl || return 1
    [[ -z "$tz" ]] && { err "provide a timezone to switch to (e.g. Europe/Madrid)." -1; return 1; }
    [[ "$tz" =~ ^[A-Z][a-z]+/[-_A-Za-z]+$ ]] || { err "invalid timezone format; has to be in a format like [Europe/Madrid]" -1; return 1; }
    [[ -e "$zonedir/$tz" ]] || { err "[$zonedir/$tz] does not exist; sure about your tz?" -1; return 1; }

    timedatectl set-timezone "$tz" || { err "setting tz to [$tz] failed (code $?)" -1; return 1; }
}

# fork bomb
killmenao() {
    confirm 'you sure?' || return
    clear
    report 'you ded.'
    :(){ :|:& };:
}

########################
## Print window class ##
########################
xclass() {
    check_progs_installed xprop awk || return 1

    xprop | awk '
    /^WM_CLASS/{sub(/.* =/, "instance:"); sub(/,/, "\nclass:"); print}
    /^WM_NAME/{sub(/.* =/, "title:"); print}'
}

################
## Smarter CD ##
################
# note this is fronted by goto()/gt() for interactive usage
_goto() {
    local i
    [[ -z "$*" ]] && { err "node operand required"; return 1; }

    if [[ -d "$*" ]]; then
        cd -- "$*"
    else
        i="$(readlink -f -- "$*")" && cd -- "$(dirname -- "$i")" || return 1  # readlink, as realpath might not be avail
    fi
}


# calculate md5sum of all files recursively from current PWD/given dir;
# note filenames are also taken into account!
#
# consider also py package 'checksumdir'
# https://unix.stackexchange.com/a/35834/47501
sumtree() {
    local f usage OPTIND opt usage dir

    f="$(funname)"
    readonly usage="\n$f: get cumulative md5 sum of all files of either
         given directory, or current dir (default)
         Usage: $f  [-h]  [directory]
             -h  show this help\n"

    while getopts 'h' opt; do
        case "$opt" in
           h) echo -e "$usage"; return 0 ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly dir="$1"
    [[ "$#" -gt 1 ]] && { err "max 1 arg - a directory - allowed"; return 1; }

    check_progs_installed find md5sum || return 1

    if [[ -n "$dir" ]]; then
        [[ -d "$dir" ]] || { err "directory [$dir] not a valid dir"; return 1; }
        pushd "$dir" &> /dev/null || return 1  # cd to dir in order to take relative paths
    fi

    if command -v parallel > /dev/null 2>&1; then
        find . -type f | parallel -k -n 100 md5sum -- {} | sort -k 2 | md5sum | cut -d' ' -f 1  # speeds up a bit, as it decreases number of calls to md5sum
    else
        find . -type f -exec md5sum -- {} \+ | sort -k 2 | md5sum | cut -d' ' -f 1
    fi

    # to ignore file names; note we could also bake parallel in this command as above
    #find . -type f -exec md5sum {} \; | cut -d" " -f1 | sort | md5sum

    # if you care also about metadata (ownership, perms), use tar:
    #tar -cf - ./ | md5sum

    # hashdeep alternative:
    #hashdeep -r -l -j0 -c md5 . | md5sum  # follows symlinks by default!

    [[ -n "$dir" ]] && popd &> /dev/null
}

sumdir() { sumtree "$@"; }
dirsum() { sumtree "$@"; }


# Checks if given two or more nodes have same checksums.
#
# @param {file...}   list of files/dirs whose equality to check.
#
# @returns {bool}  true if nodes are the same, else false
is_same() {
    local sum benchmark_sum n t

    if [[ "$#" -le 1 ]]; then
        err "at least 2 nodes whose equality to compare required"
        return 1
    fi

    for n in "$@"; do
        if [[ ! -e "$n" ]]; then
            err "[$n] does not exist, abort"; return 1
        elif [[ "$n" == / ]]; then
            err "do not pass / as a node"; return 1
        fi

        if [[ -z "$t" ]]; then  # i.e. first run
            if [[ -f "$n" ]]; then
                check_progs_installed md5sum || return 1
                readonly t=f
            elif [[ -d "$n" ]]; then
                readonly t=d
            else
                err "only dirs and files supported"; return 1
            fi
        elif [[ "$t" == f && ! -f "$n" ]] || [[ "$t" == d && ! -d "$n" ]]; then
            err "all passed nodes need to be of same type"
            return 1
        fi
    done

    for n in "$@"; do
        if [[ "$t" == f ]]; then
            sum="$(md5sum -- "$n" | cut -d' ' -f 1)" || { err "md5suming [$n] failed with $?"; return 1; }
        else  # we're comparing directories
            # note sumtree() is our own function
            sum="$(sumtree -- "$n" | cut -d' ' -f 1)" || { err "sumtreeing [$n] failed with $?"; return 1; }
        fi

        [[ -z "$sum" ]] && { err "empty checksum for [$n]"; return 1; }

        [[ -n "$benchmark_sum" && "$sum" != "$benchmark_sum" ]] && return 1
        benchmark_sum="$sum"
    done

    return 0
}


# Checks if given files are valid json files
#
# @param {file...}   list of files whose json-sanity to check
#
# @returns {bool}  true if all provided files contain valid json.
is_valid_json() {
    local file

    [[ "$#" -gt 0 ]] || return 2
    command -v jq >/dev/null 2>&1 || return 2

    for file in "$@"; do
        jq -reM '""' "$file" >/dev/null 2>&1 || return 1  # https://stackoverflow.com/a/67979464/1803648
    done

    return 0
}

is_json() { is_valid_json "$@"; }


# Checks if given two files are json files of same logical contents
#
# If you want diff, see json_diff()
#
# @param {file1}   first file to compare
# @param {file2}   second file to compare
#
# @returns {bool}  true if given files have same logical json contents
same_json() {
    local f1 f2
    f1="$1"
    f2="$2"

    check_progs_installed  jq || return 1
    [[ "$#" -eq 2 && -f "$f1" && -f "$f2" ]] || { err "exactly 2 args expected, both json files"; return 1; }
    is_valid_json "$f1" "$f2" || { err "both files need to contain valid json"; return 1; }
    jq -en --slurpfile a "$f1" --slurpfile b "$f2" '$a == $b' >/dev/null 2>&1
}

is_same_json() { same_json "$@"; }


json_diff() {
    local f1 f2
    f1="$1"
    f2="$2"

    check_progs_installed  jq vimdiff || return 1
    [[ "$#" -eq 2 && -f "$f1" && -f "$f2" ]] || { err "exactly 2 args expected, both json files"; return 1; }
    is_valid_json "$f1" "$f2" || { err "both files need to contain valid json"; return 1; }
    vimdiff <(jq -S . "$f1") <(jq -S . "$f2")
}

diff_json() { json_diff "$@"; }


# cd-s to directory by partial match; if multiple matches, opens input via fzf. smartcase.
#
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
        readonly pattern="$1"
        dir="${2:-.}"

        [[ "$(tolowercase "$pattern")" == "$pattern" ]] && iname_arg='iname'
        [[ "$dir" != */ ]] && dir+='/'

        find -L "$dir" -maxdepth 1 -mindepth 1 -type d -${iname_arg:-name} "*${pattern}*" -print0
    }

    # note this function sets the parent function's dir variable.
    __select_dir() {
        local pattern start_dir _dir matches
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

        [[ -z "$dir" ]] && { err "no matches found" -1; return 1; }
        [[ -d "$dir" ]] || { err "no such dir like [$dir] in $start_dir" -1; return 1; }
    }

    # note this function sets the parent function's dir variable.
    __go_up() {
        local pattern i
        readonly pattern="$1"  # dots only; guaranteed to be minimum of 3 dots.

        for ((i=0; i <= (( ${#pattern} - 2 )) ; i++)); do
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
    #echo "paths: [${paths[@]}]"

    # clean paths:
    # TODO: what if the first path element is '.'?
    for i in "${!paths[@]}"; do
        [[ -z "${paths[$i]}" || "${paths[$i]}" == . ]] && unset "paths[$i]"
    done
    [[ "${#paths[@]}" -eq 0 ]] && paths=('*')
    #echo "cleaned paths: [${paths[@]}]"

    for i in "${paths[@]}"; do
        [[ -z "$dir" && "$i" =~ ^\.{3,}$ ]] && { __go_up "$i"; is_backing=0; continue; }
        [[ "$i" != '..' ]] && is_backing=0
        __select_dir "$i" "$dir" || { unset __find_fun __select_dir __go_up; return 1; }
    done

    unset __find_fun __select_dir __go_up
    cd -- "$dir"
}


# dockers
#############################

# from http://stackoverflow.com/questions/32723111/how-to-remove-old-and-unused-docker-images
dcleanup() {
    local f usage opt OPTIND

    f="$(funname)"
    readonly usage="\n$f: clean up docker containers, volumes, images, networks

    Usage: $f  [-acivnh]

        -a  full cleanup (system prune)
        -c  remove exited containers
        -i  remove dangling & unused images
        -v  remove unused volumes
        -n  remove unused networks
        -h  display this usage info"

    check_progs_installed  docker || return 1
    [[ -z "$*" ]] && { echo -e "$usage"; return 1; }

    while getopts 'acivnh' opt; do
        case "$opt" in
           a) docker system prune --all
                ;;
           c) docker container prune
                ;;
           i) docker image prune --all
                ;;
           v) docker volume prune
                ;;
           n) docker network prune
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"
}


# display available APs and their basic info
wifilist() {
    local wifi_device_file

    readonly wifi_device_file="$_WIRELESS_IF"

    check_progs_installed nmcli || return 1

    if [[ -r "$wifi_device_file" ]]; then
        [[ -z "$(cat -- "$wifi_device_file")" ]] && err "[$wifi_device_file] is empty."
    else
        err "can't read file [$wifi_device_file]; probably you have no wireless devices."
    fi

    nmcli device wifi list
    return $?
}


keepsudo() {
    check_progs_installed sudo || return 1

    while true; do
        sudo -n true
        sleep 30
        kill -0 "$$" || exit
    done 2>/dev/null &
}


# reload new mountpoints in fstab w/o reboot.
# from https://unix.stackexchange.com/a/577321
fstab_reload() {
    report "reload mountpoints in fstab; sudo needed"

    sudo systemctl daemon-reload || { err "systemctl daemon-reload failed w/ $?"; return 1; }
    #sudo systemctl restart remote-fs.target  # to reload a remote mount, eg NFS
    #sudo systemctl restart local-fs.target  # to reload a local mount
    sudo systemctl restart remote-fs.target local-fs.target  # both local & remote
}


# select mountpoint(s) to unmount
fumount() {
    umountall.sh -s
}


# transfer.sh alias - file sharing
#
# TODO: enable also encrypted upload:
#    encrypt:
#        cat /tmp/hello.txt|gpg -ac -o- | curl -X PUT --upload-file "-" https://transfer.sh/test.txt
#    decrypt:
#        curl https://transfer.sh/1lDau/test.txt | gpg -o- > /tmp/hello.txt
#
# TODO2: log the headers, as upload header response has deletion header 'X-Url-Delete'!
# TODO3: optionally set max-downloads, max-days (to keep the file), also set by _request_ headers;
# TODO4: for alternative, see also http://ix.io/
# TODO5: retrieve&store deletion token
#
# see  https://github.com/dutchcoders/transfer.sh/
transfer() {
    local tmpfile file

    readonly file="$1"

    [[ "$#" -ne 1 || -z "$file" ]] && { err "single file to upload required"; return 1; }
    [[ -e "$file" ]] || { err "[$file] does not exist."; return 1; }
    check_progs_installed curl || return 1

    # write to output to tmpfile because of progress bar  # TODO: wat, why? would bar be stored into var if we didn't use this pointeless file?
    tmpfile=$(mktemp -t transfer_XXX.tmp) || { err "unable to create temp with mktemp"; return 1; }
    curl --fail --connect-timeout 2 --progress-bar --upload-file "$file" "https://transfer.sh/$(basename -- "$file")" >> "$tmpfile" || { err; return 1; }
    cat -- "$tmpfile"
    echo
    copy_to_clipboard "$(cat -- "$tmpfile")" && report "copied link above to clipboard" || err "copying to clipboard failed"

    rm -f -- "$tmpfile"
}


####################
## Copy && Follow ##
####################
cpf() {
    [[ -z "$*" ]] && { err "arguments for the cp command required."; return 1; }
    cp -- "$@" && _goto "$_";
}

####################
## Move && Follow ##
####################
mvf() {
    [[ -z "$*" ]] && { err "name of a node to be moved required."; return 1; }
    mv -- "$@" && _goto "$_";
}

########################
## Make dir && Follow ##
########################
mkcd() {
    [[ -z "$*" ]] && { err "name of a directory to be created required."; return 1; }
    command mkdir -p -- "$@" && cd -- "$@"
}


mkf() { mkcd "$@"; }  # alias to mkcd

#####################################
## Take screenshot of main monitor ##
#####################################
shot() {
    local mon file

    check_progs_installed ffcast scrot || return 1

    mon=$@
    file="$HOME/shot-$(date +'%H:%M-%d-%m-%Y').png"
    [[ -n "$mon" ]] || mon=0
    ffcast -x $mon % scrot -g %wx%h+%x+%y -- "$file"
}

###################
## Capture video ##
###################

# TODO:
# video to gif:
# from  http://superuser.com/a/436109
#
# another ver from http://unix.stackexchange.com/questions/113695/gif-screencasting-the-unix-way:
#!/bin/bash
#TMP_AVI=$(mktemp /tmp/outXXXXXXXXXX.avi)
#ffcast -s % ffmpeg -y -f x11grab -show_region 1 -framerate 15 \
    #-video_size %s -i %D+%c -codec:v huffyuv                  \
    #-vf crop="iw-mod(iw\\,2):ih-mod(ih\\,2)" $TMP_AVI         \
#&& convert -set delay 10 -layers Optimize $TMP_AVI out.gif
mkgif() {
    local input_file output optimized

    readonly input_file="$1"

    readonly output='/tmp/output.gif'
    readonly optimized='/tmp/output_optimized.gif'

    [[ "$#" -ne 1 ]] && { err "exactly one arg expected - video file to convert"; return 1; }
    [[ -z "$input_file" ]] && { err "video file to convert to gif required as a param."; return 1; }
    [[ -f "$input_file" ]] || { err "[$input_file] is not a file"; return 1; }
    check_progs_installed ffmpeg

    ffmpeg -ss 00:00:00.000 -i "$input_file" -pix_fmt rgb24 -r 10 -s 320x240 -t 00:00:10.000 "$output"
    check_progs_installed convert || { err "convert is not installed; can't optimise final output [$output]"; return 1; }

    convert -layers Optimize "$output" "$optimized"

    report "final file at [$optimized]"
}


# also consider running  vokoscreen  instead.
capture() {
    local name screen_dimensions regex dest

    name="$1"

    readonly dest='/tmp'  # dir where recorded file will be written into
    readonly regex='^[0-9]+x[0-9]+$'

    check_progs_installed ffmpeg || return 1
    [[ "$#" -ne 1 ]] && { err "exactly one arg (filename without extension) required"; return 1; }
    [[ "$name" == */* || "$(dirname -- "$name")" != '.' ]] && { err "please enter only filename, not path; it will be written to [$dest]"; return 1; }
    [[ -n "$name" ]] && readonly name="$dest/${name}.mkv" || { err "need to provide output filename as first arg (without an extension)."; return 1; }
    [[ "$-" != *i* ]] && return 1  # don't launch if we're not in an interactive shell;

    screen_dimensions="$(get_screen_dimensions)" || { err "unable to find screen dimensions"; return 1; }
    [[ "$screen_dimensions" =~ $regex ]] || { err "found screen dimensions [$screen_dimensions] do not conform with validation regex [$regex]"; return 1; }

    #recordmydesktop --display=$DISPLAY --width=1024 height=768 -x=1680 -y=0 --fps=15 --no-sound --delay=10
    #recordmydesktop --display=0 --width=1920 height=1080 --fps=15 --no-sound --delay=10
    ffmpeg -f alsa -ac 2 -i default -framerate 25 -f x11grab -s "$screen_dimensions" -i "$DISPLAY" -acodec pcm_s16le -vcodec libx264 -- "$name"
    echo
    report "screencap saved at [$name]"

    ## lossless recording (from https://wiki.archlinux.org/index.php/FFmpeg#x264_lossless):
    #ffmpeg -i "$DISPLAY" -c:v libx264 -preset ultrafast -qp 0 -c:a copy "${name}.mkv"
    ## also lossless, but smaller output file:
    #ffmpeg -i "$DISPLAY" -c:v libx264 -preset veryslow -qp 0 -c:a copy "${name}.mkv"
}

# takes an input file and outputs mkv container for youtube:
# taken from https://wiki.archlinux.org/index.php/FFmpeg#YouTube
ytconvert() {
    [[ "$#" -ne 2 ]] && { err "exactly 2 args required - input file to convert, and output filename (without extension)."; return 1; }
    [[ -f "$1" ]] || { err "need to provide an input file as first argument."; return 1; }
    ffmpeg -i "$1" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a copy "${2}.mkv"
}


# Copies our public key to clipboard
#
# @returns {void}
pubkey() {
    local opt OPTIND contents o s

    o=0
    while getopts 'sg' opt; do
        case "$opt" in
           s)
              let o++
              s=ssh
              local key="$HOME/.ssh/id_rsa.pub"
              [[ -f "$key" ]] || { err "[$key] does not exist"; return 1; }
              contents="$(cat -- "$key")" || { err "cat-ing [$key] failed."; return 1; }
              ;;
           g)
              let o++
              s=gpg
              contents="$(gpg --output - --armor --export "${GPGKEY:-$USER}")" || { err "retrieving gpg pubkey failed."; return 1; }
              ;;
           *) err "need to choose which public key to copy: -s & -g for ssh & gpg respectively"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ "$o" -eq 0 ]] && { err "need to choose which public key to copy: -s & -g for ssh & gpg respectively"; return 1; }
    [[ "$o" -gt 1 ]] && { err "can provide at most one option"; return 1; }
    [[ -z "$contents" ]] && { err "couldn't retrieve [$s] pubkey"; return 1; }
    copy_to_clipboard "$contents" && report "copied [$s] pubkey to clipboard" || { err "copying [$s] pubkey failed; here it is:\n$contents"; return 1; }
    return 0
}


##############################################
# FZF based functions                       ##
##############################################
# see  https://github.com/junegunn/fzf/wiki/Examples


# fd - cd to selected directory
# note renamed to fdd, because fd is a binary
fdd() {  # 'fd' conflicts with https://github.com/sharkdp/fd
    local dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be starting dir."; return 1; }
    check_progs_installed fzf || return 1
    dir=$(find "${src:-.}" -path '*/\.*' -prune \
                    -o -type d -print 2> /dev/null | fzf +m) && cd -- "$dir"
}


# fda - same as fd/fdd(), but includes hidden directories;
# kinda same as `cd **<Tab>`
fda() {
    local dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be starting dir."; return 1; }
    check_progs_installed fzf || return 1
    dir=$(find "${src:-.}" -type d 2> /dev/null | fzf +m) && cd -- "$dir"
}


# fdu - cd to selected *parent* directory
fdu() {
    local dirs dir src pwd

    readonly src="$1"
    readonly pwd="$(realpath -- "$PWD")"

    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be starting dir."; return 1; }
    check_progs_installed fzf || return 1

    declare -a dirs=()
    _get_parent_dirs() {
        [[ -d "$1" ]] || return
        [[ "$1" != "$pwd" ]] && dirs+=("$1")
        if [[ "$1" == '/' ]]; then
            for _dir in "${dirs[@]}"; do echo "$_dir"; done
        else
            _get_parent_dirs "$(dirname -- "$1")"
        fi
    }

    dir=$(_get_parent_dirs "$(realpath -- "${src:-$pwd}")" | fzf --tmux --tac)
    cd -- "$dir"

    unset _get_parent_dirs
}


# cdf - cd into the directory of the selected file
# (same as our fog())
cdf() {
    local file dir pattern

    readonly pattern="$1"
    [[ -d "$pattern" ]] && report "fyi, input argument has to be a search pattern, not starting dir."
    check_progs_installed fzf || return 1

    file=$(fzf +m -q "$pattern") && dir=$(dirname -- "$file") && cd -- "$dir"
}


# utility function used to write the command in the shell (used by fzf wrappers)
# pass '-run' as first argument to run the passed command
__writecmd() {
    perl -e '$TIOCSTI = 0x5412; $l = <STDIN>; $lc = $ARGV[0] eq "-run" ? "\n" : ""; $l =~ s/\s*$/$lc/; map { ioctl STDOUT, $TIOCSTI, $_; } split "", $l;' -- $1
}


# cf - fuzzy cd from anywhere
# ex: cf word1 word2 ... (even part of a file name); basically it'll be "match word1 AND word2..."
#
# note the usage of locate instead of find et al.
cf() {
  local file

  file="$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf --read0 -0 -1)"

  if [[ -n "$file" ]]; then
     if [[ -d "$file" ]]; then
        cd -- "$file"
     else
        cd -- "${file:h}"  # TODO: don't we want to use $_goto here?
     fi
  fi
}

# ffstr() with modern tooling;
# search for files with file content (showing preview)
# find-in-file - usage: fif <searchPtrn> [fd opts...]
#
# example:
#   $fif 'something.*infile' 'filenamepattern'
#   $fif 'something.*infile' -e java 'javafilenameptrn'
#   $fif 'something.*infile' -e java -e js 'filenameptrn'  # search js & java files
fif() {
    local preview_cmd preview_cmd_full opts rg_opts k out ptrn files

    ptrn="$1"; shift

    #preview_cmd='highlight -O ansi -l -- {}'
    preview_cmd='bat -p --color always -- {}'
    # TODO: if ptrn contains backslashes (rgx), then _preview_ fails (but original search populating fzf input succeeds)
    preview_cmd_full="$preview_cmd 2>/dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 -- '$ptrn' || rg --ignore-case --pretty --context 10 -- '$ptrn' {}"
    rg_opts='--files-with-matches --no-messages'

    if [[ -z "$ptrn" ]]; then
        err "at least search pattern to search for required"
        return 1
    fi

    # remaining opts can only belong to fd:
    if [[ -n "$*" ]]; then
        readarray -t -d $'\0' files < <(fd --hidden --follow --type f --print0 "$@")  # do not limit fd command w/ --
        [[ "${#files[@]}" -eq 0 ]] && { err "no files found with fd"; return 1; }
    fi

    # if fd was involved, feed the file targets found with it to rg:
    _rg_find() {
        if [[ "${#files[@]}" -eq 0 ]]; then
            rg $rg_opts -- "$ptrn"
        else
            rg $rg_opts -- "$ptrn" "${files[@]}"
        fi
    }

    # note we do enter:execute w/ visual, as (n)vim doesn't work due to
    # fzf output being captured into $out:
    opts="
        $FZF_DEFAULT_OPTS
        -m --tiebreak=index --preview=\"$preview_cmd_full\"
        --bind=\"enter:execute(geany -- {})\"
        --expect=ctrl-e
        --exit-0
        --no-sort
        --ansi
    "
    out="$(_rg_find | FZF_DEFAULT_OPTS="$opts" fzf)"  # note capturing output fricks up non-gui opening w/ --bind
    unset _rg_find
    readarray -t out <<< "$out"

    k="${out[0]}"; unset out[0]
    [[ -z "$k" ]] && return 0  # got no --expect keypress event, exit
    [[ -z "${out[*]}" ]] && return 0  # no files selected

    case "$k" in
        'ctrl-e')
            "${EDITOR:-vim}" -- "${out[@]}"
            ;;
        *)
            err "unexpected key-combo [$k]"
            return 1
            ;;
    esac
}


# difference from fif() behavior is it lists the multiple results per file, and in
# preview the match is in first line; whereas for fif(), all the results for any
# given file are grouped under single entry in fzf;
fzf_grep_edit(){
    local match file
    if [[ $# -eq 0 ]]; then
        echo 'Error: search term was not provided.'
        return 1
    fi
    match=$(
      rg --color=never --line-number "$1" |
        fzf --no-multi --delimiter : \
            --preview "bat --color=always --line-range {2}: {1}"
      )
    file=$(echo "$match" | cut -d':' -f1)
    if [[ -f "$file" ]]; then
        ${EDITOR:-vim} "$file" +$(echo "$match" | cut -d':' -f2)
    fi
}


# fkill - kill processes - list only the ones you can kill. Modified the earlier script. (this 'earlier' bit is likely mindless copypasta)
fkill() {
    local pid
    if [[ "$UID" -ne 0 ]]; then
        pid=$(ps -f -u "$UID" | sed 1d | fzf -m | awk '{print $2}')
    else
        pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    fi

    if [[ -n "$pid" ]]; then
        echo "$pid" | xargs kill -${1:-9}
    fi
}


# git pickaxe (git log -S opt) for searching for commit that caused specific string to (dis)appear in file;
# see http://www.philandstuff.com/2014/02/09/git-pickaxe.html
#
# accepts the string query as first arg, and optional <path>(s) as 2nd+ args;
# TODO: see how to provide regex to -S opt;
faxe() {
    local src dsf cmd opts

    if [[ -z "$*" ]]; then
        err 'Error: search term was not provided.'
        return 1
    fi

    src="$1"; shift
    hash "$_DSF" &>/dev/null && dsf="|$_DSF"
    cmd="git show --color=always {1} -- $* $dsf"
    opts="
        $FZF_DEFAULT_OPTS
        --ansi
        --no-sort
        --height 100%
        +m --tiebreak=index --preview=\"git show --color=always --stat {1} -- $* $dsf\"
        --bind=\"enter:execute($cmd |less --pattern='$src')\"
    "
    git log --color \
        --pretty=format:'%C(red)%h %C(blue)[%cr]%C(reset) %s' \
        -S "$src" -- "$@" | FZF_DEFAULT_OPTS="$opts" fzf
}

fpickaxe() { faxe "$@"; }  # alias for faxe()


# fh - repeat history
# note: no reason to use when fzf's ctrl+r mapping works;
#
# ctrl-e  instead of enter lets you edit the command, just like with fzf's ctrl+r binding.
# ctrl-d  deletes selected command from shell history (note it feeds the command to fhd()).
#
# Examples:
#    fh  ssh user server
#    fh  curl part-of-url
fh() {
    local input f cleanup_regex cmd out ifs_old k

    input="$*"

    f="$(funname)"

    readonly cleanup_regex='^\s*\d+\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+\K.*$'  # depends on your history format (HISTTIMEFORMAT) set in .bashrc
    #([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -re 's/^\s*[0-9]+\s*//' | __writecmd -run
    check_progs_installed history || return 1

    if command -v fzf > /dev/null 2>&1; then
        # clean up history output, remove FUNCNAME, remove trailing whitespace & clean up multiple ws, print unique (w/o sorting):
        out="$(history \
                | grep -Po -- "$cleanup_regex" \
                | grep -vE -- "^\s*$f\b" \
                | sed -n 's/\ *$//;/.*/s/\s\+/ /gp' \
                | awk '!x[$0]++' \
                | fzf --no-sort --tac --query="$input" --expect=ctrl-e,ctrl-d +m -e --exit-0)"
        mapfile -t out <<< "$out"
        readonly k="${out[0]}"
        readonly cmd="${out[-1]}"
        [[ -z "$cmd" ]] && return 1
        if [[ "$k" == 'ctrl-e' ]]; then
            echo "$cmd" | __writecmd
        elif [[ "$k" == 'ctrl-d' ]]; then
            fhd "$cmd"
        else
            echo "$cmd" | __writecmd -run
        fi
        # oneliner without the binding:
        #([ -n "$ZSH_NAME" ] && fc -l 1 || history) \
            #| grep -vE -- "\s+$f\b" \
            #| fzf --no-sort --tac --query="$input" +m -e \
            #| grep -Po -- "$cleanup_regex" \
            #| __writecmd -run
    else
        input="${input// /.*}"  # build regex for grep
        readonly ifs_old="$IFS"
        IFS=$'\n'
        declare -ar cmd=( $(history \
                | grep -Po -- "$cleanup_regex" \
                | grep -vE -- "^\s*$f\b" \
                | sed -n 's/\ *$//;/.*/s/\s\+/ /gp' \
                | grep -iE --color=auto -- "$input" \
                | sort -u
        ) )
        IFS="$ifs_old"

        [[ -z "${cmd[*]}" ]] && { err "no matching entries found"; return 1; }
        select_items -s "${cmd[@]}"
        [[ -n "${__SELECTED_ITEMS[*]}" ]] && ${__SELECTED_ITEMS[@]}
        #echo "woo: ${__SELECTED_ITEMS[@]}"
    fi
}


# fhd - history delete
# search shell history commands and delete the selected ones.
#
# Examples:
#    fhd  ssh user server
#    fhd  curl part-of-url
fhd() {
    local q offset_regex cmd ifs_old i out

    q="$*"

    readonly offset_regex='^\s*\K\d+(?=.*$)'
    check_progs_installed history || return 1

    __delete_cmd() {
        local line offset

        line="$1"
        offset="$(grep -Po "$offset_regex" <<< "$line")"
        history -d "$offset" || { err "unable to delete history offset [$offset] for entry [$line]" -1; return 1; }
    }

    if command -v fzf > /dev/null 2>&1; then
        while out="$(history | fzf --no-sort --print-query --tac --query="$q" +m -e --exit-0)"; do
            mapfile -t out <<< "$out"
            q="${out[0]}"
            i="${out[-1]}"
            [[ -z "$i" ]] && return
            __delete_cmd "$i" || break
        done
    else
        q="${q// /.*}"  # build regex for grep
        readonly ifs_old="$IFS"
        IFS=$'\n'
        declare -ar cmd=( $(history | grep -iE --color=auto -- "$q") )
        IFS="$ifs_old"

        [[ -z "${cmd[*]}" ]] && { err "no matching entries found"; return 1; }
        select_items -s "${cmd[@]}"
        [[ -z "${__SELECTED_ITEMS[*]}" ]] && { err "no entries selected"; return 1; }
        __delete_cmd "${__SELECTED_ITEMS[*]}" || return $?
    fi

    # write the changes; otherwise deleted lines will reappear after terminal is closed (see https://unix.stackexchange.com/a/49216):
    history -w
    unset __delete_cmd
}


# fhe - repeat history edit
#fhe() {
    #([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -re 's/^\s*[0-9]+\s*//' | __writecmd
#}

# fbr - checkout git branch
#fbr() {
    #local branches branch
    #branches=$(git branch -vv) &&
    #branch=$(echo "$branches" | fzf +m) &&
    #git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
#}


# fbr - checkout git branch (including remote branches);
# see also fco()
fbr() {
    local branches branch q

    q="$*"
    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }

    branches=$(
        git branch --all | grep -v HEAD             |
        sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
        sort -u) || return
    branch=$(echo "$branches" |
            fzf --tmux --select-1 --exit-0 --query="$q" -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
            git checkout "$branch"
}


# fco - checkout git branch/tag
fco() {
    local tags branches target q

    q="$*"
    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }

    tags=$(git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
    branches=$(
        git branch --all | grep -v HEAD             |
        sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
        sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
    target=$(
        (echo "$tags"; echo "$branches") |
        fzf --tmux -l30 -- --query="$q" --exit-0 --select-1 --no-hscroll --ansi +m -d "\t" -n 2) || return
    git checkout "$(awk '{print $2}' <<< "$target")"
}


# fcoc - checkout git commit (as in commit hash, not branch or tag)
fcoc() {
    local commits commit q

    q="$*"
    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }

    commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
            commit=$(echo "$commits" | fzf --select-1 --query="$q" --tac +s +m -e --exit-0) &&
            git checkout "$(sed 's/ .*//' <<< "$commit")"
}


# fcol - checkout git LOST commit (as in search for dangling commits);
# good for recovering lost commits (especially lost stashes);
#
# needs to be ran before git has garbage collected the deleted commit
#
# accepts number of paths to filter by as per usual.
fcol() {
    local dsf sha_extract_cmd preview_cmd difftool_cmd opts

    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }
    hash "$_DSF" &>/dev/null && dsf="|$_DSF"

    sha_extract_cmd="grep -Po '^.*?\\\K[0-9a-f]+' <<< {}"
    preview_cmd="i=\$($sha_extract_cmd) || exit; git show --stat --color=always \$i -- $*; echo -e '\\\n\\\n'; git diff \$i^..\$i -- $* $dsf"  # TODO: need to sort out range
    difftool_cmd="$sha_extract_cmd |xargs -I% git difftool --dir-diff %^ % -- $*"
    opts="
        $FZF_DEFAULT_OPTS
        +m --tiebreak=index --preview=\"$preview_cmd\"
        --bind=\"enter:execute($difftool_cmd)\"
        --bind=\"ctrl-t:execute(
            source $_SCRIPTS_COMMONS;
            i=\$($sha_extract_cmd)
            copy_to_clipboard \\\"\$i\\\" \
                && { report \\\"sha is on clipboard\\\"; sleep 1; exit 0; } \
                || err \\\"unable to copy sha to clipboard. here it is:\\\n\$i\\\" && sleep 3
        )\"

        --exit-0
        --no-sort
        --tac
        --ansi
        --height='80%'
        --preview-window='right:60%'
    "

    #commits=$(git log --oneline --decorate --all --reverse $(git fsck --no-reflog | awk '/dangling commit/ {print $3}')) &&
    git log --color \
        --pretty=format:'%C(red)%h %C(green)[%s]%C(reset) %C(blue)%cr%C(reset) by %C(yellow)%cn%C(reset); parents: %C(yellow)%p' \
        --abbrev-commit --decorate --all --reverse \
        $(git fsck --no-reflog | awk '/dangling commit/ {print $3}') -- $* | FZF_DEFAULT_OPTS="$opts" fzf
}


# helper function for navigating to repo root
# prior to opening difftool; navigates back afterwards.
#
# TODO: deprecate; moving to git root is not necessary; i simply didn't understand <path> args;
#__open_git_difftool_at_git_root() {
    #local cwd git_root commit
    #readonly commit="$1"

    #[[ -z "$commit" ]] && { err "need to provide commit sha"; return 1; }
    #cwd="$(realpath "$PWD")"
    #git_root="$(realpath "$(get_git_root)")" || { err "unable to find project root" -1; return 1; }

    #[[ "$cwd" != "$git_root" ]] && pushd -- "$git_root" &> /dev/null  # git root
    #git difftool --dir-diff "$commit"^ "$commit"
    #[[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back to starting dir
#}


# fshow - git commit diff browser; pass path(s) as optional args
# - enter shows the changes of the commit
# - ctrl-s lets you squash commits - select the *last* commit that should be squashed.
# - ctrl-c generates the jira commit message.
# - ctrl-u generates gitlab commit url.
# - ctrl-t copies commit sha to clipboard.
# - ctrl-f fixup given commit with already-starged changes.
# - ctrl-b check the selected commit out.
fshow() {
    local f q dsf k out sha sha_extract_cmd preview_cmd difftool_cmd opts git_log_cmd

    f="$(funname)"
    hash "$_DSF" &>/dev/null && dsf="|$_DSF"

    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }
    #git log -i --all --graph --source --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative |

    # first let's navigate to repo (ie git) root:
    #cwd="$(realpath "$PWD")"
    #git_root="$(realpath "$(get_git_root)")" || { err "unable to find project root" -1; return 1; }
    #[[ "$cwd" != "$git_root" ]] && pushd -- "$git_root" &> /dev/null



    # this from glo():
    #sha_extract_cmd="echo {} | grep -Po '^[|\\\ /\\\\\\*]+\\\s*\\\K[a-f0-9]+'"
    sha_extract_cmd="grep -Po '^.*?\\\K[0-9a-f]+' <<< {}"
    #sha_extract_cmd="echo {} |grep -Eo '[a-f0-9]+' |head -1"  # default from forgit

    #preview_cmd="$sha_extract_cmd |xargs -I% git show --color=always % $dsf"  # default from forgit
    #preview_cmd="i=\$($sha_extract_cmd); test -z \$i && exit; p=\$(git cat-file -p \$i | grep -Po '^parent\\\s+\\\K.*' | head -1); git show --stat --color=always \$i; echo -e '\\\n\\\n'; git diff \$p..\$i $dsf"  # TODO: need to sort out range
    #preview_cmd="i=\$($sha_extract_cmd) || exit; p=\$(git cat-file -p \$i | grep -Po '^parent\\\s+\\\K.*' | head -1); git show --stat --color=always \$i -- $*; echo -e '\\\n\\\n'; git diff \$p..\$i -- $* $dsf"  # TODO: need to sort out range
    preview_cmd="i=\$($sha_extract_cmd) || exit; git show --stat --color=always \$i -- $*; echo -e '\\\n\\\n'; git diff \$i^..\$i -- $* $dsf"  # TODO: need to sort out range
    difftool_cmd="$sha_extract_cmd |xargs -I% git difftool --dir-diff %^ % -- $*"
    opts="
        $FZF_DEFAULT_OPTS
        +m --tiebreak=index --preview=\"$preview_cmd\"
        --bind=\"enter:execute($difftool_cmd)\"
        --bind=\"ctrl-y:execute-silent(echo {} | grep -Eo '[a-f0-9]+' | head -1 | tr -d '\n' |${FORGIT_COPY_CMD:-pbcopy})\"
        --bind=\"ctrl-c:execute(
            source $_SCRIPTS_COMMONS;
            i=\$($sha_extract_cmd)
            is_function generate_jira_commit_comment || { err \\\"can't generate commit msg as dependency is missing\\\" $f; sleep 1.5; exit 1; }
            generate_jira_commit_comment \$i
            exit
        )\"
        --bind=\"ctrl-u:execute(
            source $_SCRIPTS_COMMONS;
            i=\$($sha_extract_cmd)
            is_function generate_git_commit_url || { err \\\"can't generate git commit url as dependency is missing\\\" $f; sleep 1.5; exit 1; }
            url=\$(generate_git_commit_url \$i) || { err \\\"creating commit url failed\\\" $f; sleep 1.5; exit 1; }
            copy_to_clipboard \\\"\$url\\\" \
                && { report \\\"git commit url on clipboard\\\" $f; sleep 1; exit 0; } \
                || err \\\"unable to copy git commit url to clipboard. here it is:\\\n\$url\\\" $f && sleep 4
        )\"
        --bind=\"ctrl-t:execute(
            source $_SCRIPTS_COMMONS;
            i=\$($sha_extract_cmd)
            copy_to_clipboard \\\"\$i\\\" \
                && { report \\\"sha is on clipboard\\\" $f; sleep 1; exit 0; } \
                || err \\\"unable to copy sha to clipboard. here it is:\\\n\$i\\\" $f && sleep 3
        )\"

        --expect=ctrl-s,ctrl-b,ctrl-f
        --exit-0
        --print-query
        --no-sort
        --reverse
        --ansi
        --height='80%'
        --preview-window='right:60%'
    "
    git_log_cmd="git log --graph --color=always \
                --format='%C(auto)%h%d %s %C(black)%C(bold)(%cr) %C(bold blue)<%an>%Creset' -- $*"

    out="$(eval "$git_log_cmd" | FZF_DEFAULT_OPTS="$opts" fzf)"
    #[[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back to starting dir

    mapfile -t out <<< "$out"
    q="${out[0]}"
    k="${out[1]}"
    [[ -z "$k" ]] && return 0  # got no --expect keypress event, exit

    sha="$(grep -Po '^.*?\K[0-9a-f]{7}' <<< "${out[-1]}")" || { err "unable to parse out commit sha"; return 1; }

    # note to squash everything up to initial commit, just run  $ git rebase -i --root
    case "$k" in
        'ctrl-s')
            if [[ "$sha" == "$(git log -n 1 --pretty=format:%h HEAD)" ]]; then
                report "won't rebase on HEAD lol"; return
            elif [[ -n "$*" ]]; then
                confirm "\nyou've filtered commits by path(s) [$*]; still continue with rebase?" || return
            elif [[ -n "$q" ]]; then
                confirm "\nyou've filtered commits by query [$q]; still continue with rebase?" || return
            fi

            git rebase -i "$sha"~
            return $? ;;
        'ctrl-b')
            git checkout "$sha"; return $? ;;
        'ctrl-f')
            if [[ -n "$(git diff --name-only --staged)" ]]; then
                git fixup "$sha" || { err 'git fixup failed' "$f"; return 1; }
            else
                err "no files staged, nothing to fixup" "$f"; return 1
            fi
            ;;
        *)
            #__open_git_difftool_at_git_root "$sha"
            err "unexpected key-combo [$k]"; return 1 ;;
    esac
}


# fsha - get git commit sha; allows multiple selections
# example usage: git rebase -i `fsha`
fsha() {
    local commits i

    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }

    while IFS= read -r -d $'\0' i; do
        commits+=("${i%% *}")
    done < <(git log --color=always --pretty=oneline --abbrev-commit --reverse | fzf --tac +s -m -e --ansi --reverse --exit-0 --print0)
    #readarray -t -d $'\0' commits < <(git log --color=always --pretty=oneline --abbrev-commit --reverse | fzf --tac +s -m -e --ansi --reverse --exit-0 --print0| xargs -0 awk '{print $1;}' )

    [[ ${#commits[@]} -eq 0 ]] && return 1
    copy_to_clipboard "${commits[*]}" && report "copied commit sha(s) [${commits[*]}] to clipboard"
}


# fstash - easier way to deal with stashes; type fstash to get a list of your stashes.
# - enter shows you the contents of the stash
# - ctrl-d asks to drop the selected stash
# - ctrl-a asks to apply (pop) the selected stash
# - ctrl-b checks the stash out as a branch, for easier merging (TODO: not avail atm)
#
# note fstash accepts path(s) similar to fshow(); only that stash list command is
# not affected by it, as git stash doesn't accept paths;
#
# NOTE possibly also implemented by forgit ('gss' command)
fstash() {
    local dsf sha_extract_cmd preview_cmd difftool_cmd opts stash_cmd out q k stsh stash_name_regex stash_name

    readonly stash_name_regex='^\s*(\S+\s+){7}\K.*'
    hash "$_DSF" &>/dev/null && dsf="|$_DSF"

    check_progs_installed fzf git || return 1
    is_git || { err "not in git repo."; return 1; }

    #cmd="git stash show \$(echo {}| cut -d: -f1) --color=always --ext-diff $forgit_fancy"  # this to use with  --bind=\"enter:execute($cmd |LESS='-R' less
    sha_extract_cmd="grep -Po '^\\\S+(?=)' <<< {}"
    preview_cmd="i=\$($sha_extract_cmd) || exit; git show --stat --color=always \$i -- $*; echo -e '\\\n\\\n'; git diff \$i^..\$i -- $* $dsf"  # TODO: need to sort out range
    difftool_cmd="$sha_extract_cmd |xargs -I% git difftool --dir-diff %^ % -- $*"
    opts="
        $FZF_DEFAULT_OPTS
        +m --tiebreak=index --preview=\"$preview_cmd\"
        --bind=\"enter:execute($difftool_cmd)\"
        --expect=ctrl-a,ctrl-d
        --exit-0
        --print-query
        --no-sort
        --ansi
        --height='80%'
        --preview-window='top:70%'
    "
    #stash_cmd="git stash list --pretty=format:'%C(red)%h%C(reset) - %C(dim yellow)(%C(bold magenta)%gd%C(dim yellow))%C(reset) %<(70,trunc)%s %C(green)(%cr) %C(bold blue)<%an>%C(reset)'"
    stash_cmd="git stash list --color --pretty=format:'%C(red)%gd %C(green)(%cr) %C(blue)%gs'"

    while out="$(eval "$stash_cmd" | FZF_DEFAULT_OPTS="$opts" fzf)"; do
        mapfile -t out <<< "$out"
        q="${out[0]}"
        k="${out[1]}"
        stsh="${out[-1]}"
        stsh="${stsh%% *}"
        [[ -z "$k" ]] && return 0  # got no --expect keypress event, exit
        [[ -z "$stsh" ]] && continue

        stash_name="$(echo "${out[-1]}" | grep -Po "$stash_name_regex")"  # name/description of the stash

        case "$k" in
            'ctrl-d')
                confirm " -> drop stash $stsh ($stash_name)?" || continue
                git stash drop "$stsh" || { err "something went wrong (code $?)"; return 1; }
                unset stsh  # so it wouldn't get copied to clipboard
                ;;
            'ctrl-a')
                confirm " -> apply (pop) stash $stsh ($stash_name)?" || continue
                git stash pop "$stsh" || { err "something went wrong (code $?)"; return 1; }
                unset stsh  # so it wouldn't get copied to clipboard
                ;;
            'ctrl-b')
                report "not using c-b binding atm" && return
                git stash branch "stash-$sha" "$sha"
                break;
                ;;
            *)
                err "unexpected key-combo [$k]"
                return 1
                ;;
        esac
    done

    # copy last viewed stash id to clipboard: (commented out for now, don't think i ever needed this)
    #[[ -z "$k" && -n "$stsh" ]] \
        #&& copy_to_clipboard "$stsh" \
        #&& echo && report " -> copied [$stsh] to clipboard"
}


# select recent file with fasd and open for editing
# TODO: manually invoke add_nodes_to_fasd() on result?
e() {  # mnemonic: edit
    local file

    check_progs_installed fasd fzf "$EDITOR" || return 1
    file="$(fasd -Rfl "$@" | fzf -1 -0 --no-sort +m --exit-0)"
    [[ -f "$file" ]] && $EDITOR -- "$file" && return 0 || return 1
}


se() {  # mnemonic: sudo edit
    local file

    check_progs_installed fasd fzf "$EDITOR" || return 1
    file="$(fasd -Rfl "$@" | fzf -1 -0 --no-sort +m --exit-0)"
    [[ -f "$file" ]] && sudo $EDITOR -- "$file" && return 0 || return 1
}

es() { se "$@"; }  # alias; keep as a function as opposed to shell alias


# select recent dir with fasd and cd into
#
# !!note: d clashes with fasd alias; make sure you remove that one (in generated cache, likely in $HOME)
# TODO: manually invoke add_nodes_to_fasd() on result?
d() {  # mnemonic: dir
    local dir

    #command -v ranger >/dev/null && fm=ranger
    #check_progs_installed "$fm" || return 1

    check_progs_installed fasd fzf || return 1
    dir="$(fasd -Rdl "$@" | fzf -1 -0 --no-sort +m --exit-0)"
    [[ -d "$dir" ]] && cd -- "$dir" && return 0 || return 1
}


# select recent dir or file and cd to it
# TODO: manually invoke add_nodes_to_fasd() on result? or should this be done in _goto()? thing in _goto() makes more sense
# TODO: maybe _goto should be goto, and only gt to provide fasd integration?
goto() {
    local node

    check_progs_installed fasd fzf || return 1
    [[ "$*" == */ && -d "$*" ]] && { _goto "$*"; return $?; }  # TODO: only short-circuit if dir-arg ends with slash?

    node="$(fasd -Ral "$@" | fzf -1 -0 --no-sort +m --exit-0)"
    if [[ -e "$node" ]]; then
        _goto "$node"
    elif [[ "$*" != */ && "$*" == */* ]]; then
        _goto "$*"
    else
        return 1
    fi
}

gt() { goto "$@"; }  # alias to goto()


# notes:
# - using [kill -3 <pid>] for thread dump causes it to appear jvm's stdout;
#   quite likely it'll be the jvm.log you've configured;
javadump() {
    local f usage OPTIND opt pids pid mode i tf hf target_dir space

    f="$(funname)"
    readonly usage="\n$f: dump java process's heap and/or threads.
    Usage: $f  [-ht] [pid] [pid2]...
        -h  only dump heap (skip thread dump)
        -t  only dump threads (skip heap dump)
"

    # TODO: maybe replace -h w/ -H, as -h is generally help?
    while getopts 'ht' opt; do
        case "$opt" in
           h) mode=H
                ;;
           t) mode=T
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    pids=("$@")

    check_progs_installed jcmd || return 1
    # if no pids provided, ask user to select:
    if [[ "${#pids[@]}" -eq 0 ]]; then
        unset opt; opt=()
        while read -r i; do
            [[ "$i" != *sun.tools.jcmd.JCmd* ]] && opt+=("$i")
        done< <(jcmd -l)
        [[ "${#opt[@]}" -eq 0 ]] && { err "no java processes as per jcmd"; return 1; }

        select_items "${opt[@]}"
        [[ -z "${__SELECTED_ITEMS[*]}" ]] && { err "no process selected"; return 1; }
        for i in "${__SELECTED_ITEMS[@]}"; do
            pid="$(grep -Eo '^[0-9]+' <<< "$i")"
            pids+=("$pid")
        done
        [[ "${#pids[@]}" -eq 0 ]] && { err "no pids selected"; return 1; }
    fi

    for pid in "${pids[@]}"; do
        is_digit "$pid" || { err "at least one of the args was not a valid pid: [$pid]"; return 1; }
    done

    # find target dir for heapdump; prefer location that has most free space left:
    # TODO: can our user write to those destinations? perhaps add test -w "$i"? then again, which user to test?
    space=0  # init
    for i in /tmp /var/log; do
        pid="$(space_left "$i")" || continue  # note we're just reusing the $pid arg
        if [[ -d "$i" && "$pid" -gt "$space" ]]; then
            space="$pid"
            target_dir="$i"
        fi
    done
    unset pid i

    # TODO: heap_dump won't overwrite file! ask for deletion?
    for pid in "${pids[@]}"; do  # do not parallelize!
        i="$(ps -o user= -p "$pid")"  # user running given $pid
        tf="$target_dir/${pid}-thread-dump.jfr"
        hf="$target_dir/${pid}-heap-dump.hprof"

        if [[ "$i" != "$USER" ]]; then
            [[ "$EUID" -ne 0 ]] && { err "pid [$pid] is not owned by our user and we're not root to change to user [$i]"; return 1; }
            [[ "$mode" != T ]] && report "dumping heap for ${pid}..." && { su -l "$i" -c "jcmd $pid GC.heap_dump '$hf'" || return 1; } && report "heapdump at [$hf]"
            [[ "$mode" != H ]] && report "dumping threads for ${pid}..." && { su -l "$i" -c "jcmd $pid Thread.print" > "$tf" || return 1; } && report "thread dump at [$tf]"
        else  # target process is owned by us
            [[ "$mode" != T ]] && report "dumping heap for ${pid}..." && { jcmd "$pid" GC.heap_dump "$hf" || return 1; } && report "heapdump at [$hf]"
            [[ "$mode" != H ]] && report "dumping threads for ${pid}..." && { jcmd "$pid" Thread.print > "$tf" || return 1; } && report "thread dump at [$tf]"
            #jmap -dump:live,format=b,file=/tmp/dump.hprof 12587    #alternative headp dump using jmap
            #jstack -f 5824  #alternative thread dump using jstack
        fi
    done
}

heapdump() { javadump -h "$@"; }
threaddump() { javadump -t "$@"; }


# TODO: also look into ngrep usage
tcpdumperino() {
    local f usage OPTIND opt file overwrite

    f="$(funname)"
    readonly usage="\n$f: monitor & dump TCP traffic of an interface.
    Usage: $f  [-o] -f <outputfile>
        -f  file where results should be dumped in
        -o  allow overwriting <outputfile> if it already exists
"

    while getopts 'of:' opt; do
        case "$opt" in
           f) file="$OPTARG"
                ;;
           o) overwrite=1
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ -z "$file" ]] && { err "need to provide output file"; echo -e "$usage"; return 1; }
    if [[ -f "$file" ]]; then
        if [[ "$overwrite" -eq 1 ]]; then
            rm -f -- "$file" || { err "removing [$file] failed"; return 1; }
        else
            err "[$file] already exists; (pass -o to automatically overwrite)"
            return 1
        fi
    fi

    # note dumpcap is included w/ wireshark
    if command -v dumpcap > /dev/null 2>&1; then
        select_interface || return 1

        # first get interface number as per dumpcap:
        __SELECTED_ITEMS="$(dumpcap -D | grep -Po '^\d+(?=\.\s+'"$__SELECTED_ITEMS"'$)')" || return 1
        report "dumping traffic using dumpcap... (Ctrl+c to stop)"
        dumpcap -i "$__SELECTED_ITEMS" -w "$file"
    elif command -v tcpdump > /dev/null 2>&1; then
        select_interface || return 1

        # we pass following options to tcpdump so result could be analyzed w/
        # wireshark; from https://www.wireshark.org/docs/wsug_html_chunked/AppToolstcpdump.html
        report "dumping traffic using tcpdump... (Ctrl+c to stop)"
        tcpdump -i "$__SELECTED_ITEMS" -s 65535 -w "$file"
    else
        err "no program to dump TCP traffic with"; return 1
    fi

    report "output in [$file]"
}


# look up IPs in LAN
# from https://superuser.com/a/261823/179401
scan_network() {
    check_progs_installed  arp-scan || return 1
    report "note that sudo passwd is required"

    #sudo arp-scan 10.42.21.1/24 --retry=5
    #sudo arp-scan --interface=enp2s0f0 --localnet --timeout=1500 --retry=5
    #sudo arp-scan --interface=enp2s0f0 --localnet --retry=5
    sudo arp-scan --localnet --retry=3
}

##############################################
## Colored Find                             ##
## NOTE: Searches current tree recrusively. ##
##############################################
#f() {
    #find . -iregex ".*$*.*" -printf '%P\0' | xargs -r0 ls --color=auto -1d
#}

##############################################
# marks (jumps)                             ##
# from: http://jeroenjanssens.com/2013/08/16/quickly-navigate-your-filesystem-from-the-command-line.html
# alternatives:
# - https://github.com/huyng/bashmarks
##############################################
if [[ "$EUID" -eq 0 ]]; then
    _MARKPATH="$(find $BASE_DATA_DIR /home -mindepth 2 -maxdepth 2 -type d -name "$_MARKPATH_DIR" -print0 -quit 2>/dev/null)"
    [[ -z "$_MARKPATH" ]] && _MARKPATH="$HOME/$_MARKPATH_DIR"
else
    # if $BASE_DATA_DIR available, try writing it there so it'd be persisted between OS installs:
    [[ -d "$BASE_DATA_DIR" ]] && _MARKPATH="$BASE_DATA_DIR/$_MARKPATH_DIR" || _MARKPATH="$HOME/$_MARKPATH_DIR"
fi

export _MARKPATH

# jump to mark:
function jj {
    [[ "$#" -ne 1 ]] && { err "provide a mark to jump to"; return 1; }
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in ${_MARKPATH} - dir does not exist."; return 1; }
    cd -P -- "$_MARKPATH/$1" 2>/dev/null || err "no mark [$1] in [$_MARKPATH]"
}

# mark:
# pass '-o' as first arg to force overwrite existing target link
# TODO: consider https://github.com/urbainvaes/fzf-marks
function jm {
    local overwrite target

    [[ "$1" == "-o" || "$1" == "--overwrite" ]] && { readonly overwrite=1; shift; }
    readonly target="$_MARKPATH/$1"

    [[ $# -ne 1 || -z "$1" ]] && { err "exactly one arg accepted"; return 1; }
    [[ -z "$_MARKPATH" ]] && { err "\$_MARKPATH not set, aborting."; return 1; }
    [[ -d "$_MARKPATH" ]] || command mkdir -p -- "$_MARKPATH" || { err "creating [$_MARKPATH] failed."; return 1; }
    [[ "$overwrite" -eq 1 && -h "$target" ]] && rm -- "$target" >/dev/null 2>/dev/null
    [[ -h "$target" ]] && { err "[$target] already exists; use jmo() or $(funname) -o to overwrite."; return 1; }

    ln -s -- "$(pwd)" "$target"
    return $?
}

# mark override:
# mnemonic: jm overwrite
function jmo {
    jm --overwrite "$@"
}

# un-mark:
function jum {
    [[ $# -ne 1 || -z "$1" ]] && { err "exactly one arg accepted"; return 1; }
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in [$_MARKPATH] - dir does not exist."; return 1; }
    rm -i -- "$_MARKPATH/$1"
}

# list all saved marks:
function jjj {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in [$_MARKPATH] - dir does not exist."; return 1; }
    ls -l -- "$_MARKPATH/" | sed 's/  / /g' | cut -d' ' -f9- | sed 's/ -/\t-/g' && echo
}

# marks/jumps completion:
_completemarks() {
    local curw wordlist

    [[ -d "$_MARKPATH" ]] || { err "no marks saved in [$_MARKPATH] - dir does not exist."; return 1; }
    curw=${COMP_WORDS[COMP_CWORD]}
    wordlist=$(find "$_MARKPATH/" -type l -printf '%f\n')
    COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
    return 0
}
is_bash && complete -F _completemarks jj jum jmo

# print out pstree, but in reverse (ie root of the tree is at the bottom)
ptree() {
    pstree -U | sed "y/└┬/┌┴/" | tac
}


# when using gnu tools (mv, cp etc) you may also check out progress command (https://github.com/Xfennec/progress)
# that one won't show aggregate progress though, but the progress of individual file being operated on so likely most useful for large files.
copy-progress() {
    local i src dest e

    if [[ $# -lt 2 ]]; then
        err 'at least 2 args required'
        return 1
    fi
    for i in "$@"; do
        if ! [[ -e "$i" ]]; then
            err "given source/dest [$i] does not exist"
            return 1
        fi
    done

    dest="${*: -1:1}"  # last arg
    #set -- "${@:1:$(($#-1))}"  # remove last arg
    src=()
    for i in "${@:1:$(($#-1))}"; do  # iterate over all but last arg
        src+=("${i%/}")  # strip trailing slash; otherwise directories are not copied the same way as cp does
    done

    rsync -ah --info=progress2 --no-i-r -- "${src[@]}" "$dest"
    e=$?

    if [[ "$e" -eq 0 ]]; then
        report "copy succeeded, running sync..."
        sync && report "sync OK" || err "sync failed w/ $?"  # to check sync progress in separate terminal, do  $ watch -d grep -e Dirty: -e Writeback: /proc/meminfo
    else
        err "rsync failed w/ $?"
    fi

    return "$e"
}

################################################
# other shell completions:
# use this if grep w/ perl regex not avail:
#[[ -f ~/.ssh/config ]] && complete -o default -o nospace -W "$(grep -i -e '^host ' ~/.ssh/config | awk '{print substr($0, index($0,$2))}' ORS=' ')" sshpearl
is_bash && [[ -f ~/.ssh/config ]] && complete -o default -o nospace -W "$(grep -Poi '^host\s+\K\S+' ~/.ssh/config | grep -vFx '*')" sshpearl

# $1 - name of the function whose args are completed
# $2 - word being completed
# $3 - word preceding the word being completed on the current command line, think it's same as ${COMP_WORDS[COMP_CWORD-1]}
_complete_dirs_in_pwd() {
    local curw wordlist d prefix p i


    [[ "$DEBUG" -eq 1 ]] && err "1: [$1]"  # always funcname
    [[ "$DEBUG" -eq 1 ]] && err "2: [$2]"  # think its what's on cml at the time you press tab, even if it gets completed immediately; separate last part, not entirety that's on CLI
    [[ "$DEBUG" -eq 1 ]] && err "3: [$3]"  # last completed word? even if its not valid completion
    curw=${COMP_WORDS[COMP_CWORD]}  # think it's the same as $2?

    __go_up() {
        local dots i d

        dots="$*"  # guaranteed to be _minimum_ of 3 dots.

        for ((i=0; i <= (( ${#dots} - 2 )); i++)); do
            d+='../'
        done
        echo "$d"
    }


    # defines global/outer $d
    __define_d() {
        local I input paths i

        I="$1"
        for i in "${COMP_WORDS[@]:1:${#COMP_WORDS[@]}-I}"; do
            input+="$i"
            [[ "$i" != */ ]] && input+='/'
        done

        if [[ "$input" == '~'* ]]; then
            input="${HOME}${input:1}"
        fi
        if [[ "$input" == /* ]]; then
            input="${input:1}"
            d='/'
        fi
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
        return 0  # if [^...] then those need to be expanded, hence can't return here

    elif [[ "$2" == */ ]]; then  # ie all's confirmed directory path i suppose? as in no further completion needed here
        curw="$2\ "
        COMPREPLY=($(compgen -W "$curw" -- "$curw"))
        return 0

    elif grep -qE '\S+/\S+' <<< "$curw"; then

        if [[ "$COMP_CWORD" -eq 1 ]]; then
            __define_d 1
            d="${d%/*}/"
            curw="${curw##*/}"  # everything after very last slash
            prefix="$d"
        else
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
#is_function g && complete -o dirnames -o filenames -o nospace -F _complete_dirs_in_pwd g  # autocomplete on directories
#is_function g && complete -o dirnames -o filenames -F _complete_dirs_in_pwd g  # autocomplete on directories
is_bash && is_function g && complete -o dirnames -F _complete_dirs_in_pwd g

# TODO: here we try to introduce fuzzyness via find -iname {{{
#_complete_dirs_in_pwd() {
    #local curw wordlist d s

    ##echo "1: [$1]"
    ##echo "2: [$2]"
    ##echo "3: [$3]"
    ##echo "curv: [${COMP_WORDS[*]}]"
    #curw=${COMP_WORDS[COMP_CWORD]}  # think it's the same as $2?
    #if [[ "$2" == */ ]]; then
        #d="$(build_comma_separated_list -s '/' "${COMP_WORDS[@]:1}")"
    #[[ -z "$d" ]] && d='.'
    ##echo "d: [$d]"
    #[[ -d "$d" ]] || return 1
        #wordlist=$(find -L "$d" -mindepth 1 -maxdepth 1 -type d -printf "%f\n")
    #else
        #d="$(build_comma_separated_list -s '/' "${COMP_WORDS[@]:1:${#COMP_WORDS[@]}-2}")"
    #[[ -z "$d" ]] && d='.'
    #[[ -d "$d" ]] || return 1
    ##echo "d: [$d]"
        #s="${COMP_WORDS[-1]}"
    #echo "s: [${s##*/}]"
        #wordlist=$(find -L "$d" -mindepth 1 -maxdepth 1 -type d -iname '*'"${s##*/}"'*' -printf '%f\n' )
    ##echo "wlist: ${wordlist[*]} --end"
    #fi
    ##wordlist=$(find -L "$d" -mindepth 1 -maxdepth 1 -type d $s -printf "%f\n")
    ##wordlist=$(find -L "$d" -mindepth 1 -maxdepth 1 -type d "${s[@]}" )
    ##[[ "${#wordlist[@]}" -eq 1 ]] && echo WAAAT && wordlist[0]="${wordlist[0]}/"
    ##echo "wlist: ${wordlist[*]} --end"
    ##[[ -z "${wordlist[*]}" ]] && wordlist=("$(printf %b '\u200b')")  # only if using -o nospace
    #COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
    #return 0
#}


#is_function g && complete  -o nospace -F _complete_dirs_in_pwd g  # autocomplete on directories
# }}}

################################################
# marker function used to detect whether functions have been loaded into the shell:
function __BASH_FUNS_LOADED_MARKER() { true; }

