#!/bin/bash
#
# good source to begin with: http://tldp.org/LDP/abs/html/sample-bashrc.html
# TODO: check this!: https://github.com/Cloudef/dotfiles-ng/blob/master/#ARCHCONFIG/shell/functions
#
#
# =====================================================================
# import common:
if ! type __COMMONS_LOADED_MARKER > /dev/null 2>&1; then
    if [[ -r "$_SCRIPTS_COMMONS" ]]; then
        source "$_SCRIPTS_COMMONS"
    else
        echo -e "\nError: common file \"$_SCRIPTS_COMMONS\" not found!! Many functions will be unusable!!!"
        # !do not exit, or you won't be able to open shell without the commons file being
        # present!
    fi
fi
# =====================================================================

# find files or dirs:
function ffind() {
    local SRC SRCDIR INAME_ARG opt usage OPTIND file_type filetypeOptionCounter linkTypeOptionCounter usegrep found_files_list parameterised_files_list file index exact binary follow_links maxDepth maxDepthParam
    usage="\n$FUNCNAME: find files/dirs by name.
    Usage: $FUNCNAME  [-i] [-f] [-d] [-l] [-b] [-e] [-m depth]  \"fileName pattern\" [top_level_dir_to_search_from]
        -i  filename is case insensitive
        -f  search for regular files
        -d  search for directories
        -l  search for symbolic links
        -b  search for executable binaries
        -L  follow symlinks. note that this won't work with -l.
        -m<digit>   max depth to descend
        -e  serch for exact filename, not for a partial"

    filetypeOptionCounter=0
    linkTypeOptionCounter=0

    while getopts "m:ifdelbLh" opt; do
        case "$opt" in
           i) INAME_ARG="-iname"
              shift $((OPTIND-1))
                ;;
           e) exact=1
              shift $((OPTIND-1))
                ;;
           f | d | l) file_type="-type $opt"
              let filetypeOptionCounter+=1
              [[ "$opt" == "l" ]] && let linkTypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           b) binary=1
              let filetypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           L) linkTypeOptionCounter+=1
              follow_links="-follow"
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done

    SRC="$1"
    SRCDIR="$2"

    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$SRC" ]]; then
        err "incorrect nr of aguments." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f, -d, -l and -b flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$linkTypeOptionCounter" -gt 1 ]]; then
        err "-l and -L flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    if [[ -n "$SRCDIR" ]]; then
        if [[ ! -d "$SRCDIR" ]]; then
            err "provided directory to search from is not a directory. abort." "$FUNCNAME"
            return 1
        elif [[ "${SRCDIR:$(( ${#SRCDIR} - 1)):1}" != "/" ]]; then
            SRCDIR="${SRCDIR}/" # add trailing slash if missing; required for gnu find; is it really the case??
        fi
    fi

    if [[ "$SRC" == *\.\** ]]; then
        err "only use asterisks (*) for wildcards, not .*" "$FUNCNAME"
        return 1
    elif [[ "$SRC" == *\.* ]]; then
        report "note that period (.) will be used as a literal period, not as a wildcard.\n" "$FUNCNAME"
    elif [[ "$SRC" == *\** ]]; then
        #echo -e "please don't use asterisks in filename pattern; searchterm is already padded with wildcards on both sides."
        #return 1
        # switch grep usage off for coloring, as using asterisks wouldn't pass grep filter:
        usegrep="false"
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth (the -m flag) arg value has to be a digit, but was \"$maxDepth\"" "$FUNCNAME"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    fi

    # grep is for coloring only:
    #find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' | grep -i --color=auto "$SRC" 2>/dev/null
    if [[ "$exact" -eq 1 ]]; then
        if [[ "$usegrep" == "false" ]]; then
            if [[ "$binary" -eq 1 ]]; then
                find "${SRCDIR:-.}" $maxDepthParam $follow_links -type f "${INAME_ARG:--name}" "$SRC" -executable -exec sh -c "file -i '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null
            else
                find "${SRCDIR:-.}" $maxDepthParam $follow_links $file_type "${INAME_ARG:--name}" "$SRC" 2>/dev/null # old; TODO: deleteme if new one proves better
            fi
        else # use coloring grep
            if [[ "$binary" -eq 1 ]]; then
                find "${SRCDIR:-.}" $maxDepthParam $follow_links -type f "${INAME_ARG:--name}" "$SRC" -executable -exec sh -c "file -i '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null | grep -i --color=auto "$SRC"
            else
                find "${SRCDIR:-.}" $maxDepthParam $follow_links $file_type "${INAME_ARG:--name}" "$SRC" 2>/dev/null | grep -i --color=auto "$SRC"
            fi
        fi
    else # partial filename match
        if [[ "$usegrep" == "false" ]]; then
            if [[ "$binary" -eq 1 ]]; then
                find "${SRCDIR:-.}" $maxDepthParam $follow_links -type f "${INAME_ARG:--name}" '*'"$SRC"'*' -executable -exec sh -c "file -i '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null
            else
                find "${SRCDIR:-.}" $maxDepthParam $follow_links $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' 2>/dev/null # old; TODO: deleteme if new one proves better
            fi
        else # use coloring grep
            if [[ "$binary" -eq 1 ]]; then
                find "${SRCDIR:-.}" $maxDepthParam $follow_links -type f "${INAME_ARG:--name}" '*'"$SRC"'*' -executable -exec sh -c "file -i '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null | grep -i --color=auto "$SRC"
            else
                find "${SRCDIR:-.}" $maxDepthParam $follow_links $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' 2>/dev/null | grep -i --color=auto "$SRC"
            fi
        fi
    fi

    ##### from here on, hackeroo begins:
    #found_files_list=()
    #parameterised_files_list=()

    ## TODO: store found files in args:
    #while IFS= read -r -d '' file; do
        #found_files_list+=( "$file" )
    #done <   <(find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' -print0 2>/dev/null)

    #index=1
    #clear
    #for file in ${found_files_list[@]}; do
        #if [[ "$index" -le 20 ]]; then
            #parameterised_files_list+=( "\"$file\"" )
            #file="$index\t$file"
            #let index+=1
        #fi

        #if [[ "$usegrep" == "false" ]]; then
            #echo -e "$file"
        #else
            #echo -e "$file" | grep -i --color=auto "$SRC"
        #fi
    #done

    ##if [[ "${#parameterised_files_list[@]}" != 0 ]]; then
        ## TODO: handles filenames with spaces, but otherwise... dangerous:
        #echo -e "${parameterised_files_list[@]}"
    ##fi
}

# Find a file with a pattern in name (inside wd);
# essentially same as ffind(), but a bit simplified:
#function ff() {
    #find . -type f -iname '*'"$*"'*'  -ls
#}

function ffindproc() {
    [[ -z "$1" ]] && { err "process name required" "$FUNCNAME"; return 1; }
    # last grep for re-coloring:
    ps -ef | grep -i "$1" | grep -v '\bgrep\b' | grep -i --color=auto "$1"

    # TODO: add also exact match option?:
    #   grep '\$1\b'
}

# find top 5/x biggest or smallest nodes:
function __find_top_big_small_fun() {
    local usage opt OPTIND itemsToShow fileTypeArgs item compiledFileTypeArgs maxDepthParam maxDepth follow_links reverse du_size_unit FUNCNAME_ bigOrSmall

    reverse="$1"
    du_size_unit="$2"
    FUNCNAME_="$3"
    bigOrSmall="$4"
    shift 4

	if ! [[ "$du_size_unit" =~ ^[KMGTPEZYB]+$ ]]; then
        err "unsupported du block size unit: \"$du_size_unit\"" "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    usage="\n$FUNCNAME_: find top $bigOrSmall nodes. if node type not specified, defaults to searching for regular files.
    Usage: $FUNCNAME_  [-f] [-d] [-L] [-m depth]  [nr_of_top_items_to_show]
        -f  include regular files
        -d  include directories
        -L  follow symlinks
        -m<digit>   max depth to descend"

    while getopts "m:fdLh" opt; do
        case "$opt" in
           f) fileTypeArgs="$fileTypeArgs f"
              shift $((OPTIND-1))
                ;;
           d) fileTypeArgs="$fileTypeArgs d"
              # we don't want to sed maxdepth param here by default, right?
              #maxDepthParam="-maxdepth 1"
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           L) follow_links="-follow"
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done

    itemsToShow="$1"

    if [[ -z "$fileTypeArgs" ]]; then
        compiledFileTypeArgs="-type f"
    else
        for item in $fileTypeArgs; do
            [[ -z "$compiledFileTypeArgs" ]] && compiledFileTypeArgs="-type $item" \
                                             || compiledFileTypeArgs="$compiledFileTypeArgs -o -type $item"
        done
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth arg value has to be... y'know, a digit" "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    fi

    if [[ -n "$itemsToShow" ]]; then
        if ! is_digit "$itemsToShow"; then
            err "number of top big items to display has to be... y'know, a digit" "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi
    else
        itemsToShow=10 # default
    fi

    # the old command, ie using ls, didn't support finding directories:
    #find . $fileTypeArgs  -exec ls -s --block-size=M {} \; | sort -n -r | head -$itemsToShow 2>/dev/null
    #find . -not -name . $fileTypeArgs  -exec du -sm {} \; | sort -n -r | head -$itemsToShow 2>/dev/null

    # exclude the starting dir with the -mindepth 1 opt:
    find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | sort -n $reverse | head -$itemsToShow 2>/dev/null
}

function ffindtopbig() {
    __find_top_big_small_fun "-r" "M" "$FUNCNAME" "large" $@
}

# find top 5/x smallest files:
function ffindtopsmall() {
    #find . -type f -exec ls -s --block-size=K {} \; | sort -n | head -$itemsToShow 2>/dev/null
    __find_top_big_small_fun "" "K" "$FUNCNAME" "small" $@
}

# find smaller/bigger than Xmegas files
function __find_bigger_smaller_common_fun() {
    local usage opt OPTIND fileTypeArgs item compiledFileTypeArgs maxDepthParam maxDepth follow_links reverse du_size_unit FUNCNAME_ biggerOrSmaller sizeArg

    reverse="$1" # sorting order
    du_size_unit="$2"
    FUNCNAME_="$3" #invoking function name
    biggerOrSmaller="$4" #denotes whether larger or smaller than X size units were queried
    shift 4

	if ! [[ "$du_size_unit" =~ ^[KMGTPEZYB]+$ ]]; then
        err "unsupported du block size unit: \"$du_size_unit\"" "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    usage="\n$FUNCNAME_: find nodes $biggerOrSmaller than X $du_size_unit. if node type not specified, defaults to searching for regular files.
    Usage: $FUNCNAME_  [-f] [-d] [-L] [-m depth]  base_size_in_$du_size_unit
        -f  include regular files
        -d  include directories
        -L  follow symlinks
        -m<digit>   max depth to descend"

    while getopts "m:fdLh" opt; do
        case "$opt" in
           f) fileTypeArgs="$fileTypeArgs f"
              shift $((OPTIND-1))
                ;;
           d) fileTypeArgs="$fileTypeArgs d"
              # we don't want to sed maxdepth param here by default, right?
              #maxDepthParam="-maxdepth 1"
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           L) follow_links="-follow"
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done

    sizeArg="$1"

    if [[ -z "$fileTypeArgs" ]]; then
        compiledFileTypeArgs="-type f"
    else
        for item in $fileTypeArgs; do
            [[ -z "$compiledFileTypeArgs" ]] && compiledFileTypeArgs="-type $item" \
                                             || compiledFileTypeArgs="$compiledFileTypeArgs -o -type $item"
        done
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth arg value has to be... y'know, a digit" "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    fi

    if [[ -n "$sizeArg" ]]; then
        if ! is_digit "$sizeArg"; then
            err "base size has to be a digit." "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi
    else
        #sizeArg=5
        err "need to provide base size in $du_size_unit" "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    # note that different find commands are defined purely because of < vs > in awk command.
    if [[ "$biggerOrSmaller" == "smaller" ]]; then # meaning that ffindsmallerthan function was invoker
        #TODO: why doesn't this work? (note the sizeArg in awk):
        #find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | awk '{var=substr($1, 0, length($1))+0; if (var < "'"$sizeArg"'") printf("%s\t%s\n", $1, $2)}' | sort -n $reverse 2>/dev/null
        find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | \
            awk -v sizeArg=$sizeArg '{var=substr($1, 0, length($1))+0; if (var < sizeArg) printf("%s\t%s\n", $1, $2)}' | \
            sort -n $reverse 2>/dev/null
    elif [[ "$biggerOrSmaller" == "bigger" ]]; then # meaning that ffindbiggerthan function was invoker
        find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | \
            awk -v sizeArg=$sizeArg '{var=substr($1, 0, length($1))+0; if (var > sizeArg) printf("%s\t%s\n", $1, $2)}' | \
            sort -n $reverse 2>/dev/null
    else
        err "could not detect whether we should look for smaller or larger than ${sizeArg}$du_size_unit files" "$FUNCNAME_"
        return 1
    fi
}

# find  nodes bigger than x mb:
function ffindbiggerthan() {
    #find . -size +${size}M -exec ls -s --block-size=M {} \; | sort -nr 2>/dev/null
    __find_bigger_smaller_common_fun "-r" "M" "$FUNCNAME" "bigger" $@
}

# find  nodes smalles than x mb:
function ffindsmallerthan() {
    #find . -size -${size}M -exec ls -s --block-size=M {} \; | sort -n 2>/dev/null
    __find_bigger_smaller_common_fun "" "M" "$FUNCNAME" "smaller" $@
}

# mkdir and cd into it:
function mkcd() { mkdir -p "$@" && cd "$@"; }

function aptsearch() {
    [[ -z "$@" ]] && { err "provide partial package name to search for." "$FUNCNAME"; return 1; }
    aptitude search "$@"
    #apt-cache search "$@"
}

function aptsrc() { aptsearch "$@"; } #alias

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of egrep).
function ffstr() {
    local grepcase OPTIND usage opt MAX_RESULT_LINE_LENGTH

    OPTIND=1
    MAX_RESULT_LINE_LENGTH=300 # max nr of characters per grep result line
    usage="$FUNCNAME: find string in files (from current directory recursively).
    Usage: $FUNCNAME [-i] \"pattern\" [filename pattern] "

    while getopts "i" opt; do
        case "$opt" in
           i) grepcase=" -i "
              shift $(( $OPTIND - 1 ))
              ;;
           *) echo "$usage";
              return 1
              ;;
        esac
    done

    if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
        echo "$usage"
        return 1;
    fi

    find . -type f -iname '*'"${2:-*}"'*' -print0 2>/dev/null | \
        xargs -0 egrep --color=always -sn ${grepcase} "$1" | \
        cut -c 1-$MAX_RESULT_LINE_LENGTH | \
        more
        #less
}

function swap() {
    # Swap 2 files around, if they exist (from Uzi's bashrc):
    local TMPFILE file_size space_left_on_target i

    TMPFILE="/tmp/${FUNCNAME}_function_tmpFile.$RANDOM"

    count_params 2 $# equal || return 1
    [[ ! -e "$1" ]] && err "$1 does not exist" "$FUNCNAME" && return 1
    [[ ! -e "$2" ]] && err "$2 does not exist" "$FUNCNAME" && return 1
    [[ "$1" == "$2" ]] && err "source and destination cannot be the same" "$FUNCNAME" && return 1

    # check write perimssions:
    for i in "$TMPFILE" "$1" "$2"; do
        i="$(dirname "$i")"
        if [[ ! -w "$i" ]]; then
            err "$i doesn't have write permission. abort." "$FUNCNAME"
            return 1
        fi
    done

    # check if $1 fits into /tmp:
    file_size="$(get_size "$1")"
    space_left_on_target="$(space_left "$TMPFILE")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$1 size is ${file_size}MB, but $(dirname "$TMPFILE") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        return 1
    fi

    if ! mv "$1" "$TMPFILE"; then
        err "moving $1 to $TMPFILE failed. abort." "$FUNCNAME"
        return 1
    fi

    # check if $2 fits into $1:
    file_size="$(get_size "$2")"
    space_left_on_target="$(space_left "$1")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$2 size is ${file_size}MB, but $(dirname "$1") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        # undo:
        mv "$TMPFILE" "$1"
        return 1
    fi

    if ! mv "$2" "$1"; then
        err "moving $2 to $1 failed. abort." "$FUNCNAME"
        # undo:
        mv "$TMPFILE" "$1"
        return 1
    fi

    # check if $1 fits into $2:
    file_size="$(get_size "$TMPFILE")"
    space_left_on_target="$(space_left "$2")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$1 size is ${file_size}MB, but $(dirname "$2") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        # undo:
        mv "$1" "$2"
        mv "$TMPFILE" "$1"
        return 1
    fi

    if ! mv "$TMPFILE" "$2"; then
        err "moving $1 to $2 failed. abort." "$FUNCNAME"
        # undo:
        mv "$1" "$2"
        mv "$TMPFILE" "$1"
        return 1
    fi
}

# list current directory and search for a file/dir by name:
function lgrep() {
    local SRC SRCDIR usage

    SRC="$1"
    SRCDIR="$2"
    usage="$FUNCNAME  filename_to_grep  [dir_to_look_from]"
    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$SRC" ]]; then
        echo -e "$usage"
        return 1;
    elif [[ -n "$SRCDIR" ]]; then
        if [[ ! -d "$SRCDIR" ]]; then
            err "provided directory to list and grep from is not a directory. abort." "$FUNCNAME"
            echo -e "\n$usage"
            return 1
        elif [[ ! -r "$SRCDIR" ]]; then
            err "provided directory to list and grep from is not readable. abort." "$FUNCNAME"
            return 1
        fi
    fi

    ls -lA "${SRCDIR:-.}" | grep --color=auto -i "$SRC"
    #[[ $# != 1 ]] && { echo -e "$FUNCNAME name_to_grep [dir_to_look_from]"; return 1; }

    #[[ -z "$@" ]] && { echo -e "$FUNCNAME filename_pattern"; return 1; }
    #ls -A | grep --color=auto -i "\'$@\'"
}

# Make your directories and files access rights sane.
# (sane as in rw for owner, r for group, none for others)
function sanitize() {
    [[ -z "$@" ]] && { err "provide a file/dir name plz." "$FUNCNAME"; return 1; }
    [[ ! -e "$@" ]] && { err "\"$@\" does not exist." "$FUNCNAME"; return 1; }
    chmod -R u=rwX,g=rX,o= "$@";
}

function sanitize_ssh() {
    local dir="$@"

    [[ -z "$dir" ]] && { err "provide a file/dir name plz. (most likely you want the .ssh dir)" "$FUNCNAME"; return 1; }
    [[ ! -e "$dir" ]] && { err "\"$dir\" does not exist." "$FUNCNAME"; return 1; }

    chmod -R u=rwX,g=,o= "$dir";
}

function ssh_sanitize() { sanitize_ssh "$@"; } # alias for sanitize_ssh

function my_ip() { # Get internal & external ip addies:
    local internal_ip external_ip connected_interface

    connected_interface="$(find_connected_if)"

    if [[ -n "$connected_interface" ]]; then
        external_ip="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)"
        internal_ip="$(/sbin/ifconfig "$connected_interface" | awk '/inet/ { print $2 } ' | sed -e s/addr://)"
        echo "${internal_ip:-"Not connected"} @ $connected_interface"
        echo "${external_ip:-"Not connected"}"
        return 0
    fi

    echo "Not connected"
}

function myip() { my_ip; } # alias for my_ip
function whatsmyip() { my_ip; } # alias for my_ip

# !! lrzip might offer best compression when it comes to text: http://unix.stackexchange.com/questions/78262/which-file-compression-software-for-linux-offers-the-highest-size-reduction
function compress() {
    local usage file type
    file="$1"
    type="$2"
    usage="$FUNCNAME  fileOrDir  [zip|tar|rar|7z]\n\tif not provided, compression type defaults to tar (tar.bz2) "

    [[ $# -eq 1 || $# -eq 2 ]] || { err "gimme file/dir to compress plox.\n" "$FUNCNAME"; echo -e "$usage"; return 1; }
    [[ -e "$file" ]] || { err "$file doesn't exist." "$FUNCNAME"; echo -e "\n\n$usage"; return 1; }
    [[ -z "$type" ]] && { report "no compression type selected, defaulting to tar.bz2\n" "$FUNCNAME"; type="tar"; } # default to tar

    case "$type" in
        zip) makezip "$file"
             ;;
        #tar) maketar "$file"
        tar) maketar2 "$file"
             ;;
        rar) [[ -d "$file" ]] || { err "input for rar has to be a dir" "$FUNCNAME"; return 1; }
             makerar "$file"
             ;;
        7z)  make7z "$file"
             ;;
        *)   err "compression type not supported\n" "$FUNCNAME"
             echo -e "$usage";
             return 1;
             ;;
    esac
}

# alias for compress
function pack() { compress $@; }

# Creates an archive (*.tar.gz) from given directory.
function maketar() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }

# Creates an archive (*.tar.bz2) from given directory.
# j - use bzip2 compression rather than z option  (heavier compression)
function maketar2() { tar cvjf "${1%%/}.tar.bz2"  "${1%%/}/"; }

# Create a rar archive.
# -m# - compresson lvl, 5 being max level, 0 just storage;
function makerar() { rar a -r -rr10 -m4 "${1%%/}.rar"  "${1%%/}/"; }

# Create a ZIP archive of a file or folder.
function makezip() { zip -r "${1%%/}.zip" "$1"; }

# Create a 7z archive of a file or folder.
# -mx=# - compression lvl, 9 being highest (ultra)
function make7z() { 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "${1%%/}.7z" "$1"; }

# alias for extract
function unpack() { extract $@; }

# helper wrapper for uncompressing archives. it uncompresses into new directory, which
# name is the same as the archive's, minus the file extension. this avoids the situations
# where gazillion files are being extracted into workin dir. note that if the dir
# already exists, then unpacking fails (since mkdir fails).
function extract() {
    local file="$1"
    local file_without_extension="${file%.*}"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz." "$FUNCNAME"
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "'$file' is not a valid file or read rights not granted." "$FUNCNAME"
        return 1
    fi

    case "$file" in
        *.tar.bz2)   file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir "$file_without_extension" && tar xjf $file -C $file_without_extension
                        ;;
        *.tar.gz)    file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir "$file_without_extension" && tar xzf $file -C $file_without_extension
                        ;;
        *.tar.xz)    file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir "$file_without_extension" && tar xpvf $file -C $file_without_extension
                        ;;
        *.bz2)       bunzip2 -k $file
                        ;;
        *.rar)       mkdir "$file_without_extension" && unrar x $file ${file_without_extension}/
                        ;;
        *.gz)        gunzip -kd $file
                        ;;
        *.tar)       mkdir "$file_without_extension" && tar xf $file -C $file_without_extension
                        ;;
        *.tbz2)      mkdir "$file_without_extension" && tar xjf $file -C $file_without_extension
                        ;;
        *.tgz)       mkdir "$file_without_extension" && tar xzf $file -C $file_without_extension
                        ;;
        *.zip)       mkdir "$file_without_extension" && unzip $file -d $file_without_extension
                        ;;
        *.7z)        mkdir "$file_without_extension" && 7z x "-o$file_without_extension" $file
                        ;;
                        # TODO .Z is unverified how and where they'd unpack:
        *.Z)         uncompress $file  ;;
        *)           err "'$file' cannot be extracted; this filetype is not supported." "$FUNCNAME"
                        return 1
                        ;;
    esac

    # at the moment this reporting could be erroneous if mkdir fails:
    #echo -e "extracted $file contents into $file_without_extension"
}

fontreset() {
    fc-cache -fv
    mkfontscale ~/.fonts
    mkfontdir ~/.fonts
    xset +fp ~/.fonts
    xset fp rehash
}

# alias for fontreset:
resetfont() { fontreset; }

# TODO: rewrite this one, looks stupid:
up() {
  local d=""
  local limit=$1
  for ((i=1 ; i <= limit ; i++)); do
      d="$d/.."
  done
  d="$(echo $d | sed 's/^\///')"
  [[ -z "$d" ]] && d=".."

  cd $d
}

# clock - A bash clock that can run in your terminal window:
clock() {
    while true; do
        clear
        echo "=========="
        echo " $(date +"%R:%S") " # echo for padding
        echo "=========="
        sleep 1
    done
}

xmlformat() {
    [[ -z "$@" ]] && { echo -e "usage:   $FUNCNAME  <filename>"; return 1; }
    [[ -f "$@" && -r "$@" ]] || { err "provided file \"$@\" is not a regular file or is not readable. abort." "$FUNCNAME"; return 1; }
    xmllint --format $@ | vim  "+set foldlevel=99" -;
}

function xmlf() { xmlformat $@; } # alias for xmlformat;

function createUsbIso() {
    local file device mountpoint cleaned_devicename usage
    file="$1"
    device="$2"

    cleaned_devicename="${device%/}" # strip trailing slash
    cleaned_devicename="${cleaned_devicename##*/}"  # strip everything before last slash(slash included)
    usage="$FUNCNAME  image.file  device"

    if [[ -z "$file" || -z "$device" || -z "$cleaned_devicename" ]]; then
        err "either file or device weren't provided" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ ! -f "$file" ]]; then
        err "$file is not a regular file" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ ! -e "$device" ]]; then
        err "$device does not exist" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif ! ls /dev | grep "\b$cleaned_devicename\b";then
        err "$device does not exist in /dev" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "${cleaned_devicename:$(( ${#cleaned_devicename} - 1)):1}" =~ ^[0-9:]+$ ]]; then
        # as per arch wiki
        err "please don't provide partition, but a drive, e.g. /dev/sdh instad of /dev/sdh1" "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    #echo "please provide passwd for running fdisk -l to confirm the selected device is the right one:"
    #sudo fdisk -l $device
    lsblk | grep --color=auto "$cleaned_devicename\|MOUNTPOINT"

    if ! confirm  "\nis selected device - $device - the correct one (be VERY sure!)? (y/n)"; then
        return 1
    fi

    # find if device is mounted:
    #lsblk -o name,size,mountpoint /dev/sda
    mountpoint="$(lsblk -o mountpoint "$device" | sed -n 3p)"
    if [[ -n "$mountpoint" ]]; then
        report "$device appears to be mounted at $mountpoint, trying to unmount..." "$FUNCNAME"
        if ! umount "$mountpoint"; then
            err "something went wrong with unmounting. please unmount the device and try again." "$FUNCNAME"
            return 1
        fi
        report "...success." "$FUNCNAME"
    fi

    report "Please provide sudo passwd for running dd:" "$FUNCNAME"
    sudo echo -e "Running dd, this might take a while..." # do not use 'report' as root might not have that
    sudo dd if="$file" of="$device" bs=4M
    sync
    #eject $device
}

#######################
## Setup github repo ##
#######################
function mkgit() {
   local GITHUB="laur89"
   local dir="$1"
   local gitname="$2"

   # check dir
   [[ -n "$dir" ]] || {
      err "usage: mkgit <dir> [name]" "$FUNCNAME"
      return 1
   }

   # use dir name if, no gitname specified
   [[ -n "$gitname" ]] || gitname="$dir"
   [[ -d "$dir"     ]] || mkdir "$dir"

   # bail out, if already git repo
   [[ -d "$dir/.git" ]] && {
      err "already a git repo: $dir" "$FUNCNAME"
      return 1
   }

   cd "$dir"
   git init || { err "bad return from git init" "$FUNCNAME"; return 1; }
   touch README; git add README
   git commit -a -m 'inital setup - automated'
   git remote add origin "git@github.com:$GITHUB/$gitname.git"
   git push -u origin master
}

######################################
## Open file inside git tree on vim ##
######################################
vimo() {
   local match=
   local gtdir=
   local cwd=$PWD
   git ls-files &>/dev/null || return # test if git
   gtdir="$(git rev-parse --show-toplevel )"
   [[ "$cwd" != "$gtdir" ]] && pushd "$gtdir" &> /dev/null # git root
   [[ -n "$@" ]] && { match="$(git ls-files | grep "$@")"; } ||
                      match="$(git ls-files)"
   [[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | bemenu -i -l 20 -p "vim")"
   match="$gtdir/$match" # convert to absolute
   [[ "$cwd" != "$gtdir" ]] && popd &> /dev/null # go back
   [[ -f "$match" ]] || return
   vim "$match"
}

function sethometime() {
    timedatectl set-timezone Europe/Tallinn
}

#function setesttime() { sethometime; }
function setestoniatime() { sethometime; }

function setgibtime() {
    timedatectl set-timezone Europe/Gibraltar
}

function setspaintime() {
    timedatectl set-timezone Europe/Madrid
}

########################
## Print window class ##
########################
xclass() {
   xprop |awk '
   /^WM_CLASS/{sub(/.* =/, "instance:"); sub(/,/, "\nclass:"); print}
   /^WM_NAME/{sub(/.* =/, "title:"); print}'
}

################
## Smarter CD ##
################
goto() {
   [[ -d "$1" ]] && { cd "$1"; } || cd "$(dirname "$1")";
}

####################
## Copy && Follow ##
####################
cpf() {
   cp "$@" && goto "$_";
}

####################
## Move && Follow ##
####################
mvf() {
   mv "$@" && goto "$_";
}

#####################################
## Take screenshot of main monitor ##
#####################################
shot() {
   local mon=$@
   local file="$HOME/shot-$(date +'%H:%M-%d-%m-%Y').png"
   [[ -n "$mon" ]] || mon=0
   ffcast -x $mon % scrot -g %wx%h+%x+%y "$file"
}

###################
## Capture video ##
###################
capture() {
   ffcast -w ffmpeg -f alsa -ac 2 -i hw:0,2 -f x11grab -s %s -i %D+%c -acodec pcm_s16le -vcodec huffyuv $@
}

##############################################
## Colored Find                             ##
## NOTE: Searches current tree recrusively. ##
##############################################
f() {
   find . -iregex ".*$@.*" -printf '%P\0' | xargs -r0 ls --color=auto -1d
}
