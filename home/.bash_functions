#!/bin/bash
#
# good source to begin with: http://tldp.org/LDP/abs/html/sample-bashrc.html
# TODO: check this!: https://github.com/Cloudef/dotfiles-ng/blob/master/#ARCHCONFIG/shell/functions
# also this for general dotfiles/scripts goodness: https://github.com/Donearm
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

# gnu find wrapper.
# find files or dirs.
# TODO: refactor the massive spaghetti.
function ffind() {
    local SRC SRCDIR INAME_ARG opt usage OPTIND file_type filetypeOptionCounter exact binary follow_links
    local maxDepth maxDepthParam pathOpt regex defMaxDeptWithFollowLinks force_case caseOptCounter skip_msgs
    local quitFlag

    [[ "$1" == --_skip_msgs ]] && { skip_msgs=1; shift; }  # skip showing informative messages, as the result will be directly echoed to other processes;
    defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) is provided;

    usage="\n$FUNCNAME: find files/dirs by name. smartcase.

    Usage: $FUNCNAME  [options]  \"fileName pattern\" [top_level_dir_to_search_from]

        -r  use regex (so the find specific metacharacters *, ? and [] won't work)
        -i  force case insensitive
        -s  force case sensitivity
        -f  search for regular files
        -d  search for directories
        -l  search for symbolic links
        -b  search for executable binaries
        -L  follow symlinks
        -q  provide find the -quit flag (exit on first found item)
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;
        -e  search for exact filename, not for a partial (you still can use * wildcards)
        -p  expand the pattern search for path as well (adds the -path option)"

    filetypeOptionCounter=0
    caseOptCounter=0

    while getopts "m:isrefdlbLqph" opt; do
        case "$opt" in
           i) INAME_ARG="-iname"
              caseOptCounter+=1
              shift $((OPTIND-1))
                ;;
           s) unset INAME_ARG
              force_case=1
              caseOptCounter+=1
              shift $((OPTIND-1))
                ;;
           r) regex=1
              shift $((OPTIND-1))
                ;;
           e) exact=1
              shift $((OPTIND-1))
                ;;
           f | d | l) file_type="-type $opt"
              let filetypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           b) binary=1
              let filetypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           L) follow_links="-L"
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           p) pathOpt=1
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              [[ "$skip_msgs" -eq 1 ]] && return 9 || return 0
                ;;
           q) quitFlag="-quit"
              shift $((OPTIND-1))
                ;;
           *) echo -e "$usage"
              [[ "$skip_msgs" -eq 1 ]] && return 9 || return 1
                ;;
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
    elif [[ "$caseOptCounter" -gt 1 ]]; then
        err "-i and -s flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$pathOpt" -eq 1 && "$regex" -eq 1 ]]; then
        err "-r and -p flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$exact" -eq 1 && "$regex" -eq 1 ]]; then
        err "-r and -e flags are exclusive, since regex always searches the whole path anyways, meaning script will always pad beginning with .*" "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi


    if [[ "$follow_links" == "-L" && "$file_type" == "-type l" && "$skip_msgs" -ne 1 ]]; then
        report "if both -l and -L flags are set, then ONLY the broken links are being searched.\n" "$FUNCNAME"
        sleep 2
    fi

    # as find doesn't support smart case, provide it yourself:
    if [[ "$(tolowercase "$SRC")" == "$SRC" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        INAME_ARG="-iname"
    fi

    [[ "$force_case" -eq 1 ]] && unset INAME_ARG


    if [[ "$pathOpt" -eq 1 && "$exact" -eq 1 && "$skip_msgs" -ne 1 ]]; then
        report "note that using -p and -e flags together means that the pattern has to match whole path, not only the filename!" "$FUNCNAME"
        sleep 2
    fi

    if [[ -n "$SRCDIR" ]]; then
        if [[ ! -d "$SRCDIR" ]]; then
            err "provided directory to search from (\"$SRCDIR\") is not a directory. abort." "$FUNCNAME"
            return 1
        elif [[ "$SRCDIR" != */ ]]; then
            SRCDIR="${SRCDIR}/"  # add trailing slash if missing; required for gnu find; necessary in case it's a link.
        fi
    fi

    # find metacharacter or regex sanity:
    if [[ "$regex" -eq 1 ]]; then
        if [[ "$SRC" == *\** && "$SRC" != *\.\** ]]; then
            err 'use .* as wildcards, not a single *; you are misusing regex.' "$FUNCNAME"
            return 1
        elif [[ "$(echo "$SRC" | tr -dc '.' | wc -m)" -lt "$(echo "$SRC" | tr -dc '*' | wc -m)" ]]; then
            err "nr of periods (.) was less than stars (*); you're misusing regex." "$FUNCNAME"
            return 1
        fi
    else  # no regex, make sure find metacharacters are not mistaken for regex ones:
        if [[ "$SRC" == *\.\** ]]; then
            err "only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex." "$FUNCNAME"
            return 1
        fi

        if [[ "$SRC" == *\.* && "$skip_msgs" -ne 1 ]]; then
            report "note that period (.) will be used as a literal period, not as a wildcard. provide -r flag to use regex.\n" "$FUNCNAME"
        fi
    fi


    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth (the -m flag) arg value has to be a positive digit, but was \"$maxDepth\"" "$FUNCNAME"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    elif [[ -n "$follow_links" ]]; then
        # TODO: perhaps force maxdepth regardless whether followlinks is used?
        maxDepthParam="-maxdepth $defMaxDeptWithFollowLinks"
    fi

    if [[ "$pathOpt" -eq 1 ]]; then
        [[ -n "$INAME_ARG" ]] && INAME_ARG="-iwholename" || INAME_ARG="-path"  # as per man page, -ipath is deprecated
    elif [[ "$regex" -eq 1 ]]; then
        [[ -n "$INAME_ARG" ]] && INAME_ARG="-regextype posix-extended -iregex" || INAME_ARG="-regextype posix-extended -regex"
    fi

    # grep is for coloring only:
    #find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' | grep -i --color=auto "$SRC" 2>/dev/null
    if [[ "$exact" -eq 1 ]]; then # no regex with exact; they are excluded.
        if [[ "$binary" -eq 1 ]]; then
            find $follow_links "${SRCDIR:-.}" $maxDepthParam -type f "${INAME_ARG:--name}" "$SRC" -executable -exec sh -c "file -ib '{}' | grep -q 'x-executable; charset=binary'" \; -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$SRC|$"
        else
            find $follow_links "${SRCDIR:-.}" $maxDepthParam $file_type "${INAME_ARG:--name}" "$SRC" -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$SRC|$"
        fi
    else # partial filename match, ie add * padding
        if [[ "$regex" -eq 1 ]]; then  # using regex, need to change the * padding around $SRC
            #
            # TODO eval!
            #
            if [[ "$binary" -eq 1 ]]; then
                # TODO: this doesnt work atm:
                err "executalbe binary file search in regex currently unimplemented" "$FUNCNAME"
                return 1
                # this doesn't work atm:
                eval find $follow_links "${SRCDIR:-.}" $maxDepthParam -type f "${INAME_ARG:--name}" '.*'"$SRC"'.*' -executable -exec sh -c "file -ib '{}' | grep -q 'x-executable; charset=binary'" \; -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$SRC|$"
            else
                report "!!! running with eval, be careful !!!" "$FUNCNAME"
                sleep 2
                eval find $follow_links "${SRCDIR:-.}" $maxDepthParam $file_type "${INAME_ARG:--name}" '.*'"$SRC"'.*' -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$SRC|$"
            fi
        else  # no regex
            if [[ "$binary" -eq 1 ]]; then
                find $follow_links "${SRCDIR:-.}" $maxDepthParam -type f "${INAME_ARG:--name}" '*'"$SRC"'*' -executable -exec sh -c "file -ib '{}' | grep -q 'x-executable; charset=binary'" \; -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$SRC|$"
            else
                find $follow_links "${SRCDIR:-.}" $maxDepthParam $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$SRC|$"
            fi
        fi
    fi
}

# Find a file with a pattern in name (inside wd);
# essentially same as ffind(), but a bit simplified:
#function ff() {
    #find . -type f -iname '*'"$*"'*'  -ls
#}

function ffindproc() {
    [[ -z "$1" ]] && { err "process name required" "$FUNCNAME"; return 1; }
    # last grep for re-coloring:
    ps -ef | grep -v '\bgrep\b' | grep -i --color=auto -- "$1"

    # TODO: add also exact match option?:
    #   grep '\$1\b'
}

# find top 5/x biggest or smallest nodes:
function __find_top_big_small_fun() {
    local usage opt OPTIND itemsToShow file_type maxDepthParam maxDepth follow_links reverse du_size_unit FUNCNAME_
    local bigOrSmall du_include_regular_files duMaxDepthParam filetypeOptionCounter

    reverse="$1" # this basically decides whether we're showing top big or small.
    du_size_unit="$2" # default unit provided by the invoker
    FUNCNAME_="$3"
    bigOrSmall="$4"
    shift 4

    filetypeOptionCounter=0

    if ! [[ "$du_size_unit" =~ ^[KMGTPEZYB]+$ && "${#du_size_unit}" -eq 1 ]]; then
        err "unsupported du block size unit: \"$du_size_unit\"" "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    usage="\n$FUNCNAME_: find top $bigOrSmall nodes from current dir.\nif node type not specified, defaults to searching for everything.\n
    Usage: $FUNCNAME_  [-f] [-d] [-L] [-m depth]  [nr_of_top_items_to_show]
        -f  search only for regular files
        -d  search only for directories
        -L  follow/dereference symlinks
        -m<digit>   max depth to descend; unlimited by default."

    while getopts "m:fdLh" opt; do
        case "$opt" in
           f | d) file_type="-type $opt"
              let filetypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           L) follow_links="-L" # common for both find and du
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done

    itemsToShow="$1"

    if [[ "$#" -gt 1 ]]; then
        err "maximum of one arg allowed" "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth arg value has to be... y'know, a digit" "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
        duMaxDepthParam="--max-depth=$maxDepth"
    fi

    if [[ -n "$itemsToShow" ]]; then
        if ! is_digit "$itemsToShow"; then
            err "number of top big items to display has to be... y'know, a digit" "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi
    else
        itemsToShow=10  # default
    fi

    if [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f and -d flags are exclusive." "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    report "seeking for top $itemsToShow $bigOrSmall files (in $du_size_unit units)...\n" "$FUNCNAME_"

    if [[ "$du_size_unit" == B ]]; then
        du_size_unit="--bytes"
    else
        du_size_unit="--block-size=$du_size_unit"
    fi

    if [[ "$file_type" == "-type f" ]]; then
        # optimization for files-only logic (ie no directories) to avoid expensive
        # calls to other programs (like awk and du).

        find $follow_links . -mindepth 1 $maxDepthParam $file_type -exec du -a "$du_size_unit" '{}' +  2>/dev/null | \
                sort -n $reverse | \
                head -$itemsToShow

    else  # covers both dirs only & dirs+files cases:
        [[ "$file_type" != "-type d" ]] && du_include_regular_files="--all"  # if not dirs only;

        # TODO: here, for top_big_small, consider for i in G M K for the du -h!:
        du $follow_links $du_include_regular_files $du_size_unit $duMaxDepthParam 2>/dev/null | \
                sort -n $reverse | \
                head -$itemsToShow

    #
    # !! this one's slow and old, but works with errything, ie dirs and files included:
    #
    #else
                # the old command, ie using ls, didn't support finding directories:
                #find . $file_type  -exec ls -s --block-size=M {} \; | sort -n -r | head -$itemsToShow 2>/dev/null
                #find . -not -name . $file_type  -exec du -sm {} \; | sort -n -r | head -$itemsToShow 2>/dev/null


                # good stuff from http://www.cyberciti.biz/faq/how-do-i-find-the-largest-filesdirectories-on-a-linuxunixbsd-filesystem/:
                # find top filesizes, but add only last levels for the dirs!:
                    # for i in G M K; do du -ah | grep [0-9]$i | sort -nr -k 1; done | head -n 11
                    # for i in G M K; do du -ah | grep ^[0-9\.]*$i | sort -nr -k 1; done | head -n 110
                # find grand total of jpg files:
                    # find ./photos/john_doe -type f -name '*.jpg' -exec du -ch {} + | grep total$


                # summing tip:
                # | awk '{sum+=$1} END {print sum}'    # to sum stuff


        # old, all-fits-one comm:
        # exclude the starting dir with the -mindepth 1 opt:
        #find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | \
            #sort -n $reverse | \
            #head -$itemsToShow
    fi
}

function ffindtopbig() {
    __find_top_big_small_fun "-r" "M" "$FUNCNAME" "large" "$@"
}

function ffindtopsmall() {
    #find . -type f -exec ls -s --block-size=K {} \; | sort -n | head -$itemsToShow 2>/dev/null
    __find_top_big_small_fun "" "K" "$FUNCNAME" "small" "$@"
}

# find smaller/bigger than Xmegas files
function __find_bigger_smaller_common_fun() {
    local usage opt OPTIND file_type maxDepthParam maxDepth follow_links reverse du_size_unit FUNCNAME_ biggerOrSmaller sizeArg
    local du_include_regular_files duMaxDepthParam plusOrMinus filetypeOptionCounter sizeArgLastChar du_blk_sz find_size_unit

    reverse="$1" # sorting order
    du_size_unit="$2" # default unit provided by the invoker
    FUNCNAME_="$3" #invoking function name
    biggerOrSmaller="$4" #denotes whether larger or smaller than X size units were queried
    shift 4

    filetypeOptionCounter=0

    if ! [[ "$du_size_unit" =~ ^[KMGTPEZYB]+$ && "${#du_size_unit}" -eq 1 ]]; then
        err "unsupported du block size unit: \"$du_size_unit\"" "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    usage="\n$FUNCNAME_: find nodes $biggerOrSmaller than X $du_size_unit from current dir.\nif node type not specified, defaults to searching for everything.\n
    Usage: $FUNCNAME_  [-f] [-d] [-L] [-m depth]  base_size_in_<du_size_unit>

        the <du_size_unit> can be any of [KMGTPEZYB]; if not provided, defaults to $du_size_unit.
        ('B' is for bytes; KB, MB etc for base 1000 not supported)

        -f  search only for regular files
        -d  search only for directories
        -L  follow/dereference symlinks
        -m<digit>   max depth to descend; unlimited by default.

        examples:
            $FUNCNAME_ 300       - seek files and dirs $biggerOrSmaller than 300 default
                                        du_size_units, which is $du_size_unit;
            $FUNCNAME_ -f 12G    - seek files $biggerOrSmaller than 12 gigs;
            $FUNCNAME_ -dm3 12K  - seek dirs $biggerOrSmaller than 12 kilobytes;
                                        descend up to 3 levels from current dir.
"

    while getopts "m:fdLh" opt; do
        case "$opt" in
           f | d) file_type="-type $opt"
              let filetypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           L) follow_links="-L" # common for both find and du
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done

    sizeArg="$1"

    if [[ "$#" -ne 1 ]]; then
        err "exactly one arg required" "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth arg value has to be... y'know, a digit" "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
        duMaxDepthParam="--max-depth=$maxDepth"
    fi

    if [[ -n "$sizeArg" ]]; then
        sizeArgLastChar="${sizeArg:$(( ${#sizeArg} - 1)):1}"

        if ! is_digit "$sizeArgLastChar"; then
            if ! [[ "$sizeArgLastChar" =~ ^[KMGTPEZYB]+$ ]]; then
                err "unsupported du block size unit provided: \"$sizeArgLastChar\"" "$FUNCNAME_"
                return 1
            fi

            # override du_size_unit defined by the invoker:
            du_size_unit="$sizeArgLastChar"

            sizeArg="${sizeArg:0:$(( ${#sizeArg} - 1))}"
        fi

        if [[ -z "$sizeArg" ]]; then
            err "base size has to be provided as well, not only the unit." "$FUNCNAME_"
            echo -e "$usage"
            return 1
        elif ! is_digit "$sizeArg"; then
            err "base size has to be a positive digit, but was \"$sizeArg\"." "$FUNCNAME_"
            echo -e "$usage"
            return 1
        fi
    else
        #sizeArg=5
        err "need to provide base size in $du_size_unit" "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    if [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f and -d flags are exclusive." "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi


    # invoker sanity: (and +/- definition for find -size and du --threshold args)
    if [[ "$biggerOrSmaller" == "smaller" ]]; then
        plusOrMinus='-'
    elif [[ "$biggerOrSmaller" == "bigger" ]]; then
        plusOrMinus='+'
    else
        err "could not detect whether we should look for smaller or larger than ${sizeArg}$du_size_unit files" "$FUNCNAME"
        return 1
    fi

    report "seeking for files $biggerOrSmaller than ${sizeArg}${du_size_unit}...\n" "$FUNCNAME_"

    if [[ "$du_size_unit" == B ]]; then
        du_blk_sz="--bytes"
    else
        du_blk_sz="--block-size=$du_size_unit"
    fi

    if [[ "$file_type" == "-type f" ]]; then
        # optimization for files-only logic (ie no directories) to avoid expensive
        # calls to other programs (like awk and du).

        find_size_unit="$du_size_unit"

        if ! [[ "$du_size_unit" =~ ^[KMGB]+$ ]]; then
            err "unsupported block size unit for find: \"$du_size_unit\". refer to man find and search for \"-size\"" "$FUNCNAME_"
            echo -e "$usage"
            return 1

        # convert some of the du types to the find equivalents:
        elif [[ "$du_size_unit" == B ]]; then
            find_size_unit=c  # bytes unit for find
        elif [[ "$du_size_unit" == K ]]; then
            find_size_unit=k  # kilobytes unit for find
        fi


        # old version using find's printf:
        # find's printf:
        # %s file size in byte   - appears to be the same as du block-size w/o any units
        # %k in 1K blocks
        # %b in 512byte blocks
        #find $follow_links . -mindepth 1 $maxDepthParam -size ${plusOrMinus}${sizeArg}${du_size_unit} $file_type -printf "%${filesize_print_unit}${orig_size_unit}\t%P\n" 2>/dev/null | \
            #sort -n $reverse

        find $follow_links . -mindepth 1 $maxDepthParam -size ${plusOrMinus}${sizeArg}${find_size_unit} $file_type -exec du -a "$du_blk_sz" '{}' +  2>/dev/null | \
                sort -n $reverse

    else  # directories included, need to use du + awk
        # note that different find commands are defined purely because of < vs > in awk command.; could overcome
        # by using eval, but better not.

        # old, find+du combo; slow as fkuk:
        #if [[ "$biggerOrSmaller" == "smaller" ]]; then # meaning that ffindsmallerthan function was invoker
            ##TODO: why doesn't this work? (note the sizeArg in awk):
            ##find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | awk '{var=substr($1, 0, length($1))+0; if (var < "'"$sizeArg"'") printf("%s\t%s\n", $1, $2)}' | sort -n $reverse 2>/dev/null
            #find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | \
                #awk -v sizeArg=$sizeArg '{var=substr($1, 0, length($1))+0; if (var < sizeArg) printf("%s\t%s\n", $1, $2)}' | \
                #sort -n $reverse 2>/dev/null
        #else
            #find . $follow_links -mindepth 1 $maxDepthParam \( $compiledFileTypeArgs \)  -exec du -s --block-size=${du_size_unit} {} \; 2>/dev/null | \
                #awk -v sizeArg=$sizeArg '{var=substr($1, 0, length($1))+0; if (var > sizeArg) printf("%s\t%s\n", $1, $2)}' | \
                #sort -n $reverse 2>/dev/null
        #fi

        if [[ "$du_size_unit" == B ]]; then
            unset du_size_unit  # with bytes, --threshold arg doesn't need a unit
        fi

        [[ "$file_type" != "-type d" ]] && du_include_regular_files="--all"  # if not dirs only;

        du $follow_links $du_include_regular_files $du_blk_sz $duMaxDepthParam --threshold=${plusOrMinus}${sizeArg}${du_size_unit} 2>/dev/null | \
                sort -n $reverse
    fi
}

# find  nodes bigger than x mb:
function ffindbiggerthan() {
    #find . -size +${size}M -exec ls -s --block-size=M {} \; | sort -nr 2>/dev/null
    __find_bigger_smaller_common_fun "-r" "M" "$FUNCNAME" "bigger" "$@"
}

# find  nodes smaller than x mb:
function ffindsmallerthan() {
    #find . -size -${size}M -exec ls -s --block-size=M {} \; | sort -n 2>/dev/null
    __find_bigger_smaller_common_fun "" "M" "$FUNCNAME" "smaller" "$@"
}

function aptsearch() {
    [[ -z "$@" ]] && { err "provide partial package name to search for." "$FUNCNAME"; return 1; }
    check_progs_installed apt-cache || return 1

    apt-cache search -- "$@"
    #aptitude search -- "$@"
}

function aptsrc() { aptsearch "$@"; } # alias

function aptreset() {

    report "note that sudo passwd is required" "$FUNCNAME"

    sudo apt-get clean
    if [[ -d "/var/lib/apt/lists" ]]; then
        sudo rm -rf /var/lib/apt/lists/*
    else
        err "/var/lib/apt/lists is not a lib; can't delete the contents" "$FUNCNAME"
    fi
    sudo apt-get clean
    #sudo apt-get update
    #sudo apt-get upgrade
}

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of grep).
# !!! deprecated by ag/astr
# TODO: find whether we could stop using find here and use grep --include & --exclude flags instead.
function ffstr() {
    local grepcase OPTIND usage opt MAX_RESULT_LINE_LENGTH caseOptCounter force_case regex
    local INAME_ARG maxDepth maxDepthParam defMaxDeptWithFollowLinks follow_links

    caseOptCounter=0
    OPTIND=1
    MAX_RESULT_LINE_LENGTH=300      # max nr of characters per grep result line
    defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) is provided;

    usage="\n$FUNCNAME: find string in files (from current directory recursively). smartcase both for filename and search patterns.
    Usage: $FUNCNAME [opts] \"pattern\" [filename pattern]
        -i  force case insensitive
        -s  force case sensitivity
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;
        -L  follow symlinks
        -r  enable regex on filename pattern"


    command -v ag > /dev/null && report "consider using ag or its wrapper astr (same thing as $FUNCNAME, but using ag instead of find+grep)\n" "$FUNCNAME"

    while getopts "isrm:Lh" opt; do
        case "$opt" in
           i) grepcase=" -i "
              INAME_ARG="-iname"
              caseOptCounter+=1
              shift $(( $OPTIND - 1 ))
              ;;
           s) unset grepcase
              unset INAME_ARG
              force_case=1
              caseOptCounter+=1
              shift $((OPTIND-1))
                ;;
           r) regex=1
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           L) follow_links="-L"
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
        err "incorrect nr of arguments." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$caseOptCounter" -gt 1 ]]; then
        err "-i and -s flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    # grep search pattern sanity:
    if [[ "$1" == *\** && "$1" != *\.\** ]]; then
        err "use .* as wildcards, not a single *" "$FUNCNAME"
        return 1
    elif [[ "$(echo "$1" | tr -dc '.' | wc -m)" -lt "$(echo "$1" | tr -dc '*' | wc -m)" ]]; then
        err "nr of periods (.) was less than stars (*); you're misusing regex." "$FUNCNAME"
        return 1
    fi


    # find metacharacter or regex FILENAME (not search pattern) sanity:
    if [[ -n "$2" ]]; then
        if [[ "$2" == */* ]]; then
            err "there are slashes in the filename. note that optional 2nd arg is a filename pattern, not a path." "$FUNCNAME"
            return 1
        fi

        if [[ "$regex" -eq 1 ]]; then
            if [[ "$2" == *\** && "$2" != *\.\** ]]; then
                err 'err in filename pattern: use .* as wildcards, not a single *; you are misusing regex.' "$FUNCNAME"
                return 1
            elif [[ "$(echo "$2" | tr -dc '.' | wc -m)" -lt "$(echo "$2" | tr -dc '*' | wc -m)" ]]; then
                err "err in filename pattern: nr of periods (.) was less than stars (*); you're misusing regex." "$FUNCNAME"
                return 1
            fi
        else # no regex, make sure find metacharacters are not mistaken for regex ones:
            if [[ "$2" == *\.\** ]]; then
                err "err in filename pattern: only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex." "$FUNCNAME"
                return 1
            fi

            if [[ "$2" == *\.* ]]; then
                report "note that period (.) in the filename pattern will be used as a literal period, not as a wildcard. provide -r flag to use regex.\n" "$FUNCNAME"
            fi
        fi
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth (the -m flag) arg value has to be a positive digit, but was \"$maxDepth\"" "$FUNCNAME"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    elif [[ -n "$follow_links" ]]; then
        maxDepthParam="-maxdepth $defMaxDeptWithFollowLinks"
    fi

    # as find doesn't support smart case, provide it yourself:
    if [[ "$(tolowercase "$1")" == "$1" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        grepcase=" -i "
    fi

    if [[ -n "$2" && "$(tolowercase "$2")" == "$2" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        INAME_ARG="-iname"
    fi

    [[ "$force_case" -eq 1 ]] && unset grepcase INAME_ARG

    ## Clean grep-only solution: (in this case the maxdepth option goes out the window)
    #if [[ -z "$2" ]]; then
        #[[ -n "$follow_links" ]] && follow_links=R || follow_links=r
        #grep -E${follow_links} --color=always -sn ${grepcase} -- "$1"

    #elif [[ "$regex" -eq 1 ]]; then
    if [[ "$regex" -eq 1 ]]; then
        # TODO: convert to  'find . -name "$ext" -type f -exec grep "$pattern" /dev/null {} +' perhaps?
        [[ -z "$2" ]] && { err "with -r flag, filename argument is required." "$FUNCNAME"; return 1; }
        [[ -n "$INAME_ARG" ]] && INAME_ARG="-regextype posix-extended -iregex" || INAME_ARG="-regextype posix-extended -regex"

        eval find $follow_links . $maxDepthParam -type f $INAME_ARG '.*'"$2"'.*' -print0 2>/dev/null | \
            xargs -0 grep -E --color=always -sn ${grepcase} -- "$1" | \
            cut -c 1-$MAX_RESULT_LINE_LENGTH | \
            more
            #less
    else
        find $follow_links . $maxDepthParam -type f "${INAME_ARG:--name}" '*'"${2:-*}"'*' -print0 2>/dev/null | \
            xargs -0 grep -E --color=always -sn ${grepcase} -- "$1" | \
            cut -c 1-$MAX_RESULT_LINE_LENGTH | \
            more
            #less
    fi
}

function memmost(){
    # $1: number of process to view (default 10).
    local num

    readonly num=${1:-10}

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 4 | head -n $num
}


function cpumost(){
    # $1: number of process to view (default 10).

    local num=$1
    [ "$num" == "" ] && num="10"

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 3 | head -n $num
}

function cpugt(){
    # $1: percentage of cpu. Default 90%

    local perc=$1
    [ "$perc" == "" ] && perc="90"

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 3 | awk -v "q=$perc" '($3>=q){print $0}'
}

function memgt(){
    # $1: percentage of memory. Default 90%

    local perc=$1
    [ "$perc" == "" ] && perc="90"

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 4 | awk -v "q=$perc" '($4>=q){print $0}'
}


function touser(){
    # $1: name of the user
    ps -U $1 -u $1 u
}

function frompid(){
    # $1: PID of the process
    ps -p $1 -o comm=
}


function topid(){
    # $1: name of the process
    ps -C $1 -o pid=
}


function astr() {
    local grepcase OPTIND usage opt filePattern fileCase caseOptCounter

    OPTIND=1
    caseOptCounter=0
    usage="\n$FUNCNAME: find string in files using ag (from current directory recursively). smartcase by default.
    Usage: $FUNCNAME [-i] [-s] \"pattern\" [filename pattern]
        -i  force case insensitive
        -s  force case sensitivity"

    check_progs_installed ag
    report "consider using ag directly; it has really sane syntax (compared to find + grep)\nfor instance, with this wrapper you can't use the filetype & path options." "$FUNCNAME"

    while getopts "ish" opt; do
        case "$opt" in
           i) grepcase=" -i "
              fileCase="i"
              caseOptCounter+=1
              shift $(( $OPTIND - 1 ))
              ;;
           s) grepcase=" -s "
              fileCase="s"
              caseOptCounter+=1
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
        err "incorrect nr of arguments." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$caseOptCounter" -gt 1 ]]; then
        err "-i and -s flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    # regex sanity:
    if [[ "$@" == *\** && "$@" != *\.\** ]]; then
        err "use .* as wildcards, not a single *" "$FUNCNAME"
        return 1
    elif [[ "$(echo "$@" | tr -dc '.' | wc -m)" -lt "$(echo "$@" | tr -dc '*' | wc -m)" ]]; then
        err "nr of periods (.) was less than stars (*); you're misusing regex." "$FUNCNAME"
        return 1
    fi

    [[ -n "$2" ]] && filePattern="-${fileCase}G $2"

    ag $filePattern $grepcase -- "$1" 2>/dev/null
}

function swap() {
    # Swap 2 files around, if they exist (from Uzi's bashrc):
    local TMPFILE file_size space_left_on_target i first_file sec_file

    TMPFILE="/tmp/${FUNCNAME}_function_tmpFile.$RANDOM"
    first_file="${1%/}" # strip trailing slash
    sec_file="${2%/}" # strip trailing slash

    count_params 2 $# equal || return 1
    [[ ! -e "$first_file" ]] && err "$first_file does not exist" "$FUNCNAME" && return 1
    [[ ! -e "$sec_file" ]] && err "$sec_file does not exist" "$FUNCNAME" && return 1
    [[ "$first_file" == "$sec_file" ]] && err "source and destination cannot be the same" "$FUNCNAME" && return 1


    # check write perimssions:
    for i in "$TMPFILE" "$first_file" "$sec_file"; do
        i="$(dirname -- "$i")"
        if [[ ! -w "$i" ]]; then
            err "$i doesn't have write permission. abort." "$FUNCNAME"
            return 1
        fi
    done

    # check if $first_file fits into /tmp:
    file_size="$(get_size "$first_file")"
    space_left_on_target="$(space_left "$TMPFILE")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname "$TMPFILE") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        return 1
    fi

    if ! mv -- "$first_file" "$TMPFILE"; then
        err "moving $first_file to $TMPFILE failed. abort." "$FUNCNAME"
        return 1
    fi

    # check if $sec_file fits into $first_file:
    file_size="$(get_size "$sec_file")"
    space_left_on_target="$(space_left "$first_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$sec_file size is ${file_size}MB, but $(dirname "$first_file") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        # undo:
        mv -- "$TMPFILE" "$first_file"
        return 1
    fi

    if ! mv -- "$sec_file" "$first_file"; then
        err "moving $sec_file to $first_file failed. abort." "$FUNCNAME"
        # undo:
        mv -- "$TMPFILE" "$first_file"
        return 1
    fi

    # check if $first_file fits into $sec_file:
    file_size="$(get_size "$TMPFILE")"
    space_left_on_target="$(space_left "$sec_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname "$sec_file") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        # undo:
        mv -- "$first_file" "$sec_file"
        mv -- "$TMPFILE" "$first_file"
        return 1
    fi

    if ! mv -- "$TMPFILE" "$sec_file"; then
        err "moving $first_file to $sec_file failed. abort." "$FUNCNAME"
        # undo:
        mv "$first_file" "$sec_file"
        mv "$TMPFILE" "$first_file"
        return 1
    fi
}

# list current directory and search for a file/dir by name:
function lgrep() {
    local SRC SRCDIR usage exact OPTIND

    usage="$FUNCNAME  [-e]  filename_to_grep  [dir_to_look_from]\n             -e  search for exact filename"

    while getopts "he" opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           e) exact=1
              shift $((OPTIND-1))
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    SRC="$1"
    SRCDIR="$2"

    # sanity:
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

    if [[ "$exact" -eq 1 ]]; then
        find "${SRCDIR:-.}" -maxdepth 1 -mindepth 1 -name "$SRC" -printf '%f\n' | grep -iE --color=auto "$SRC|$"
    else
        ls -lA "${SRCDIR:-.}" | grep --color=auto -i -- "$SRC"
        #find "${SRCDIR:-.}" -maxdepth 1 -mindepth 1 -iname '*'"$SRC"'*' -printf '%f\n' | grep -iE --color=auto "$SRC|$"
    fi
}


function histgrep() {
    local input

    readonly input="$*"

    [[ -z "$input" ]] && { err "command to look up from history required." "$FUNCNAME"; return 1; }
    history \
        | grep -v " $FUNCNAME " \
        | grep -iE --color=auto -- "$input"
}


# Make your directories and files access rights sane.
# (sane as in rw for owner, r for group, none for others)
function sanitize() {
    [[ -z "$@" ]] && { err "provide a file/dir name plz." "$FUNCNAME"; return 1; }
    [[ ! -e "$@" ]] && { err "\"$*\" does not exist." "$FUNCNAME"; return 1; }
    chmod -R u=rwX,g=rX,o= -- "$@";
}

function sanitize_ssh() {
    local dir="$@"

    [[ -z "$dir" ]] && { err "provide a file/dir name plz. (most likely you want the .ssh dir)" "$FUNCNAME"; return 1; }
    [[ ! -e "$dir" ]] && { err "\"$dir\" does not exist." "$FUNCNAME"; return 1; }
    if [[ "$dir" != *ssh*  ]]; then
        confirm  "\nthe node name you're about to $FUNCNAME does not contain string \"ssh\"; still continue? (y/n)" || return 1
    fi

    chmod -R u=rwX,g=,o= -- "$dir";
}

function ssh_sanitize() { sanitize_ssh "$@"; } # alias for sanitize_ssh

function my_ip() {  # Get internal & external ip addies:
    local connected_interface interfaces if_dir interface external_ip

    if_dir="/sys/class/net"

    function __get_internal_ip_for_if() {
        local interface ip

        interface="$1"

        ip="$(/sbin/ifconfig "$interface" | awk '/inet / { print $2 } ' | sed -e s/addr://)"
        [[ -z "$ip" && "$__REMOTE_SSH" -eq 1 ]] && return  # probaby the interface was not found
        echo -e "${ip:-"Not connected"}\t@ $interface"
    }

    connected_interface="$(find_connected_if)"  # note this returns only on own machines, not on remotes.
    external_ip="$(get_external_ip)" && {
        echo -e "external:\t${external_ip:-"Not connected to the internet."}"
    }

    command -v /sbin/ifconfig > /dev/null 2>&1 || {  # don't use check_progs_installed because of its verbosity
        err "can't check internal ip as /sbin/ifconfig appears not to be installed." "$FUNCNAME"
        return 1
    }

    if [[ -n "$connected_interface" ]]; then
        __get_internal_ip_for_if "$connected_interface"
        unset __get_internal_ip_for_if
        return 0
    elif [[ "$__REMOTE_SSH" -eq 1 ]]; then
        if [[ -d "$if_dir" && -r "$if_dir" ]]; then
            while read interface; do
                # filter out blacklisted interfaces:
                list_contains "$interface" "lo loopback" || interfaces+=" $interface "
            done < <(find "$if_dir" -maxdepth 1 -mindepth 1 -printf '%f\n')

            # old solution:
            #interfaces="$(ls "$if_dir")"
        else
            interfaces="eth0 eth1 eth2 eth3"
            report "can't read interfaces from $if_dir (not a readable dir); trying these interfaces: \"$interfaces\"" "$FUNCNAME"
        fi

        [[ -z "$interfaces" ]] && return 1

        for interface in $interfaces; do
            __get_internal_ip_for_if "$interface"
        done

        unset __get_internal_ip_for_if
        return 0
    fi

    echo "Not connected (at least nothing was returned by find_connected_if())"
    unset __get_internal_ip_for_if
}

function myip() { my_ip; } # alias for my_ip
function whatsmyip() { my_ip; } # alias for my_ip

# !! lrzip might offer best compression when it comes to text: http://unix.stackexchange.com/questions/78262/which-file-compression-software-for-linux-offers-the-highest-size-reduction
function compress() {
    local usage file type opt OPTIND
    file="$1"
    type="$2"
    usage="$FUNCNAME  fileOrDir  [zip|tar|rar|7z]\n\tif optional second arg not provided, compression type defaults to tar (tar.bz2) "

    while getopts "h" opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

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
function maketar() { tar cvzf "${1%%/}.tar.gz" -- "${1%%/}/"; }

# Creates an archive (*.tar.bz2) from given directory.
# j - use bzip2 compression rather than z option  (heavier compression)
function maketar2() { tar cvjf "${1%%/}.tar.bz2" -- "${1%%/}/"; }

# Create a rar archive.
# -m# - compresson lvl, 5 being max level, 0 just storage;
function makerar() {
    check_progs_installed rar || return 1

    rar a -r -rr10 -m4 -- "${1%%/}.rar"  "${1%%/}/"
}

# Create a ZIP archive of a file or folder.
function makezip() {
    check_progs_installed zip || return 1

    zip -r "${1%%/}.zip" -- "$1"
}

# Create a 7z archive of a file or folder.
# -mx=# - compression lvl, 9 being highest (ultra)
function make7z() {
    check_progs_installed 7z || return 1

    7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on -- "${1%%/}.7z" "$1"
}

# alias for extract
function unpack() { extract "$@"; }

# helper wrapper for uncompressing archives. it uncompresses into new directory, which
# name is the same as the archive's, minus the file extension. this avoids the situations
# where gazillion files are being extracted into workin dir. note that if the dir
# already exists, then unpacking fails (since mkdir fails).
function extract() {
    local file="$*"
    local file_without_extension="${file%.*}"
    #file_extension="${file##*.}"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz." "$FUNCNAME"
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "'$file' is not a regular file or read rights not granted." "$FUNCNAME"
        return 1
    fi

    case "$file" in
        *.tar.bz2)   file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir -- "$file_without_extension" && tar xjf "$file" -C "$file_without_extension"
                        ;;
        *.tar.gz)    file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir -- "$file_without_extension" && tar xzf "$file" -C "$file_without_extension"
                        ;;
        *.tar.xz)    file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir -- "$file_without_extension" && tar xpvf "$file" -C "$file_without_extension"
                        ;;
        *.bz2)       check_progs_installed bunzip2 || return 1
                        bunzip2 -k -- "$file"
                        ;;
        *.rar)       check_progs_installed unrar || return 1
                        mkdir -- "$file_without_extension" && unrar x "$file" "${file_without_extension}"/
                        ;;
        *.gz)        check_progs_installed gunzip || return 1
                        gunzip -kd -- "$file"
                        ;;
        *.tar)       mkdir -- "$file_without_extension" && tar xf "$file" -C "$file_without_extension"
                        ;;
        *.tbz2)      mkdir -- "$file_without_extension" && tar xjf "$file" -C "$file_without_extension"
                        ;;
        *.tgz)       mkdir -- "$file_without_extension" && tar xzf "$file" -C "$file_without_extension"
                        ;;
        *.zip)       check_progs_installed unzip || return 1
                        mkdir -- "$file_without_extension" && unzip -- "$file" -d "$file_without_extension"
                        ;;
        *.7z)        check_progs_installed 7z || return 1
                        mkdir -- "$file_without_extension" && 7z x "-o$file_without_extension" -- "$file"
                        ;;
                        # TODO .Z is unverified how and where they'd unpack:
        *.Z)         check_progs_installed uncompress || return 1
                        uncompress -- "$file"  ;;
        *)           err "'$file' cannot be extracted; this filetype is not supported." "$FUNCNAME"
                        return 1
                        ;;
    esac

    # at the moment this reporting could be erroneous if mkdir fails:
    #echo -e "extracted $file contents into $file_without_extension"
}

# to check included fonts: xlsfonts | grep fontname
# list all installed fonts: fclist
fontreset() {
    local dir

    xset +fp ~/.fonts
    mkfontscale ~/.fonts
    mkfontdir ~/.fonts
    #xset fp rehash

    pushd ~/.fonts
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
  limit=$1
  for ((i=1 ; i <= limit ; i++)); do
      d="$d/.."
  done
  d="$(echo "$d" | sed 's/^\///')"
  [[ -z "$d" ]] && d=".."

  cd -- "$d"
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
    local file

    [[ -z "$@" ]] && { echo -e "usage:   $FUNCNAME  <filename>"; return 1; }
    for file in "$@"; do
        [[ -f "$file" && -r "$file" ]] || { err "provided file \"$file\" is not a regular file or is not readable. abort." "$FUNCNAME"; return 1; }
    done

    check_progs_installed xmllint "$EDITOR" || return 1;
    xmllint --format "$@" | "$EDITOR"  "+set foldlevel=99" -;
}

function xmlf() { xmlformat "$@"; } # alias for xmlformat;

function createUsbIso() {
    local file device mountpoint cleaned_devicename usage override_dev_partitioncheck OPTIND partition

    readonly usage="${FUNCNAME}: burn images to usb.
    Usage:   $FUNCNAME  [options]  image.file  device
        -o  allow selecting devices whose name ends with a digit (note that you
            should be selecting a whole device instead of its parition (ie sda vs sda1),
            but some devices have weird names (eg sd cards)

    example: $FUNCNAME  file.iso  /dev/sdh"

    check_progs_installed   dd lsblk umount sudo || return 1

    while getopts "ho" opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           o) override_dev_partitioncheck=1
              shift $((OPTIND-1))
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    readonly file="$1"
    readonly device="${2%/}" # strip trailing slash

    readonly cleaned_devicename="${device##*/}"  # strip everything before last slash (slash included)

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
    elif ! ls /dev | grep -q -- "\b${cleaned_devicename}\b" > /dev/null 2>&1 ;then
        err "$cleaned_devicename does not exist in /dev" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$override_dev_partitioncheck" -ne 1 ]] && [[ "$cleaned_devicename" =~ .*[0-9]+$ ]]; then
        # as per arch wiki
        err "please don't provide partition, but a drive, e.g. /dev/sdh instad of /dev/sdh1" "$FUNCNAME"
        report "note you can override this check with the -o flag." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$override_dev_partitioncheck" -eq 1 ]] && [[ "$cleaned_devicename" =~ .*[0-9]+$ ]]; then
        report "you've selected to override partition check (ie making sure you select device, not its partition.)" "$FUNCNAME"
        confirm "you're sure that $cleaned_devicename is the device you wish to check?" "$FUNCNAME" || return 1
    fi

    #echo "please provide passwd for running fdisk -l to confirm the selected device is the right one:"
    #sudo fdisk -l $device
    lsblk | grep --color=auto -- "$cleaned_devicename\|MOUNTPOINT"

    confirm  "\nis selected device - $device - the correct one (be VERY sure!)? (y/n)" || return 1

    # find if device is mounted:
    #lsblk -o name,size,mountpoint /dev/sda
    report "unmounting $cleaned_devicename partitions... (may ask for sudo password)"
    for partition in ${device}* ; do
        mountpoint="$(lsblk -o mountpoint -- "$partition")" || { err "some issue occurred running lsblk -o mountpoint $partition" "$FUNCNAME"; return 1; }
        mountpoint="$(echo "$mountpoint" | sed -n 2p)"
        if [[ -n "$mountpoint" ]]; then
            report "$partition appears to be mounted at $mountpoint, trying to unmount..." "$FUNCNAME"
            if ! sudo umount "$mountpoint"; then
                err "something went wrong with unmounting ${mountpoint}. please unmount the device and try again." "$FUNCNAME"
                return 1
            fi
            report "...success." "$FUNCNAME"
        fi
    done

    report "Please provide sudo passwd for running dd:" "$FUNCNAME"
    sudo echo "..."
    clear
    report "Running dd, this might take a while..." "$FUNCNAME"
    sudo dd if="$file" of="$device" bs=4M
    sync
    #eject $device
}

#######################
## Setup github repo ##
#######################
function mkgit() {
    local user repo dir gitname OPTIND opt
    local usage="usage:   $FUNCNAME  -g|-b  <dirname> [reponame]"
    local mainOptCounter=0

    while getopts "hgb" opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           g) user="laur89"
              repo="github.com"
              let mainOptCounter+=1
              shift $((OPTIND-1))
              ;;
           b) user="layr"
              repo="bitbucket.org"
              let mainOptCounter+=1
              shift $((OPTIND-1))
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    dir="$1"
    gitname="$2"

    if [[ "$mainOptCounter" -gt 1 ]]; then
        err "-g and -b flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$mainOptCounter" -eq 0 ]]; then
        err "need to select a repo." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$#" -gt 2 ]]; then
        err "too many arguments" "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif ! check_progs_installed git; then
        return 1
    fi

    # check dir
    [[ -z "$dir" ]] && {
       err "$usage" "$FUNCNAME"
       return 1
    }

    # use dir name if, no gitname specified
    [[ -n "$gitname" ]] || gitname="$dir"
    [[ -d "$dir"     ]] || mkdir -- "$dir"

    [[ -w "$dir" ]] || {
       err "we were unable to create dir $dir, or it simply doesn't have write permissions." "$FUNCNAME"
       return 1
    }

    # bail out, if already git repo
    [[ -d "$dir/.git" ]] && {
       err "already a git repo: $dir" "$FUNCNAME"
       return 1
    }

    # TODO: remote repo needs to be first created via REST:
    #curl --user $username:$password https://api.bitbucket.org/1.0/repositories/ --data name=$reponame --data is_private='true'
    #git remote add origin git@bitbucket.org:$username/$reponame.git
    #git push -u origin --all
    #git push -u origin --tags

    cd -- "$dir"
    git init || { err "bad return from git init" "$FUNCNAME"; return 1; }
    touch README; git add README
    git commit -a -m 'inital setup - automated'
    git remote add origin "git@$repo:$user/${gitname}.git"
    git push -u origin master
}

######################################
## Open file inside git tree on vim ##
######################################
gito() {
    local DMENU match matches git_root count cwd dmenurc editor nr_of_dmenu_vertical_lines i

    cwd="$PWD"
    dmenurc="$HOME/.dmenurc"
    editor="$EDITOR"
    nr_of_dmenu_vertical_lines=20

    if [[ "$__REMOTE_SSH" -ne 1 ]]; then
        check_progs_installed git "$editor" dmenu || return 1
    fi

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    git_root="$(git rev-parse --show-toplevel)"
    [[ "$cwd" != "$git_root" ]] && pushd "$git_root" &> /dev/null  # git root

    if [[ -n "$@" ]]; then
        if [[ "$@" == *\** && "$@" != *\.\** ]]; then
            err 'use .* as wildcards, not a single *' "$FUNCNAME"
            [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back
            return 1
        elif [[ "$(echo "$@" | tr -dc '.' | wc -m)" -lt "$(echo "$@" | tr -dc '*' | wc -m)" ]]; then
            err "nr of periods (.) was less than stars (*); you're misusing regex." "$FUNCNAME"
            [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back
            return 1
        fi

        matches="$(git ls-files | grep -Ei -- "$@")"
    else
        matches="$(git ls-files)"
    fi

    [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back

    count="$(echo "$matches" | wc -l)"
    match=("$matches")

    if [[ "$count" -gt 1 ]]; then
        report "found $count items" "$FUNCNAME"
        match=()

        if [[ "$__REMOTE_SSH" -eq 1 ]]; then  # TODO: check for $DISPLAY as well perhaps?
            if [[ "$count" -gt 200 ]]; then
                report "no way of using dmenu over ssh; these are the found files:\n" "$FUNCNAME"
                echo -e "$matches"
                return 0
            fi

            while read i; do
                match+=( "$i" )
            done < <(echo "$matches")

            select_items --single "${match[@]}"
            match=("${__SELECTED_ITEMS[@]}")
        else
            while read i; do
                match+=( "$i" )
            done < <(echo "$matches" | $DMENU -l $nr_of_dmenu_vertical_lines -p open)
        fi
    fi

    #[[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | bemenu -i -l 20 -p "$editor")"
    [[ -z "${match[*]}" ]] && return 1
    match="$git_root/${match[0]}"  # convert to absolute
    [[ -f "$match" ]] || { err "\"$match\" is not a regular file." "$FUNCNAME"; return 1; }

    $editor -- "$match"
}

# ag looks for whole file path!
ago() {
    err "ag is not playing along at the moment. see fo()" "$FUNCNAME"
    return 1


    local DMENU match
    local dmenurc="$HOME/.dmenurc"
    local editor="$EDITOR"

    check_progs_installed ag "$editor" dmenu || return 1
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    [[ -z "$@" ]] && { err "args required."; return 1; }

    match="$(ag -g "$@")"
    [[ "$?" -eq 0 ]] || return 1

    [[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | $DMENU -l 20 -p open)"
    [[ -z "$match" ]] && return 1

    [[ -f "$match" ]] || { err "\"$match\" is not a regular file." "$FUNCNAME"; return 1; }
    $editor "$match"
}

# same as fo(), but opens all the found results; forces regular filetype search.
#
# mnemonic: file open all
foa() {
    local opts default_depth

    opts="$1"

    readonly default_depth="m10"

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"  # depth opt has to come last
        #echo $opts  # debug

        shift
    else
        opts="-f${default_depth}"
    fi

    fo --openall $opts "$@"
}


# finds files/dirs using fo() and goes to containing dir (or same dir if found item is already a dir)
#
# mnemonic: file open go
fog() {
    local opts default_depth

    opts="$1"

    readonly default_depth="m10"

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-$default_depth"
    fi

    fo --goto $opts "$@"
}

# mnemonic: go go
gg() {
    fog "$@"
}


# open newest file (as in with last mtime);
# if no args provided, then searches for '*';
# if no depth arg provided, then defaults to current dir only.
#
# mnemonic: file open new(est)
fon() {
    local opts default_depth

    opts="$1"

    readonly default_depth="m1"

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-f${default_depth}"
    fi

    [[ -z "$@" ]] && set -- '*'
    fo --newest $opts "$@"

    #local matches file

    #matches="$(find -L . -mindepth 1 -maxdepth 1 -type f -printf "%T+\t%p\n" | sort -r)"
    #matches=("$matches")

    #[[ -z "${matches[*]}" ]] && return 1

    #file="${matches[0]}"
    #report "opening ${file}..."
    #xo "$file"
}


# finds files/dirs using ffind() (find wrapper) and opens them.
# accepts different 'special modes' to be defined as first arg (modes defined in $special_modes array).
#
# if NOT in special mode, and no args provided, then default to opening regular files in current dir.
#
# mnemonic: file open
fo() {
    local DMENU matches match count filetype dmenurc editor image_viewer video_player file_mngr
    local pdf_viewer nr_of_dmenu_vertical_lines special_mode special_modes single_selection i j
    local last_mtime_to_file

    dmenurc="$HOME/.dmenurc"
    nr_of_dmenu_vertical_lines=20
    readonly special_modes="--goto --openall --newest"  # special mode definitions; mode basically decides how to deal with the found match(es)
    editor="$EDITOR"
    image_viewer="sxiv"
    video_player="smplayer"
    file_mngr="ranger"
    pdf_viewer="zathura"

    list_contains "$1" "$special_modes" && { special_mode="$1"; shift; }
    [[ -z "$@" && -z "$special_mode" ]] && set -- '-fm1' '*'
    [[ -z "$@" ]] && { err "args required for ffind. see ffind -h" "$FUNCNAME"; return 1; }
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    if [[ "$__REMOTE_SSH" -ne 1 && -z "$special_mode" ]]; then  # only check for progs if not ssh-d AND not using in "special mode"
        check_progs_installed find ffind "$PAGER" "$file_mngr" "$editor" "$image_viewer" \
                "$video_player" "$pdf_viewer" dmenu file || return 1
    fi

    # filesearch begins:
    matches="$(ffind --_skip_msgs "$@")" || return 1
    count="$(echo "$matches" | wc -l)"
    match=("$matches")  # define the default match array in case only single node was found;

    # logic to select wanted nodes from multiple matches:
    if [[ "$count" -gt 1 ]] && ! list_contains "$special_mode" "--openall --newest"; then
        report "found $count items" "$FUNCNAME"
        match=()

        if [[ "$__REMOTE_SSH" -eq 1 ]]; then  # TODO: check for $DISPLAY as well perhaps?
            if [[ "$count" -gt 200 ]]; then
                report "no way of using dmenu over ssh; these are the found files:\n" "$FUNCNAME"
                echo -e "$matches"
                return 0
            fi

            [[ "$special_mode" == --goto ]] && single_selection="--single"

            while read i; do
                match+=( "$i" )
            done < <(echo "$matches")

            select_items $single_selection "${match[@]}"
            match=("${__SELECTED_ITEMS[@]}")
        else
            while read i; do
                match+=( "$i" )
            done < <(echo "$matches" | $DMENU -l $nr_of_dmenu_vertical_lines -p open)
        fi

        [[ -z "${match[*]}" ]] && return 1
    fi
    # /filesearch

    # handle special modes, if any:
    if [[ -n "$special_mode" ]]; then
        case $special_mode in
            --goto)
                goto "${match[@]}"  # note that for --goto only one item should be allowed to select

                return
                ;;
            --openall)
                match=()

                while read i; do
                    match+=( "$i" )
                done < <(echo "$matches")

                "$editor" "${match[@]}"

                return
                ;;
            --newest)
                check_progs_installed stat head || return 1
                match=0
                declare -A last_mtime_to_file

                while read i; do
                    j=$(stat --format=%Y -- "$i") || { err "problems running \$stat for \"$i\"." "$FUNCNAME"; continue; }
                    last_mtime_to_file[$j]="$i"
                    # bash-based sorting:
                    [[ "$j" -gt "$match" ]] && match="$j"

                    #match+="${j}\n"  # TODO: we're screwed if filename contains newlines
                done < <(echo "$matches")

                #match="$(stat --format=%Y -- "${match[@]}" | sort -r | head --lines=1)"
                #match="$(echo -e "$match" | sort -r | head --lines=1)"  # finds the newest mtime
                match="${last_mtime_to_file[$match]}"
                [[ -f "$match" ]] || { err "something went wrong, found newest file \"$match\" is not a valid file."; return 1; }

                #report "opening \"${match}\"..." "$FUNCNAME"
                #if [[ "$__REMOTE_SSH" -eq 1 ]]; then
                    #"$editor" -- "$match"
                #else
                    #xdg-open "$match"  # xdg-open doesn't support -- !!!
                #fi

                match=("$match")
                # fall through, do not return!
                ;;
            #*) no need, as mode has already been verified
        esac
    fi


    count="${#match[@]}"
    # define filetype only by the first node:
    filetype="$(file -iLb -- "${match[0]}")" || { err "issues testing \"${match[0]}\" with \$file"; return 1; }

    report "opening \"${match[*]}\"" "$FUNCNAME"

    case "$filetype" in
        image/*)
            "$image_viewer" -- "${match[@]}"
            ;;
        application/octet-stream*)
            # should be the logs on app servers
            "$PAGER" -- "${match[@]}"
            ;;
        application/xml*)
            [[ "$count" -gt 1 ]] && { report "won't format multiple xml files! will just open them"; sleep 1.5; }
            if [[ "$(wc -l < "${match[0]}")" -gt 2 || "$count" -gt 1 ]]; then  # note if more than 2 lines we also assume it's already formatted;
                # assuming it's already formatted:
                "$editor" -- "${match[@]}"
            else
                xmlformat "${match[@]}"
            fi
            ;;
        video/* | audio/mp4*)
            #"$video_player" -- "${match[@]}"  # TODO: smplayer doesn't support '--' as per now
            "$video_player" "${match[@]}"
            ;;
        text/*)
            "$editor" -- "${match[@]}"
            ;;
        application/pdf*)
            "$pdf_viewer" -- "${match[@]}"
            ;;
        application/x-elc*)  # TODO: what exactly is it?
            "$editor" -- "${match[@]}"
            ;;
        'application/x-executable; charset=binary'*)
            [[ "$count" -gt 1 ]] && { report "won't execute multiple files! select one please"; return 1; }
            confirm "${match[*]} is executable. want to launch it from here?" || return
            report "launching ${match[0]}..." "$FUNCNAME"
            ${match[0]}
            ;;
        'inode/directory;'*)
            [[ "$count" -gt 1 ]] && { report "won't navigate to multiple dirs! select one please"; return 1; }
            "$file_mngr" -- "${match[0]}"
            ;;
        'inode/x-empty; charset=binary')  # touched file
            "$editor" -- "${match[@]}"
            ;;
        *)
            err "dunno what to open this type of file with:\n\t$filetype" "$FUNCNAME"
            return 1
            ;;
    esac



    ## TODO: old, safer verions where only one file was opened at a time:
    ##
    ## note that test will resolve links to files and dirs as well;
    ## TODO: instead of file, use xdg-open?
    #if [[ -f "$match" ]]; then
        #filetype="$(file -iLb -- "$match")" || { err "issues testing \"$match\" with \$file"; return 1; }

        #case "$filetype" in
            #image/*)
                #"$image_viewer" "$match"
                #;;
            #application/octet-stream*)
                ## should be the logs on server
                #"$PAGER" "$match"
                #;;
            #application/xml*)
                #if [[ "$(wc -l < "$match")" -gt 2 ]]; then
                    ## assuming it's already formatted:
                    #"$editor" "$match"
                #else
                    #xmlformat "$match"
                #fi
                #;;
            #video/*)
                #"$video_player" "$match"
                #;;
            #text/*)
                #"$editor" "$match"
                #;;
            #application/pdf*)
                #"$pdf_viewer" "$match"
                #;;
            #application/x-elc*) # TODO: what is it exactly?
                #"$editor" "$match"
                #;;
            #'application/x-executable; charset=binary'*)
                #confirm "$match is executable. want to launch it from here?" || return
                #report "launching ${match}..." "$FUNCNAME"
                #"$match"
                #;;
            ##'inode/directory;'*)
                ##"$file_mngr" "$match"
            #*)
                #err "dunno what to open this type of file with:\n\t$filetype" "$FUNCNAME"
                #return 1
                #;;
        #esac
    #elif [[ -d "$match" ]]; then
        #"$file_mngr" "$match"
    #else
        #err "\"$match\" isn't either regular file nor a dir." "$FUNCNAME"
        #return 1
    #fi
}

function sethometime() { setestoniatime; }  # home is where you make it;

function setromaniatime() {
    __settz Europe/Bucharest
}

function setestoniatime() {
    __settz Europe/Tallinn
}

function setgibtime() {
    __settz Europe/Gibraltar
}

function setspaintime() {
    __settz Europe/Madrid
}

function __settz() {
    local tz

    tz="$*"

    check_progs_installed timedatectl || return 1
    [[ -z "$tz" ]] && { err "provide a timezone to switch to (e.g. Europe/Madrid)." "$FUNCNAME"; return 1; }
    [[ "$tz" != */* ]] && { err "invalid timezone format; has to be in a format like \"Europe/Madrid\"." "$FUNCNAME"; return 1; }

    timedatectl set-timezone "$tz"
    return $?
}

function killmenao() {
    confirm "you sure?" || return
    clear
    report 'you ded.' "$FUNCNAME"
    :(){ :|:& };:
}

########################
## Print window class ##
########################
xclass() {
    xprop | awk '
    /^WM_CLASS/{sub(/.* =/, "instance:"); sub(/,/, "\nclass:"); print}
    /^WM_NAME/{sub(/.* =/, "title:"); print}'
}

################
## Smarter CD ##
################
goto() {
    [[ -z "$@" ]] && { err "node operand required" "$FUNCNAME"; return 1; }
    [[ -d "$@" ]] && { cd -- "$@"; } || cd -- "$(dirname -- "$@")";
}

# cd-s to directory by partial match; if multiple matches, opens input via dmenu. smartcase.
#  g /data/partialmatch     # searches for partialmatch in /data
#  g partialmatch           # searches for partialmatch in current dir
#  g                        # if no input, then searches all directories in current dir
#
# see also gg()
g() {
    local path input file match matches pattern DMENU dmenurc msg_loc INAME_ARG nr_of_dmenu_vertical_lines count i

    input="$*"
    dmenurc="$HOME/.dmenurc"
    nr_of_dmenu_vertical_lines=20

    [[ -d "$input" ]] && { cd -- "$input"; return; }
    [[ -z "$input" ]] && input='*'
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    #[[ "$input" == */* ]] && path="${input%%/*}"  # strip everything after last slash(included)
    path="$(dirname -- "$input")"
    [[ -d "$path" ]] || { err "something went wrong - dirname result \"$path\" is not a dir." "$FUNCNAME"; return 1; }
    pattern="${input##*/}"  # strip everything before last slash (included)
    [[ -z "$pattern" ]] && { err "no search pattern provided" "$FUNCNAME"; return 1; }
    [[ "$path" == '.' ]] && msg_loc="here" || msg_loc="$path/"

    [[ "$(tolowercase "$pattern")" == "$pattern" ]] && INAME_ARG="iname"

    matches="$(find -L "$path" -maxdepth 1 -mindepth 1 -type d -${INAME_ARG:-name} '*'"$pattern"'*')"
    count="$(echo "$matches" | wc -l)"
    match=("$matches")

    if [[ -z "$matches" ]]; then
        err "no dirs in $msg_loc matching \"$pattern\"" "$FUNCNAME"
        return 1
    elif [[ "$count" -gt 1 ]]; then
        match=()

        if [[ "$__REMOTE_SSH" -eq 1 ]]; then  # TODO: check for $DISPLAY as well perhaps?
            if [[ "$count" -gt 200 ]]; then
                report "no way of using dmenu over ssh; these are the found dirs:\n" "$FUNCNAME"
                echo -e "$matches"
                return 0
            fi

            while read i; do
                match+=( "$i" )
            done < <(echo "$matches")

            select_items --single "${match[@]}"
            match=("${__SELECTED_ITEMS[@]}")
        else
            while read i; do
                match+=( "$i" )
            done < <(echo "$matches" | $DMENU -l $nr_of_dmenu_vertical_lines -p cd)
        fi
    fi

    [[ -z "${match[*]}" ]] && return 1
    [[ -d "${match[0]}" ]] || { err "no such dir like \"${match[0]}\" in $msg_loc" "$FUNCNAME"; return 1; }

    cd -- "${match[0]}"
}


# display available APs and their basic info
function wifi_list() {
    nmcli device wifi list
}


function keepsudo() {
    while true; do
        sudo -n true
        sleep 30
        kill -0 "$$" || exit
    done 2>/dev/null &
}


####################
## Copy && Follow ##
####################
cpf() {
    [[ -z "$@" ]] && { err "arguments for the cp command required." "$FUNCNAME"; return 1; }
    cp -- "$@" && goto "$_";
}

####################
## Move && Follow ##
####################
mvf() {
    [[ -z "$@" ]] && { err "name of a node to be moved required." "$FUNCNAME"; return 1; }
    mv -- "$@" && goto "$_";
}

########################
## Make dir && Follow ##
########################
function mkcd() {
    [[ -z "$@" ]] && { err "name of a directory to be created required." "$FUNCNAME"; return 1; }
    mkdir -p -- "$@" && cd -- "$@"
}


function mkf() { mkcd "$@"; } # alias to mkcd

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
# also consider running  vokoscreen  instead.
capture() {
    local name screen_dimensions regex

    name="$1"

    check_progs_installed ffmpeg xdpyinfo || return 1
    [[ -z "$name" ]] && { err "need to provide output file as first arg (without an extension)." "$FUNCNAME"; return 1; } || name="/tmp/${name}.mkv"
    [[ "$-" != *i* ]] && return 1  # don't launch if we're not in interactive shell;

    readonly regex='^[0-9]+x[0-9]+$'
    readonly screen_dimensions="$(xdpyinfo | awk '/dimensions:/{printf $2}')" || { err "unable to find screen dimensions via xdpyinfo" "$FUNCNAME"; return 1; }
    [[ "$screen_dimensions" =~ $regex ]] || { err "found screen dimensions \"$screen_dimensions\" do not conform with validation regex \"$regex\"" "$FUNCNAME"; return 1; }

    #recordmydesktop --display=$DISPLAY --width=1024 height=768 -x=1680 -y=0 --fps=15 --no-sound --delay=10
    #recordmydesktop --display=0 --width=1920 height=1080 --fps=15 --no-sound --delay=10
    ffmpeg -f alsa -ac 2 -i default -framerate 25 -f x11grab -s "$screen_dimensions" -i "$DISPLAY" -acodec pcm_s16le -vcodec libx264 "${name}"
    echo
    report "screencap saved at $name" "$FUNCNAME"

    ## lossless recording (from https://wiki.archlinux.org/index.php/FFmpeg#x264_lossless):
    #ffmpeg -i "$DISPLAY" -c:v libx264 -preset ultrafast -qp 0 -c:a copy "${name}.mkv"
    ## also lossless, but smaller output file:
    #ffmpeg -i "$DISPLAY" -c:v libx264 -preset veryslow -qp 0 -c:a copy "${name}.mkv"
}

# takes an input file and outputs mkv container for youtube:
# stolen from https://wiki.archlinux.org/index.php/FFmpeg#YouTube
ytconvert() {
    [[ "$#" -ne 2 ]] && { err "exactly 2 args required - input file to convert, and output filename (without extension)." "$FUNCNAME"; return 1; }
    [[ -f "$1" ]] || { err "need to provide an input file as first argument." "$FUNCNAME"; return 1; }
    ffmpeg -i "$1" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a copy "$2.mkv"
}

##############################################
## Colored Find                             ##
## NOTE: Searches current tree recrusively. ##
##############################################
f() {
    find . -iregex ".*$*.*" -printf '%P\0' | xargs -r0 ls --color=auto -1d
}

##############################################
# marks (jumps)                             ##
# from: http://jeroenjanssens.com/2013/08/16/quickly-navigate-your-filesystem-from-the-command-line.html
##############################################
_MARKPATH_DIR=.shell_jump_marks

unset _MARKPATH  # otherwise we'll use the regular user defined _MARKPATH who changed into su
if [[ "$EUID" -eq 0 ]]; then
    _MARKPATH="$(find /home -mindepth 2 -maxdepth 2 -type d -name $_MARKPATH_DIR -print0 -quit)"
fi

export _MARKPATH="${_MARKPATH:-$HOME/$_MARKPATH_DIR}"
unset _MARKPATH_DIR

function jj {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in $_MARKPATH" "$FUNCNAME"; return 1; }
    cd -P "$_MARKPATH/$1" 2>/dev/null || err "no such mark: $1" "$FUNCNAME"
}

# pass '-o' as first arg to force overwrite existing target link
function jm {
    local overwrite target

    [[ "$1" == "-o" || "$1" == "--overwrite" ]] && { readonly overwrite=1; shift; }

    [[ $# -ne 1 || -z "$1" ]] && { err "exactly one arg accepted" "$FUNCNAME"; return 1; }
    [[ -z "$_MARKPATH" ]] && { err "\$_MARKPATH not set, aborting." "$FUNCNAME"; return 1; }
    mkdir -p "$_MARKPATH"
    readonly target="$_MARKPATH/$1"
    [[ "$overwrite" -eq 1 && -h "$target" ]] && rm "$target" >/dev/null 2>/dev/null
    [[ -h "$target" ]] && { err "$target already exists; use jmo or $FUNCNAME -o to overwrite." "$FUNCNAME"; return 1; }

    ln -s "$(pwd)" "$target" || return 1
}

# mnemonic: jm overwrite
function jmo {
    jm -o "$@"
}

function jum {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in $_MARKPATH" "$FUNCNAME"; return 1; }
    rm -i "$_MARKPATH/$1"
}

function jjj {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in $_MARKPATH" "$FUNCNAME"; return 1; }
    ls -l "$_MARKPATH" | sed 's/  / /g' | cut -d' ' -f9- | sed 's/ -/\t-/g' && echo
}

# marks/jumps completion:
_completemarks() {
    local curw wordlist

    curw=${COMP_WORDS[COMP_CWORD]}
    wordlist=$(find "$_MARKPATH" -type l -printf "%f\n")
    COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
    return 0
}
complete -F _completemarks jj jum jmo

################################################

# marker function used to detect whether functions have been loaded into the shell:
function __BASH_FUNS_LOADED_MARKER() { true; }

