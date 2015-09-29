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
# TODO: set default max depth? should be at least when -L is selected;
function ffind() {
    local SRC SRCDIR INAME_ARG opt usage OPTIND file_type filetypeOptionCounter exact binary follow_links maxDepth maxDepthParam pathOpt regex defMaxDeptWithFollowLinks force_case caseOptCounter

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
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;
        -e  search for exact filename, not for a partial (you still can use * wildcards)
        -p  expand the pattern search for path as well (adds the -path option)"

    filetypeOptionCounter=0
    caseOptCounter=0

    while getopts "m:isrefdlbLph" opt; do
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


    if [[ "$follow_links" == "-L" && "$file_type" == "-type l" ]]; then
        report "if both -l and -L flags are set, then ONLY the broken links are being searched.\n" "$FUNCNAME"
    fi

    # as find doesn't support smart case, provide it yourself:
    if [[ "$(tolowercase "$SRC")" == "$SRC" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        INAME_ARG="-iname"
    fi

    [[ "$force_case" -eq 1 ]] && INAME_ARG=""


    if [[ "$pathOpt" -eq 1 && "$exact" -eq 1 ]]; then
        report "note that using -p and -e flags together means that the pattern has to match whole path, not only the filename!" "$FUNCNAME"
    fi

    if [[ -n "$SRCDIR" ]]; then
        if [[ ! -d "$SRCDIR" ]]; then
            err "provided directory to search from (\"$SRCDIR\") is not a directory. abort." "$FUNCNAME"
            return 1
        elif [[ "${SRCDIR:$(( ${#SRCDIR} - 1)):1}" != "/" ]]; then
            SRCDIR="${SRCDIR}/" # add trailing slash if missing; required for gnu find; is it really the case??
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
    else # no regex, make sure find metacharacters are not mistaken for regex ones:
        if [[ "$SRC" == *\.\** ]]; then
            err "only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex." "$FUNCNAME"
            return 1
        fi

        if [[ "$SRC" == *\.* ]]; then
            report "note that period (.) will be used as a literal period, not as a wildcard. provide -r flag to use regex.\n" "$FUNCNAME"
        fi
    fi


    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth (the -m flag) arg value has to be a digit, but was \"$maxDepth\"" "$FUNCNAME"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
    elif [[ -n "$follow_links" ]]; then
        maxDepthParam="-maxdepth $defMaxDeptWithFollowLinks"
    fi

    if [[ "$pathOpt" -eq 1 ]]; then
        [[ -n "$INAME_ARG" ]] && INAME_ARG="-iwholename" || INAME_ARG="-path" # as per man page, -ipath is deprecated
    elif [[ "$regex" -eq 1 ]]; then
        [[ -n "$INAME_ARG" ]] && INAME_ARG="-regextype posix-extended -iregex" || INAME_ARG="-regextype posix-extended -regex"
    fi

    # grep is for coloring only:
    #find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' | grep -i --color=auto "$SRC" 2>/dev/null
    if [[ "$exact" -eq 1 ]]; then # no regex with exact; they are excluded.
        if [[ "$binary" -eq 1 ]]; then
            find $follow_links "${SRCDIR:-.}" $maxDepthParam -type f "${INAME_ARG:--name}" "$SRC" -executable -exec sh -c "file -ib '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null | grep -iE --color=auto "$SRC|$"
        else
            find $follow_links "${SRCDIR:-.}" $maxDepthParam $file_type "${INAME_ARG:--name}" "$SRC" 2>/dev/null | grep -iE --color=auto "$SRC|$"
        fi
    else # partial filename match, ie add * padding
        if [[ "$regex" -eq 1 ]]; then  #regex, need to change the * padding around $SRC
            #
            # TODO eval!
            #
            if [[ "$binary" -eq 1 ]]; then
                # TODO: this doesnt work atm:
                err "binary search in regex currently unimplemented" "$FUNCNAME"
                return
                # this doesn't work atm:
                eval find $follow_links "${SRCDIR:-.}" $maxDepthParam -type f "${INAME_ARG:--name}" '.*'"$SRC"'.*' -executable -exec sh -c "file -ib '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null | grep -iE --color=auto "$SRC|$"
            else
                eval find $follow_links "${SRCDIR:-.}" $maxDepthParam $file_type "${INAME_ARG:--name}" '.*'"$SRC"'.*' 2>/dev/null | grep -iE --color=auto "$SRC|$"
            fi
        else # no regex
            if [[ "$binary" -eq 1 ]]; then
                find $follow_links "${SRCDIR:-.}" $maxDepthParam -type f "${INAME_ARG:--name}" '*'"$SRC"'*' -executable -exec sh -c "file -ib '{}' | grep -q 'x-executable; charset=binary'" \; -print 2>/dev/null | grep -iE --color=auto "$SRC|$"
            else
                find $follow_links "${SRCDIR:-.}" $maxDepthParam $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' 2>/dev/null | grep -iE --color=auto "$SRC|$"
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
    ps -ef | grep -v '\bgrep\b' | grep -i --color=auto "$1"

    # TODO: add also exact match option?:
    #   grep '\$1\b'
}

# find top 5/x biggest or smallest nodes:
function __find_top_big_small_fun() {
    local usage opt OPTIND itemsToShow file_type item compiledFileTypeArgs maxDepthParam maxDepth follow_links reverse du_size_unit FUNCNAME_
    local bigOrSmall du_include_regular_files filesize_print_unit ignore_filesize_print_unit_msg duMaxDepthParam filetypeOptionCounter

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
           #f) file_type="$file_type f"
           #f) file_type="-type f"
              #filetypeOptionCounter+=1
              #shift $((OPTIND-1))
                #;;
           ##d) file_type="$file_type d"
           #d) file_type="-type d"
              #filetypeOptionCounter+=1
              ## we don't want to sed maxdepth param here by default, right?
              ##maxDepthParam="-maxdepth 1"
              #shift $((OPTIND-1))
                #;;
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

    #if [[ -z "$file_type" ]]; then
        #compiledFileTypeArgs="-type f"
    #else
        #for item in $file_type; do
            #[[ -z "$compiledFileTypeArgs" ]] && compiledFileTypeArgs="-type $item" \
                                             #|| compiledFileTypeArgs="$compiledFileTypeArgs -o -type $item"
        #done
    #fi

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
        itemsToShow=10 # default
    fi

    if [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f and -d flags are exclusive." "$FUNCNAME_"
        echo -e "$usage"
        return 1
    fi

    # TODO: malaga start

    report "seeking for top $itemsToShow $bigOrSmall files (in $du_size_unit units) ..." "$FUNCNAME_"

    if [[ "$file_type" == "-type f" ]]; then
        # optimization for files-only logic (ie no directories) to avoid expensive
        # calls to other programs (like awk and du).

        filesize_print_unit="k" # find's printf unit for the filesize; note that this is used merely for the printing not for seeking for the files;

        if ! [[ "$du_size_unit" =~ ^[KMGB]+$ ]]; then
            err "unsupported block size unit for find: \"$du_size_unit\"" "$FUNCNAME_"
            echo -e "$usage"
            return 1

        # convert some of the du types to the find equivalents:
        elif [[ "$du_size_unit" == B ]]; then
            filesize_print_unit="s"
            ignore_filesize_print_unit_msg=1
        elif [[ "$du_size_unit" == K ]]; then
            ignore_filesize_print_unit_msg=1
        fi

        [[ "$ignore_filesize_print_unit_msg" -ne 1 ]] && report "note that printed file size is in 1k units (limitation of find's -printf)\n" "$FUNCNAME_"

        # find's printf:
        # %s file size in byte   - appears to be the same as du block-size w/o any units
        # %k in 1K blocks
        # %b in 512byte blocks
        find $follow_links . -mindepth 1 $maxDepthParam $file_type -printf "%${filesize_print_unit}\t%P\n" 2>/dev/null | \
            sort -n $reverse | \
            head -$itemsToShow

    else  # covers both dirs only & dirs+files cases:
        if [[ "$du_size_unit" == B ]]; then
            du_size_unit="--bytes"
        else
            du_size_unit="--block-size=${du_size_unit}"
        fi

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
    __find_top_big_small_fun "-r" "M" "$FUNCNAME" "large" $@
}

function ffindtopsmall() {
    #find . -type f -exec ls -s --block-size=K {} \; | sort -n | head -$itemsToShow 2>/dev/null
    __find_top_big_small_fun "" "K" "$FUNCNAME" "small" $@
}

# find smaller/bigger than Xmegas files
function __find_bigger_smaller_common_fun() {
    local usage opt OPTIND file_type item compiledFileTypeArgs maxDepthParam maxDepth follow_links reverse du_size_unit FUNCNAME_ biggerOrSmaller sizeArg
    local du_include_regular_files filesize_print_unit ignore_filesize_print_unit_msg duMaxDepthParam plusOrMinus filetypeOptionCounter sizeArgLastChar du_blk_sz

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
           #f) file_type="$file_type f"
           #f) file_type="-type f"
              #filetypeOptionCounter+=1
              #shift $((OPTIND-1))
                #;;
           ##d) file_type="$file_type d"
           #d) file_type="-type d"
              #filetypeOptionCounter+=1
              ## we don't want to sed maxdepth param here by default, right?
              ##maxDepthParam="-maxdepth 1"
              #shift $((OPTIND-1))
                #;;
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

    #if [[ -z "$file_type" ]]; then
        #compiledFileTypeArgs="-type f"
    #else
        #for item in $file_type; do
            #[[ -z "$compiledFileTypeArgs" ]] && compiledFileTypeArgs="-type $item" \
                                             #|| compiledFileTypeArgs="$compiledFileTypeArgs -o -type $item"
        #done
    #fi

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
            # override du_size_unit defined by the invoker:
            du_size_unit="$sizeArgLastChar"

            if ! [[ "$sizeArgLastChar" =~ ^[KMGTPEZYB]+$ ]]; then
                err "unsupported du block size unit provided: \"$du_size_unit\"" "$FUNCNAME_"
                return 1
            fi

            sizeArg="${sizeArg:0:$(( ${#sizeArg} - 1))}"
        fi

        if [[ -z "$sizeArg" ]]; then
            err "base size has to be provided as well, not only the unit." "$FUNCNAME_"
            echo -e "$usage"
            return 1
        elif ! is_digit "$sizeArg"; then
            err "base size has to be a digit, but was \"$sizeArg\"." "$FUNCNAME_"
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
        err "could not detect whether we should look for smaller or larger than ${sizeArg}$du_size_unit files" "$FUNCNAME_"
        return 1
    fi

    report "seeking for files $biggerOrSmaller than ${sizeArg}$du_size_unit ..." "$FUNCNAME_"

    if [[ "$file_type" == "-type f" ]]; then
        # optimization for files-only logic (ie no directories) to avoid expensive
        # calls to other programs (like awk and du).

        filesize_print_unit="k" # find's printf unit for the filesize; note that this is used merely for the printing not for seeking for the files;

        if ! [[ "$du_size_unit" =~ ^[KMGB]+$ ]]; then
            err "unsupported block size unit for find: \"$du_size_unit\". refer to man find and search for \"-size\"" "$FUNCNAME_"
            echo -e "$usage"
            return 1

        # convert some of the du types to the find equivalents:
        elif [[ "$du_size_unit" == B ]]; then
            du_size_unit=c # bytes unit for find
            filesize_print_unit="s"
            ignore_filesize_print_unit_msg=1
        elif [[ "$du_size_unit" == K ]]; then
            du_size_unit=k # kilobytes unit for find
            ignore_filesize_print_unit_msg=1
        fi

        [[ "$ignore_filesize_print_unit_msg" -ne 1 ]] && report "note that printed file size is in 1k units (limitation of find's -printf)\n" "$FUNCNAME_"

        # find's printf:
        # %s file size in byte   - appears to be the same as du block-size w/o any units
        # %k in 1K blocks
        # %b in 512byte blocks
        find $follow_links . -mindepth 1 $maxDepthParam -size ${plusOrMinus}${sizeArg}${du_size_unit} $file_type -printf "%${filesize_print_unit}\t%P\n" 2>/dev/null | \
            sort -n $reverse

    else # directories included, need to use du + awk
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
            du_blk_sz="--bytes"
            unset du_size_unit # with bytes, --threshold arg doesn't need a unit
        else
            du_blk_sz="--block-size=$du_size_unit"
        fi

        [[ "$file_type" != "-type d" ]] && du_include_regular_files="--all"  # if not dirs only;

        du $follow_links $du_include_regular_files $du_blk_sz $duMaxDepthParam --threshold=${plusOrMinus}${sizeArg}${du_size_unit} 2>/dev/null | \
            sort -n $reverse
    fi
}

# find  nodes bigger than x mb:
function ffindbiggerthan() {
    #find . -size +${size}M -exec ls -s --block-size=M {} \; | sort -nr 2>/dev/null
    __find_bigger_smaller_common_fun "-r" "M" "$FUNCNAME" "bigger" $@
}

# find  nodes smaller than x mb:
function ffindsmallerthan() {
    #find . -size -${size}M -exec ls -s --block-size=M {} \; | sort -n 2>/dev/null
    __find_bigger_smaller_common_fun "" "M" "$FUNCNAME" "smaller" $@
}

# mkdir and cd into it:
function mkcd() { mkdir -p "$@" && cd "$@"; }
function mkf() { mkcd "$@"; } # alias to mkcd

function aptsearch() {
    [[ -z "$@" ]] && { err "provide partial package name to search for." "$FUNCNAME"; return 1; }
    aptitude search "$@"
    #apt-cache search "$@"
}

function aptsrc() { aptsearch "$@"; } # alias

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of grep).
# !!! deprecated by ag/astr
function ffstr() {
    local grepcase OPTIND usage opt MAX_RESULT_LINE_LENGTH caseOptCounter force_case regex INAME_ARG

    caseOptCounter=0
    OPTIND=1
    MAX_RESULT_LINE_LENGTH=300 # max nr of characters per grep result line
    usage="\n$FUNCNAME: find string in files (from current directory recursively). smartcase both for filename and search patterns.
    Usage: $FUNCNAME [-i] [-s] \"pattern\" [filename pattern]
        -i  force case insensitive
        -s  force case sensitivity
        -r  enable regex on filename pattern"


    check_progs_installed ag && report "consider using ag or its wrapper astr (same thing as $FUNCNAME, but using ag instead of find+grep)" "$FUNCNAME"

    while getopts "isrh" opt; do
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

    # as find doesn't support smart case, provide it yourself:
    if [[ "$(tolowercase "$1")" == "$1" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        grepcase=" -i "
    fi

    if [[ -n "$2" && "$(tolowercase "$2")" == "$2" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        INAME_ARG="-iname"
    fi

    [[ "$force_case" -eq 1 ]] && { grepcase=""; INAME_ARG=""; }

    if [[ "$regex" -eq 1 ]]; then
        [[ -z "$2" ]] && { err "with -r flag, please provide file name pattern." "$FUNCNAME"; return 1; }
        [[ -n "$INAME_ARG" ]] && INAME_ARG="-regextype posix-extended -iregex" || INAME_ARG="-regextype posix-extended -regex"

        eval find . -type f $INAME_ARG '.*'"$2"'.*' -print0 2>/dev/null | \
            xargs -0 grep -E --color=always -sn ${grepcase} "$1" | \
            cut -c 1-$MAX_RESULT_LINE_LENGTH | \
            more
            #less
    else
        find . -type f "${INAME_ARG:--name}" '*'"${2:-*}"'*' -print0 2>/dev/null | \
            xargs -0 grep -E --color=always -sn ${grepcase} "$1" | \
            cut -c 1-$MAX_RESULT_LINE_LENGTH | \
            more
            #less
    fi
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

    ag $filePattern $grepcase "$1" 2>/dev/null
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
        i="$(dirname "$i")"
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

    if ! mv "$first_file" "$TMPFILE"; then
        err "moving $first_file to $TMPFILE failed. abort." "$FUNCNAME"
        return 1
    fi

    # check if $sec_file fits into $first_file:
    file_size="$(get_size "$sec_file")"
    space_left_on_target="$(space_left "$first_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$sec_file size is ${file_size}MB, but $(dirname "$first_file") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        # undo:
        mv "$TMPFILE" "$first_file"
        return 1
    fi

    if ! mv "$sec_file" "$first_file"; then
        err "moving $sec_file to $first_file failed. abort." "$FUNCNAME"
        # undo:
        mv "$TMPFILE" "$first_file"
        return 1
    fi

    # check if $first_file fits into $sec_file:
    file_size="$(get_size "$TMPFILE")"
    space_left_on_target="$(space_left "$sec_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname "$sec_file") has only ${space_left_on_target}MB free space left. abort." "$FUNCNAME"
        # undo:
        mv "$first_file" "$sec_file"
        mv "$TMPFILE" "$first_file"
        return 1
    fi

    if ! mv "$TMPFILE" "$sec_file"; then
        err "moving $first_file to $sec_file failed. abort." "$FUNCNAME"
        # undo:
        mv "$first_file" "$sec_file"
        mv "$TMPFILE" "$first_file"
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
    if [[ "$dir" != *ssh*  ]]; then
        confirm  "\nthe node name you're about to $FUNCNAME does not contain string \"ssh\"; still continue? (y/n)" || return 1
    fi

    chmod -R u=rwX,g=,o= "$dir";
}

function ssh_sanitize() { sanitize_ssh "$@"; } # alias for sanitize_ssh

function my_ip() { # Get internal & external ip addies:
    local internal_ip external_ip connected_interface

    connected_interface="$(find_connected_if)"

    if [[ -n "$connected_interface" ]]; then
        external_ip="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)"
        internal_ip="$(/sbin/ifconfig "$connected_interface" | awk '/inet / { print $2 } ' | sed -e s/addr://)"
        echo "${internal_ip:-"Not connected"} @ $connected_interface"
        echo "${external_ip:-"Not connected"}"
        return 0
    fi

    echo "Not connected (at least nothing was returned by find_connected_if())"
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
        err "'$file' is not a regular file or read rights not granted." "$FUNCNAME"
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
  local i
  local d=""
  local limit=$1
  for ((i=1 ; i <= limit ; i++)); do
      d="$d/.."
  done
  d="$(echo $d | sed 's/^\///')"
  [[ -z "$d" ]] && d=".."

  cd "$d"
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
    check_progs_installed xmllint vim || return 1;
    xmllint --format $@ | vim  "+set foldlevel=99" -;
}

function xmlf() { xmlformat $@; } # alias for xmlformat;

function createUsbIso() {
    local file device mountpoint cleaned_devicename usage
    file="$1"
    device="$2"

    cleaned_devicename="${device%/}" # strip trailing slash
    cleaned_devicename="${cleaned_devicename##*/}"  # strip everything before last slash (slash included)
    usage="usage:   $FUNCNAME  image.file  device\nexample: $FUNCNAME  file.iso  /dev/sdh"

    check_progs_installed   dd lsblk umount sudo || return 1

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
    elif ! ls /dev | grep "\b$cleaned_devicename\b" > /dev/null 2>&1 ;then
        err "$cleaned_devicename does not exist in /dev" "$FUNCNAME"
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

    confirm  "\nis selected device - $device - the correct one (be VERY sure!)? (y/n)" || return 1

    # find if device is mounted:
    #  TODO: what about partition mountpoints????
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
    fi

    # check dir
    [[ -n "$dir" ]] || {
       err "$usage" "$FUNCNAME"
       return 1
    }

    # use dir name if, no gitname specified
    [[ -n "$gitname" ]] || gitname="$dir"
    [[ -d "$dir"     ]] || mkdir "$dir"

    [[ -w "$dir" ]] || {
       err "we were unable to create dir $dir, or it simply doesn't have write permissions." "$FUNCNAME"
       return 1
    }

    # bail out, if already git repo
    [[ -d "$dir/.git" ]] && {
       err "already a git repo: $dir" "$FUNCNAME"
       return 1
    }

    cd "$dir"
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
    local DMENU match gtdir count
    local cwd="$PWD"
    local dmenurc="$HOME/.dmenurc"
    local editor="$EDITOR"

    check_progs_installed git "$editor" dmenu || return 1
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    git rev-parse --is-inside-work-tree &>/dev/null || { err "not in git repo." "$FUNCNAME"; return 1; } # test if git
    gtdir="$(git rev-parse --show-toplevel )"
    [[ "$cwd" != "$gtdir" ]] && pushd "$gtdir" &> /dev/null # git root

    if [[ -n "$@" ]]; then
        if [[ "$@" == *\** && "$@" != *\.\** ]]; then
            err 'use .* as wildcards, not a single *' "$FUNCNAME"
            [[ "$cwd" != "$gtdir" ]] && popd &> /dev/null # go back
            return 1
        elif [[ "$(echo "$@" | tr -dc '.' | wc -m)" -lt "$(echo "$@" | tr -dc '*' | wc -m)" ]]; then
            err "nr of periods (.) was less than stars (*); you're misusing regex." "$FUNCNAME"
            [[ "$cwd" != "$gtdir" ]] && popd &> /dev/null # go back
            return 1
        fi

        match="$(git ls-files | grep -Ei "$@")"
    else
        match="$(git ls-files)"
    fi

    [[ "$cwd" != "$gtdir" ]] && popd &> /dev/null # go back

    count="$(echo "$match" | wc -l)"
    [[ "$count" -gt 1 ]] && { report "found $count items" "$FUNCNAME"; match="$(echo "$match" | $DMENU -l 20 -p open)"; }
    #[[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | bemenu -i -l 20 -p "$editor")"
    [[ -z "$match" ]] && return 1
    match="$gtdir/$match" # convert to absolute
    [[ -f "$match" ]] || { err "\"$match\" is not a regular file." "$FUNCNAME"; return 1; }

    $editor "$match"
}

# ag looks for whole file path!
ago() {
    err "ag is not playing along at the moment. see fo()"
    return 1


    local DMENU match
    local dmenurc="$HOME/.dmenurc"
    local editor="$EDITOR"

    check_progs_installed ag $editor dmenu || return 1
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    [[ -z "$@" ]] && { err "args required."; return 1; }

    match="$(ag -g "$@")"
    [[ "$?" -eq 0 ]] || return 1

    [[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | $DMENU -l 20 -p open)"
    [[ -z "$match" ]] && return 1

    [[ -f "$match" ]] || { err "\"$match\" is not a regular file." "$FUNCNAME"; return 1; }
    $editor "$match"
}

# finds files/dirs using ffind() (find wrapper) and opens them.
# mnemonic: file open
fo() {
    local DMENU match count filetype dmenurc editor image_viewer video_player file_mngr pdf_viewer

    dmenurc="$HOME/.dmenurc"
    editor="$EDITOR"
    image_viewer="sxiv"
    video_player="smplayer"
    file_mngr="ranger"
    pdf_viewer="zathura"

    check_progs_installed find ffind "$file_mngr" "$editor" "$image_viewer" "$video_player" "$pdf_viewer" dmenu file || return 1
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    [[ -z "$@" ]] && { err "args required. see ffind -h" "$FUNCNAME"; return 1; }

    match="$(ffind "$@")"
    [[ "$?" -eq 0 ]] || return 1

    count="$(echo "$match" | wc -l)"
    [[ "$count" -gt 1 ]] && { report "found $count items" "$FUNCNAME"; match="$(echo "$match" | $DMENU -l 20 -p open)"; }
    [[ -z "$match" ]] && return 1

    # note that test will resolve links to files and dirs as well;
    # TODO: instead of file, use xdg-open?
    if [[ -f "$match" ]]; then
        filetype="$(file -iLb "$match")"

        if echo "$filetype" | grep -q '^image/'; then
            $image_viewer "$match"
        elif echo "$filetype" | grep -q '^video/'; then
            $video_player "$match"
        elif echo "$filetype" | grep -q '^text/'; then
            $editor "$match"
        elif echo "$filetype" | grep -q '^application/pdf'; then
            $pdf_viewer "$match"
        elif echo "$filetype" | grep -q '^application/x-executable; charset=binary'; then
            confirm "$match is executable. want to launch it from here?" || return
            report "launching ${match}..." "$FUNCNAME"
            "$match"
        else
            err "dunno what to open this type of file with:\n\t$filetype" "$FUNCNAME"
            return 1
        fi
    elif [[ -d "$match" ]]; then
        "$file_mngr" "$match"
    else
        err "\"$match\" isn't either regular file nor a dir." "$FUNCNAME"
        return 1
    fi
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

function killmenao() {
    confirm "you sure?" || return 1
    clear
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
   [[ -d "$@" ]] && { cd "$@"; } || cd "$(dirname "$@")";
}

# cd-s to directory by partial match; if multiple matches, opens input via dmenu. smartcase.
#  g /data/partialmatch     # searches for partialmatch in /data
#  g partialmatch           # searches for partialmatch in current dir
g() {
    local path input file matches pattern DMENU dmenurc msg_loc INAME_ARG

    input="$@"
    dmenurc="$HOME/.dmenurc"

    [[ -z "$input" ]] && { err "no input." "$FUNCNAME"; return 1; }
    [[ -d "$input" ]] && { cd "$input"; return; }
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    #[[ "$input" == */* ]] && path="${input%%/*}"  # strip everything after last slash(included)
    path="$(dirname "$input")"
    [[ -d "$path" ]] || { err "something went wrong - dirname result \"$path\" is not a dir." "$FUNCNAME"; return 1; }
    pattern="${input##*/}" # strip everything before last slash (included)
    [[ -z "$pattern" ]] && { err "no search pattern provided" "$FUNCNAME"; return 1; }
    [[ "$path" == '.' ]] && msg_loc="here" || msg_loc="$path"

    if [[ "$(tolowercase "$pattern")" == "$pattern" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        INAME_ARG="-iname"
    fi

    matches="$(find -L "$path" -maxdepth 1 -mindepth 1 \( -type d \) ${INAME_ARG:--name} '*'"$pattern"'*')"
    if [[ -z "$matches" ]]; then
        err "no dirs in $msg_loc matching \"$pattern\"" "$FUNCNAME"
        return 1
    fi

    [[ "$(echo "$matches" | wc -l)" -gt 1 ]] && matches="$(echo "$matches" | $DMENU -l 20 -p cd)"
    [[ -z "$matches" ]] && return 1
    if ! [[ -d "$matches" ]]; then
        err "no such dir like \"$matches\" in $msg_loc" "$FUNCNAME"
        return 1
    fi

    cd "$matches"
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
   check_progs_installed recordmydesktop || return 1

    #recordmydesktop --display=$DISPLAY --width=1024 height=768 -x=1680 -y=0 --fps=15 --no-sound --delay=10
    #recordmydesktop --display=0 --width=1920 height=1080 --fps=15 --no-sound --delay=10
   ffcast -w ffmpeg -f alsa -ac 2 -i hw:0,2 -f x11grab -s %s -i %D+%c -acodec pcm_s16le -vcodec huffyuv $@
}

##############################################
## Colored Find                             ##
## NOTE: Searches current tree recrusively. ##
##############################################
f() {
   find . -iregex ".*$@.*" -printf '%P\0' | xargs -r0 ls --color=auto -1d
}

# marker function used to detect whether functions have been loaded into the shell:
function __BASH_FUNS_LOADED_MARKER() { true; }

