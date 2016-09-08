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
    local src srcdir iname_arg opt usage OPTIND file_type filetypeOptionCounter exact filetype follow_links
    local maxDepth maxDepthParam pathOpt regex defMaxDeptWithFollowLinks force_case caseOptCounter skip_msgs
    local quitFlag type_grep extra_params matches i delete deleteFlag

    function __filter_for_filetype() {
        local filetype index

        [[ -z "${matches[*]}" ]] && return 1
        [[ -z "$type_grep" ]] && { err "[\$type_grep] not defined." "$FUNCNAME"; return 1; }
        index=0

        while read filetype; do
            [[ "$filetype" =~ $type_grep ]] && echo "${matches[$index]}" | grep -iE --color=auto -- "$src|$"
            let index++
        done < <(file -iLb -- "${matches[@]}")
    }

    [[ "$1" == --_skip_msgs ]] && { skip_msgs=1; shift; }  # skip showing informative messages, as the result will be directly echoed to other processes;
    defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) is provided;

    usage="\n$FUNCNAME: find files/dirs by name. smartcase.

    Usage: $FUNCNAME  [options]  \"fileName pattern\" [top_level_dir_to_search_from]

        -r  use regex (instead of find's own metacharacters *, ? and [])
        -i  force case insensitive
        -s  force case sensitivity
        -f  search for regular files
        -d  search for directories
        -l  search for symbolic links
        -b  search for executable binaries
        -V  search for video files
        -P  search for pdf files
        -I  search for image files
        -C  search for doc files (word, excel, opendocument...; NO pdf)
        -L  follow symlinks
        -D  delete found nodes  (won't delete nonempty dirs!)
        -q  provide find the -quit flag (exit on first found item)
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;
        -e  search for exact filename, not for a partial (you still can use * wildcards)
        -p  expand the pattern search for path as well (adds the -path option);
            might want to consider regex, that also searches across the whole path."

    filetypeOptionCounter=0
    caseOptCounter=0
    matches=()

    while getopts "m:isrefdlbLDqphVPIC" opt; do
        case "$opt" in
           i) iname_arg="-iname"
              caseOptCounter+=1
              shift $((OPTIND-1))
                ;;
           s) unset iname_arg
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
           b) readonly filetype=1
              extra_params='-executable'
              readonly type_grep='x-executable; charset=binary'
              shift $((OPTIND-1))
                ;;
           V) readonly filetype=1
              extra_params='-size +100M'  # search for min. x megs files, so mp4 wouldn't (likely) return audio files
              readonly type_grep='video/|audio/mp4'
              shift $((OPTIND-1))
                ;;
           P) readonly filetype=1
              readonly type_grep='application/pdf; charset=binary'
              shift $((OPTIND-1))
                ;;
           I) readonly filetype=1
              readonly type_grep='image/\w+; charset=binary'
              shift $((OPTIND-1))
                ;;
           C)  # for doC
              readonly filetype=1
              shift $((OPTIND-1))

              # try keeping doc files' definitions in sync with the ones in fo()
              # no linebreaks in regex!
              readonly type_grep='application/msword; charset=binary|application/.*opendocument.*; charset=binary|application/vnd.ms-office; charset=binary'
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
           D) readonly delete=1     # for nonempty dirs as well, just run     find . -name "3" -type d -exec rm -rf {} +
              readonly deleteFlag='-delete'
              shift $((OPTIND-1))
                ;;
           *) echo -e "$usage"
              [[ "$skip_msgs" -eq 1 ]] && return 9 || return 1
                ;;
        esac
    done

    src="$1"
    srcdir="$2"  # optional

    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$src" ]]; then
        err "incorrect nr of aguments." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f, -d, -l flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$filetypeOptionCounter" -ge 1 && "$filetype" -eq 1 && "$file_type" != "-type f" ]]; then
        err "-d, -l and filetype (eg -V) flags are exclusive." "$FUNCNAME"
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
    elif [[ "$delete" -eq 1 && "$filetype" -eq 1 ]]; then
        err "-D and filetype (eg -V) flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$delete" -eq 1 ]] && ! confirm "wish to delete nodes that match [$src]?"; then
        return
    fi


    if [[ "$follow_links" == "-L" && "$file_type" == "-type l" && "$skip_msgs" -ne 1 ]]; then
        report "if both -l and -L flags are set, then ONLY the broken links are being searched.\n" "$FUNCNAME"
        sleep 2
    fi

    if [[ "$force_case" -eq 1 ]]; then
        unset iname_arg
    # as find doesn't support smart case, provide it yourself:
    elif [[ "$(tolowercase "$src")" == "$src" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        iname_arg="-iname"
    fi


    if [[ "$pathOpt" -eq 1 && "$exact" -eq 1 && "$skip_msgs" -ne 1 ]]; then
        report "note that using -p and -e flags together means that the pattern has to match whole path, not only the filename!" "$FUNCNAME"
        sleep 2
    fi

    if [[ -n "$srcdir" ]]; then
        if [[ ! -d "$srcdir" ]]; then
            err "provided directory to search from (\"$srcdir\") is not a directory. abort." "$FUNCNAME"
            return 1
        elif [[ "$srcdir" != */ ]]; then
            srcdir="${srcdir}/"  # add trailing slash if missing; required for gnu find; necessary in case it's a link.
        fi
    fi

    # find metacharacter or regex sanity:
    if [[ "$regex" -eq 1 ]]; then
        if [[ "$src" == *\** && "$src" != *\.\** ]]; then
            err 'use .* as wildcards, not a single *; are you misusing regex?' "$FUNCNAME"
            return 1
        elif [[ "$(echo "$src" | tr -dc '.' | wc -m)" -lt "$(echo "$src" | tr -dc '*' | wc -m)" ]]; then
            err "nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
            return 1
        fi
    else  # no regex, make sure find metacharacters are not mistaken for regex ones:
        if [[ "$src" == *\.\** ]]; then
            err "only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex." "$FUNCNAME"
            return 1
        fi

        if [[ "$src" == *\.* && "$skip_msgs" -ne 1 ]]; then
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
        [[ -n "$iname_arg" ]] && iname_arg="-iwholename" || iname_arg="-path"  # as per man page, -ipath is deprecated
    elif [[ "$regex" -eq 1 ]]; then
        [[ -n "$iname_arg" ]] && iname_arg="-regextype posix-extended -iregex" || iname_arg="-regextype posix-extended -regex"
    fi

    # trailing grep is for coloring only:
    if [[ "$exact" -eq 1 ]]; then # no regex with exact; they are excluded.
        if [[ "$filetype" -eq 1 ]]; then
            # original, all-in-find-command solution; slower, since file command will be launced per every result:
            #find $follow_links "${srcdir:-.}" $maxDepthParam -type f ${iname_arg:--name} "$src" $extra_params -exec sh -c "file -iLb -- \"{}\" | grep -Eq -- '$type_grep'" \; -print $quitFlag $deleteFlag 2>/dev/null | grep -iE --color=auto -- "$src|$"
            # optimised version:
            while read i; do
                matches+=( "$i" )
            done < <(find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} "$src" $extra_params -print $quitFlag 2>/dev/null)
            __filter_for_filetype
        else
            find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} "$src" -print $quitFlag $deleteFlag 2>/dev/null | grep -iE --color=auto -- "$src|$"
        fi
    else  # partial filename match, ie add * padding
        if [[ "$regex" -eq 1 ]]; then  # using regex, need to change the * padding around $src
            #
            # TODO remove eval!
            #
            report "!!! running with eval, be careful !!!" "$FUNCNAME"
            sleep 2  # give time to bail out

            if [[ "$filetype" -eq 1 ]]; then
                # original, all-in-find-command solution; slower, since file command will be launced per every result:
                #eval "find $follow_links \"${srcdir:-.}\" $maxDepthParam -type f ${iname_arg:--name} '.*'\"$src\"'.*' $extra_params -exec sh -c \"file -iLb -- \\\"{}\\\" | grep -Eq -- '$type_grep'\" \; -print $quitFlag | grep -iE --color=auto -- \"$src|$\""
                # optimised version:
                while read i; do
                    matches+=( "$i" )
                done < <(eval find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} '.*'"$src"'.*' $extra_params -print $quitFlag 2>/dev/null)
                __filter_for_filetype
            else
                eval find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} '.*'"$src"'.*' -print $quitFlag $deleteFlag 2>/dev/null | grep -iE --color=auto -- "$src|$"
            fi
        else  # no regex
            if [[ "$filetype" -eq 1 ]]; then
                # original, all-in-find-command solution; slower, since file command will be launced per every result:
                #find $follow_links "${srcdir:-.}" $maxDepthParam -type f ${iname_arg:--name} '*'"$src"'*' $extra_params -exec sh -c "file -iLb -- \"{}\" | grep -Eq -- '$type_grep'" \; -print $quitFlag 2>/dev/null | grep -iE --color=auto -- "$src|$"
                # optimised version:
                while read i; do
                    matches+=( "$i" )
                done < <(find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} '*'"$src"'*' $extra_params -print $quitFlag 2>/dev/null)
                __filter_for_filetype
            else
                find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} '*'"$src"'*' -print $quitFlag $deleteFlag 2>/dev/null | grep -iE --color=auto -- "$src|$"
            fi
        fi
    fi

    unset __filter_for_filetype
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
        [[ "$file_type" != "-type d" ]] && readonly du_include_regular_files="--all"  # if not dirs only;

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

    reverse="$1"          # sorting order (param for sort)
    du_size_unit="$2"     # default unit provided by the invoker
    FUNCNAME_="$3"        # invoking function name
    biggerOrSmaller="$4"  # denotes whether larger or smaller than X size units were queried
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
           L) follow_links="-L"  # common for both find and du
              shift $((OPTIND-1))
                ;;
           h) echo -e "$usage"
              return 0
                ;;
           *) echo -e "$usage"
              return 1
                ;;
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
        # find out whether block size unit was provided:
        sizeArgLastChar="${sizeArg:$(( ${#sizeArg} - 1)):1}"

        if ! is_digit "$sizeArgLastChar"; then
            if ! [[ "$sizeArgLastChar" =~ ^[KMGTPEZYB]+$ ]]; then
                err "unsupported du block size unit provided: \"$sizeArgLastChar\"" "$FUNCNAME_"
                return 1
            fi

            # override du_size_unit defined by the invoker:
            du_size_unit="$sizeArgLastChar"
            # clean up the numeric sizeArg:
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

        if ! [[ "$find_size_unit" =~ ^[KMGB]+$ ]]; then
            err "unsupported block size unit for find: \"$find_size_unit\". refer to man find and search for \"-size\"" "$FUNCNAME_"
            echo -e "$usage"
            return 1

        # convert some of the du types to the find equivalents:
        elif [[ "$find_size_unit" == B ]]; then
            find_size_unit=c  # bytes unit for find
        elif [[ "$find_size_unit" == K ]]; then
            find_size_unit=k  # kilobytes unit for find
        fi


        # old version using find's printf:
        # find's printf:
        # %s file size in byte   - appears to be the same as du block-size w/o any units
        # %k in 1K blocks
        # %b in 512byte blocks
        #find $follow_links . -mindepth 1 $maxDepthParam -size ${plusOrMinus}${sizeArg}${find_size_unit} $file_type -printf "%${filesize_print_unit}${orig_size_unit}\t%P\n" 2>/dev/null | \
            #sort -n $reverse

        find $follow_links . -mindepth 1 $maxDepthParam \
            -size ${plusOrMinus}${sizeArg}${find_size_unit} \
            $file_type \
            -exec du -a "$du_blk_sz" '{}' +  2>/dev/null | \
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

        [[ "$file_type" != "-type d" ]] && readonly du_include_regular_files="--all"  # if not dirs only;

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
    local apt_lists_dir

    readonly apt_lists_dir="/var/lib/apt/lists"

    report "note that sudo passwd is required" "$FUNCNAME"

    if [[ -d "$apt_lists_dir" ]]; then
        report "deleting contents of $apt_lists_dir" "$FUNCNAME"
        sudo rm -rf $apt_lists_dir/*
    else
        err "$apt_lists_dir is not a dir; can't delete the contents in it." "$FUNCNAME"
    fi

    report "running apt-get clean..." "$FUNCNAME"
    sudo apt-get clean
    #sudo apt-get update
    #sudo apt-get upgrade
}

function aptclean() { aptreset; }

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of grep).
# !!! deprecated by ag/astr
# TODO: find whether we could stop using find here and use grep --include & --exclude flags instead.
function ffstr() {
    local grepcase OPTIND usage opt max_result_line_length caseOptCounter force_case regex i
    local iname_arg maxDepth maxDepthParam defMaxDeptWithFollowLinks follow_links result
    local pattern file_pattern collect_files open_files

    caseOptCounter=0
    OPTIND=1
    max_result_line_length=300      # max nr of characters per grep result line
    defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) option selected;

    usage="\n$FUNCNAME: find string in files (from current directory recursively). smartcase both for filename and search patterns.
    Usage: $FUNCNAME [opts] \"pattern\" [filename pattern]
        -i  force case insensitive;
        -s  force case sensitivity;
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;
        -L  follow symlinks;
        -c  collect matching filenames into global array instead of printing to stdout;
        -o  open found files;
        -r  enable regex on filename pattern"


    command -v ag > /dev/null && report "consider using ag or its wrapper astr (same thing as $FUNCNAME, but using ag instead of find+grep)\n" "$FUNCNAME"

    while getopts "isrm:Lcoh" opt; do
        case "$opt" in
           i) grepcase=" -i "
              iname_arg="-iname"
              caseOptCounter+=1
              shift $(( $OPTIND - 1 ))
              ;;
           s) unset grepcase
              unset iname_arg
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
           c) collect_files=1
              shift $((OPTIND-1))
                ;;
           o) open_files=1
              collect_files=1  # so we can use the array
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

    pattern="$1"
    file_pattern="$2"

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
    if [[ "$pattern" == *\** && "$pattern" != *\.\** ]]; then
        err "use .* as wildcards, not a single *" "$FUNCNAME"
        return 1
    elif [[ "$(echo "$pattern" | tr -dc '.' | wc -m)" -lt "$(echo "$pattern" | tr -dc '*' | wc -m)" ]]; then
        err "nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
        return 1
    fi


    # find metacharacter or regex FILENAME (not search pattern) sanity:
    if [[ -n "$file_pattern" ]]; then
        if [[ "$file_pattern" == */* ]]; then
            err "there are slashes in the filename. note that optional 2nd arg is a filename pattern, not a path." "$FUNCNAME"
            return 1
        fi

        if [[ "$regex" -eq 1 ]]; then
            if [[ "$file_pattern" == *\** && "$file_pattern" != *\.\** ]]; then
                err 'err in filename pattern: use .* as wildcards, not a single *; you are misusing regex.' "$FUNCNAME"
                return 1
            elif [[ "$(echo "$file_pattern" | tr -dc '.' | wc -m)" -lt "$(echo "$file_pattern" | tr -dc '*' | wc -m)" ]]; then
                err "err in filename pattern: nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
                return 1
            fi
        else # no regex, make sure find metacharacters are not mistaken for regex ones:
            if [[ "$file_pattern" == *\.\** ]]; then
                err "err in filename pattern: only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex." "$FUNCNAME"
                return 1
            fi

            if [[ "$file_pattern" == *\.* ]]; then
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
    if [[ "$(tolowercase "$pattern")" == "$pattern" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        grepcase=" -i "
    fi

    if [[ -n "$file_pattern" && "$(tolowercase "$file_pattern")" == "$file_pattern" ]]; then
        # provided pattern was lowercase, make it case insensitive:
        iname_arg="-iname"
    fi

    [[ "$force_case" -eq 1 ]] && unset grepcase iname_arg

    ## Clean grep-only solution: (in this case the maxdepth option goes out the window)
    #if [[ -z "$file_pattern" ]]; then
        #[[ -n "$follow_links" ]] && follow_links=R || follow_links=r
        #grep -E${follow_links} --color=always -sn ${grepcase} -- "$pattern"

    #elif [[ "$regex" -eq 1 ]]; then
    if [[ "$regex" -eq 1 ]]; then
        # TODO: convert to  'find . -name "$ext" -type f -exec grep "$pattern" /dev/null {} +' perhaps?
        [[ -z "$file_pattern" ]] && { err "with -r flag, filename argument is required." "$FUNCNAME"; return 1; }
        [[ -n "$iname_arg" ]] && iname_arg="-regextype posix-extended -iregex" || iname_arg="-regextype posix-extended -regex"

        if [[ "$collect_files" -eq 1 ]]; then
            result="$(eval find $follow_links . $maxDepthParam -type f $iname_arg '.*'"$file_pattern"'.*' -print0 2>/dev/null | \
                    xargs -0 grep -El --color=never -sn ${grepcase} -- "$pattern")"
        else
            eval find $follow_links . $maxDepthParam -type f $iname_arg '.*'"$file_pattern"'.*' -print0 2>/dev/null | \
                xargs -0 grep -E --color=always -sn ${grepcase} -- "$pattern" | \
                cut -c 1-$max_result_line_length | \
                more
                #less
        fi
    else
        if [[ "$collect_files" -eq 1 ]]; then
            result="$(find $follow_links . $maxDepthParam -type f "${iname_arg:--name}" '*'"${file_pattern:-*}"'*' -print0 2>/dev/null | \
                    xargs -0 grep -El --color=never -sn ${grepcase} -- "$pattern")"
        else
            find $follow_links . $maxDepthParam -type f "${iname_arg:--name}" '*'"${file_pattern:-*}"'*' -print0 2>/dev/null | \
                xargs -0 grep -E --color=always -sn ${grepcase} -- "$pattern" | \
                cut -c 1-$max_result_line_length | \
                more
                #less
        fi
    fi

    if [[ "$collect_files" -eq 1 ]]; then
        _FOUND_FILES=()
        while read i; do
            _FOUND_FILES+=( "$i" )
        done < <(echo "$result")

        report "found ${#_FOUND_FILES[@]} files containing [$pattern]; stored in \$_FOUND_FILES global array." "$FUNCNAME"
        [[ "${#_FOUND_FILES[@]}" -eq 0 ]] && return 1
    fi

    if [[ "$open_files" -eq 1 ]]; then
        # TODO: pass the array to-be-refactored fo()
        check_progs_installed "$EDITOR" || return 1
        $EDITOR "${_FOUND_FILES[@]}"
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
        err "nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
        return 1
    fi

    [[ -n "$2" ]] && filePattern="-${fileCase}G $2"

    ag $filePattern $grepcase -- "$1" 2>/dev/null
}

# Swap 2 files around, if they exist (from Uzi's bashrc):
function swap() {
    local tmp file_size space_left_on_target i first_file sec_file

    tmp="/tmp/${FUNCNAME}_function_tmpFile.$RANDOM"
    first_file="${1%/}" # strip trailing slash
    sec_file="${2%/}" # strip trailing slash

    count_params 2 $# equal || return 1
    [[ ! -e "$first_file" ]] && err "$first_file does not exist" "$FUNCNAME" && return 1
    [[ ! -e "$sec_file" ]] && err "$sec_file does not exist" "$FUNCNAME" && return 1
    [[ "$first_file" == "$sec_file" ]] && err "source and destination cannot be the same" "$FUNCNAME" && return 1


    # check write perimssions:
    for i in "$tmp" "$first_file" "$sec_file"; do
        i="$(dirname -- "$i")"
        if [[ ! -w "$i" ]]; then
            err "$i doesn't have write permission. abort." "$FUNCNAME"
            return 1
        fi
    done

    # check if $first_file fits into /tmp:
    file_size="$(get_size "$first_file")"
    space_left_on_target="$(space_left "$tmp")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname "$tmp") has only [${space_left_on_target}MB] free space left. abort." "$FUNCNAME"
        return 1
    fi

    if ! mv -- "$first_file" "$tmp"; then
        err "moving $first_file to $tmp failed. abort." "$FUNCNAME"
        return 1
    fi

    # check if $sec_file fits into $first_file:
    file_size="$(get_size "$sec_file")"
    space_left_on_target="$(space_left "$first_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$sec_file size is ${file_size}MB, but $(dirname "$first_file") has only [${space_left_on_target}MB] free space left. abort." "$FUNCNAME"
        # undo:
        mv -- "$tmp" "$first_file"
        return 1
    fi

    if ! mv -- "$sec_file" "$first_file"; then
        err "moving $sec_file to $first_file failed. abort." "$FUNCNAME"
        # undo:
        mv -- "$tmp" "$first_file"
        return 1
    fi

    # check if $first_file fits into $sec_file:
    file_size="$(get_size "$tmp")"
    space_left_on_target="$(space_left "$sec_file")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        err "$first_file size is ${file_size}MB, but $(dirname "$sec_file") has only [${space_left_on_target}MB] free space left. abort." "$FUNCNAME"
        # undo:
        mv -- "$first_file" "$sec_file"
        mv -- "$tmp" "$first_file"
        return 1
    fi

    if ! mv -- "$tmp" "$sec_file"; then
        err "moving $first_file to $sec_file failed. abort." "$FUNCNAME"
        # undo:
        mv "$first_file" "$sec_file"
        mv "$tmp" "$first_file"
        return 1
    fi
}

# list current directory and search for a file/dir by name:
function lgrep() {
    local src srcdir usage exact OPTIND

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

    src="$1"
    srcdir="$2"

    # sanity:
    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$src" ]]; then
        echo -e "$usage"
        return 1;
    elif [[ -n "$srcdir" ]]; then
        if [[ ! -d "$srcdir" ]]; then
            err "provided directory to list and grep from is not a directory. abort." "$FUNCNAME"
            echo -e "\n$usage"
            return 1
        elif [[ ! -r "$srcdir" ]]; then
            err "provided directory to list and grep from is not readable. abort." "$FUNCNAME"
            return 1
        fi
    fi

    if [[ "$exact" -eq 1 ]]; then
        find "${srcdir:-.}" -maxdepth 1 -mindepth 1 -name "$src" -printf '%f\n' | grep -iE --color=auto "$src|$"
    else
        ls -lA "${srcdir:-.}" | grep --color=auto -i -- "$src"
        #find "${srcdir:-.}" -maxdepth 1 -mindepth 1 -iname '*'"$src"'*' -printf '%f\n' | grep -iE --color=auto "$src|$"
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
    [[ ! -e "$@" ]] && { err "[$*] does not exist." "$FUNCNAME"; return 1; }
    chmod -R u=rwX,g=rX,o= -- "$@";
}

function sanitize_ssh() {
    local node="$*"

    [[ -z "$node" ]] && { err "provide a file/dir name plz. (most likely you want the .ssh dir)" "$FUNCNAME"; return 1; }
    [[ ! -e "$node" ]] && { err "[$node] does not exist." "$FUNCNAME"; return 1; }
    if [[ "$node" != *ssh*  ]]; then
        confirm  "\nthe node name you're about to $FUNCNAME does not contain string [ssh]; still continue? (y/n)" || return 1
    fi

    chmod -R u=rwX,g=,o= -- "$node";
}

function ssh_sanitize() { sanitize_ssh "$@"; } # alias for sanitize_ssh

function myip() {  # Get internal & external ip addies:
    local connected_interface interfaces if_dir interface external_ip

    if_dir="/sys/class/net"

    function __get_internal_ip_for_if() {
        local interface ip

        interface="$1"

        ip="$(ip addr show "$interface" | awk '/ inet /{print $2}')" || return 1
        ip="${ip%%/*}"  # strip the subnet

        #ip="$(/sbin/ifconfig "$interface" | awk '/inet / {print $2}' | sed -e s/addr://)"  # deprecated
        [[ -z "$ip" && "$__REMOTE_SSH" -eq 1 ]] && return  # probaby the interface was not found
        echo -e "${ip:-"Not connected"}\t@ $interface"
    }

    connected_interface="$(find_connected_if)"  # note this returns only on own machines, not on remotes.
    external_ip="$(get_external_ip)" && {
        echo -e "external:\t${external_ip:-"Not connected to the internet."}"
    }

    command -v ip > /dev/null 2>&1 || {  # don't use check_progs_installed because of its verbosity
        err "can't check internal ip as ip appears not to be installed." "$FUNCNAME"
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
            report "can't read interfaces from $if_dir [not a (readable) dir]; trying these interfaces: [$interfaces]" "$FUNCNAME"
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

function whatsmyip() { myip; }  # alias for myip

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
    local reverse inf ouf full_lsblk_output

    readonly usage="${FUNCNAME}: write files onto devices and vice versa.

    Usage:   $FUNCNAME  [options]  image.file  device
        -r  reverse the direction - device will be written into a file.
        -o  allow selecting devices whose name ends with a digit (note that you
            should be selecting a whole device instead of its parition (ie sda vs sda1),
            but some devices have weird names (eg sd cards)).

    example: $FUNCNAME  file.iso  /dev/sdh"

    check_progs_installed   dd lsblk dirname umount sudo || return 1

    while getopts "hor" opt; do
        case "$opt" in
           h) echo -e "$usage";
              return 0
              ;;
           o) override_dev_partitioncheck=1
              shift $((OPTIND-1))
              ;;
           r) reverse=1
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
    elif [[ ! -f "$file" && "$reverse" -ne 1 ]]; then
        err "$file is not a regular file" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ -f "$file" && "$reverse" -eq 1 ]]; then
        err "$file already exists. choose another file to write into, or delete it." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$reverse" -eq 1 && ! -d "$(dirname "$file")" ]]; then
        err "$file doesn't appear to be defined on a valid path. please check." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ ! -e "$device" ]]; then
        err "[$device] device does not exist" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif ! ls /dev | grep -q -- "\b${cleaned_devicename}\b" > /dev/null 2>&1 ;then
        err "[$cleaned_devicename] does not exist in /dev" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$override_dev_partitioncheck" -ne 1 && "$cleaned_devicename" =~ .*[0-9]+$ ]]; then
        # as per arch wiki
        err "please don't provide partition, but a drive, e.g. /dev/sdh instad of /dev/sdh1" "$FUNCNAME"
        report "note you can override this check with the -o flag." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$override_dev_partitioncheck" -eq 1 && "$cleaned_devicename" =~ .*[0-9]+$ ]]; then
        report "you've selected to override partition check (ie making sure you select device, not its partition.)" "$FUNCNAME"
        confirm "are you sure that [$cleaned_devicename] is the device you wish to select?" "$FUNCNAME" || return 1
    fi

    #echo "please provide passwd for running fdisk -l to confirm the selected device is the right one:"
    #sudo fdisk -l $device
    readonly full_lsblk_output="$(lsblk)" || { err "issues running lsblk"; return 1; }
    echo "$full_lsblk_output" | grep --color=auto -- "$cleaned_devicename\|MOUNTPOINT"

    confirm  "\nis selected device [$device] the correct one (be VERY sure!)? (y/n)" || { report "aborting, nothing written." "$FUNCNAME"; return 1; }

    # find if device is mounted:
    #lsblk -o name,size,mountpoint /dev/sda
    report "unmounting $cleaned_devicename partitions... (may ask for sudo password)"
    for partition in ${device}* ; do
        echo "$full_lsblk_output" | grep -Eq "${partition##*/}\b" || continue  # not all partitions are listed by lsblk; dunno what's with that

        mountpoint="$(lsblk -o mountpoint -- "$partition")" || { err "some issue occurred running [lsblk -o mountpoint ${partition}]" "$FUNCNAME"; return 1; }
        mountpoint="$(echo "$mountpoint" | sed -n 2p)"
        if [[ -n "$mountpoint" ]]; then
            report "[$partition] appears to be mounted at [$mountpoint], trying to unmount..." "$FUNCNAME"
            if ! sudo umount "$mountpoint"; then
                err "something went wrong with unmounting [${mountpoint}]. please unmount the device and try again." "$FUNCNAME"
                return 1
            fi
            report "...success." "$FUNCNAME"
        fi
    done

    [[ "$reverse" -eq 1 ]] && { inf="$device"; ouf="$file"; } || { inf="$file"; ouf="$device"; }

    echo
    confirm "last confirmation: wish to write [$inf] into [$ouf]?" || { report "aborting." "$FUNCNAME"; return 1; }
    report "Please provide sudo passwd for running dd:" "$FUNCNAME"
    sudo echo "..."
    clear

    report "Running dd, writing [$inf] into [$ouf]; this might take a while..." "$FUNCNAME"
    sudo dd if="$inf" of="$ouf" bs=4M || { err "some error occurred while running dd (err code [$?])." "$FUNCNAME"; }
    sync
    #eject $device

    # TODO:
    # verify integrity:
    #md5sum mydisk.iso
    #md5sum /dev/sr0
}

#######################
## Setup github repo ##
#######################
function mkgit() {
    local user passwd repo dir project_name OPTIND opt usage mainOptCounter http_statuscode
    local newly_created_dir

    mainOptCounter=0
    readonly usage="usage:   $FUNCNAME  -g|-b|-w  <dirname> [project_name]
         -g   create repo in github
         -b   create repo in bitbucket
         -w   create repo in work (not supported)

         if  project_name  is not given, then project name will be same as  dirname  "

    while getopts "hgbw" opt; do
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
           w) user="work user"
              repo="gitlab.work-dev.local"
              let mainOptCounter+=1
              shift $((OPTIND-1))
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    readonly dir="$1"
    readonly project_name="${2:-$dir}"  # default to dir name

    if [[ "$mainOptCounter" -gt 1 ]]; then
        err "-g and -b flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$mainOptCounter" -eq 0 ]]; then
        err "need to select a repo to create new project in." "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ "$#" -gt 2 ]]; then
        err "too many arguments" "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif ! check_progs_installed git getnetrc curl; then
        return 1
    elif [[ -z "$dir" ]]; then
        err "need to provide dirname at minimum" "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ -d "$dir/.git" ]]; then
        err "[$dir] is already a git repo. abort." "$FUNCNAME"
        return 1
    elif ! check_connection "$repo"; then
        err "no connection to [$repo]" "$FUNCNAME"
        return 1
    fi

    [[ -d "$dir" ]] || { mkdir -- "$dir"; readonly newly_created_dir=1; }

    if ! [[ -d "$dir" && -w "$dir" ]]; then
       err "we were unable to create dir [$dir], or it simply doesn't have write permission." "$FUNCNAME"
       return 1
    fi

    readonly passwd="$(getnetrc "${user}@${repo}")"
    if [[ "$?" -ne 0 || -z "$passwd" ]]; then
        err "getting password failed. abort." "$FUNCNAME"
        [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
        return 1
    fi

    # create remote repo, if not existing:
    if ! git ls-remote "git@${repo}:${user}/${project_name}" &> /dev/null; then
        if [[ "$repo" == 'github.com' ]]; then
            readonly http_statuscode="$(curl -sL \
                -w '%{http_code}' \
                -u "$user:$passwd" \
                https://api.github.com/user/repos \
                -d "{ \"name\":\"$project_name\", \"private\":\"true\" }" \
                -o /dev/null)"
        elif [[ "$repo" == 'bitbucket.org' ]]; then
            readonly http_statuscode="$(curl -sL -X POST \
                -w '%{http_code}' \
                -H "Content-Type: application/json" \
                -u "$user:$passwd" \
                "https://api.bitbucket.org/2.0/repositories/$user/$project_name" \
                -d '{ "scm": "git", "is_private": "true", "fork_policy": "no_public_forks" }' \
                -o /dev/null)"
        elif [[ "$repo" == 'gitlab.work-dev.local' ]]; then
            # https://forum.gitlab.com/t/create-a-new-project-in-a-group-using-api/1552/2
            #
            # find namespaces:
            #curl --header "PRIVATE-TOKEN: $passwd" "https://${repo}/api/v3/namespaces"
            # create repo:
            #curl --header "PRIVATE-TOKEN: token" -X POST "https://gitlab.com/api/v3/projects?name=foobartest4&namespace_id=<found_id>&description=This%20is%20a%20description"
            err "not supported"
            return 1
        else
            err "unexpected repo [$repo]" "$FUNCNAME"
            [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
            return 1
        fi

        if [[ "$http_statuscode" != 20* || "${#http_statuscode}" -ne 3 ]]; then
            err "curl request for creating the repo @ [$repo] apparently failed; response code was [$http_statuscode]" "$FUNCNAME"
            echo
            err "abort" "$FUNCNAME"

            [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
            return 1
        fi

        report "created new repo @ ${repo}/${user}/${project_name}" "$FUNCNAME"
        echo
    fi

    pushd -- "$dir" &> /dev/null || return 1
    git init || { err "bad return from git init" "$FUNCNAME"; return 1; }
    git remote add origin "git@${repo}:${user}/${project_name}.git" || { err "adding remote failed. abort." "$FUNCNAME"; return 1; }
    echo

    if confirm "want to add README.md (recommended)?"; then
        report "adding README.md ..." "$FUNCNAME"
        touch README.md
        git add README.md
        git commit -a -m 'inital setup - automated'
        git push -u origin master
    fi
}

########################################
## Open file inside git tree with vim ##
########################################
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
            err "nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
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

# git untag; git delete tag; git tag delete; delete git tag
gut() {
    local tag

    readonly tag="$*"

    [[ -z "$tag" ]] && { err "need to provide tag to delete." "$FUNCNAME"; return 1; }
    git_tag_exists "$tag" || { err "tag [$tag] does not exist. abort." "$FUNCNAME"; return 1; }
    git tag -d "$tag" || { err "deleting tag [$tag] locally failed. abort." "$FUNCNAME"; return 1; }
    git push origin ":refs/tags/$tag"
    return $?
}

# copy & print latest tag ver:
glt() {
    local last_tag

    readonly last_tag=$(git for-each-ref \
        --format='%(refname:short)' \
        --sort=taggerdate refs/tags \
        | tail -1)

    [[ $? -ne 0 || -z "$last_tag" || "$(echo "$last_tag" | wc -l)" -ne 1 ]] && { err "either no tags found or some issue occurred." "$FUNCNAME"; return 1; }
    report "latest tag: [$last_tag]" "$FUNCNAME"
    copy_to_clipboard "$last_tag" || { err "unable to copy tag to clipboard." "$FUNCNAME"; return 1; }
    return $?
}


# git flow feature start
gffs() {
    local branch

    readonly branch="$1"

    if [[ -z "$branch" ]]; then
        err "need to provide feature branch name to create/start" "$FUNCNAME"
        return 1
    elif [[ "$branch" == */* ]]; then
        err "there are slashes in the branchname. need to provide the child branch name only, not [feature/...]" "$FUNCNAME"
        return 1
    elif git_branch_exists "feature/$branch"; then
        err "branch [feature/$branch] already exists on remote."
        return 1
    fi

    git checkout master && git pull && git checkout develop && git pull || { err "pulling master and/or develop failed. abort." "$FUNCNAME"; return 1; }
    git flow feature start -F "$branch" || { err "starting git feature failed." "$FUNCNAME"; return 1; }
    return $?
}


# git flow feature publish
gffp() {
    [[ "$(get_git_branch)" != feature/* ]] && { err "need to be on a feature branch for this." "$FUNCNAME"; return 1; }
    git flow feature publish
}


# git flow feature finish
gfff() {
    local branch

    [[ -n "$1" ]] && readonly branch="$1" || readonly branch="$(get_git_branch --child)"

    if [[ -z "$branch" ]]; then
        err "need to provide feature branch to finish" "$FUNCNAME"
        return 1
    elif [[ "$branch" == */* ]]; then
        err "there are slashes in the branchname. need to provide the child branch name only, not [feature/...]" "$FUNCNAME"
        return 1
    fi

    git checkout master && git pull && git checkout develop && git pull || { err "pulling master and/or develop failed. abort." "$FUNCNAME"; return 1; }
    git flow feature finish -F "$branch" || { err "finishing git feature failed." "$FUNCNAME"; return 1; }

    # push the merged develop commit:
    #if [[ "$(get_git_branch --child)" == develop ]]; then
    git push || { err "pushing to [$(get_git_branch)] failed." "$FUNCNAME"; return 1; }
    return $?
}


# git flow release start
gfrs() {
    local tag

    readonly tag="$1"

    if [[ -z "$tag" ]]; then
        err "need to provide release tag to create" "$FUNCNAME"
        return 1
    elif [[ "$tag" == */* ]]; then
        err "there are slashes in the tag. need to provide the child tag ver only, not [release/...]" "$FUNCNAME"
        return 1
    elif git_branch_exists "release/$tag"; then
        err "branch [release/$tag] already exists on remote."
        return 1
    elif git_tag_exists "$tag"; then
        err "tag [$tag] already exists."
        return 1
    fi

    glt || { err "unable to find latest tag. not affecting ${FUNCNAME}(), continuing..." "$FUNCNAME"; }

    git checkout master && git pull && git checkout develop && git pull || { err "pulling master and/or develop failed. abort." "$FUNCNAME"; return 1; }
    git flow release start -F "$tag"
    return $?
}


# git flow release finish
gfrf() {
    local tag

    [[ -n "$1" ]] && readonly tag="$1" || readonly tag="$(get_git_branch --child)"

    if [[ -z "$tag" ]]; then
        err "need to provide release tag to finish" "$FUNCNAME"
        return 1
    elif [[ "$tag" == */* ]]; then
        err "there are slashes in the tag. need to provide the child tag ver only, not [release/...]" "$FUNCNAME"
        return 1
    fi

    git flow release finish -F -p "$tag" || { err "finishing git release failed." "$FUNCNAME"; return 1; }
    report "pushing tags..." "$FUNCNAME"
    git push --tags || { err "...pushing tags failed." "$FUNCNAME"; return 1; }

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

    err "ag is not playing along at the moment. see fo()" "$FUNCNAME"
    return 1

    readonly dmenurc="$HOME/.dmenurc"
    readonly editor="$EDITOR"

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


# finds files/dirs using fo() and DELETES them
#
# mnemonic: file open delete
fod() {
    fo --delete "$@"
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
#
# takes optional last arg (digit) to select 2nd, 3rd...nth newest instead.
#
# if no args provided, then searches for '*';
# if no depth arg provided, then defaults to current dir only.
#
# mnemonic: file open new(est)
fon() {
    local opts default_depth n

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

    unset __FILE_OPEN_NEWEST_NTH  # so the state wouldn't be contaminated from the last run

    # try to filter out optional last arg defining the nth newest to open (as in open the nth newest file):
    if [[ "$#" -gt 1 ]]; then
        readonly n="${@: -1}"  # last arg; alternatively ${@:$#}
        if is_digit "$n" && [[ "$n" -ge 1 ]] && [[ "$#" -gt 2 || ! -d "$n" ]]; then  # $# -gt 2   means dir is already being passed to ffind(), so no need to check !isDir
            __FILE_OPEN_NEWEST_NTH="$n"
            set -- "${@:1:${#}-1}"  # shift the last arg
        fi
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


# open file with specified program
#
# program to open file(s) with is to be specified as a last arg
#
# mnemonic: file open with
fow() {
    local opts default_depth prog

    opts="$1"

    readonly default_depth="m10"

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-f${default_depth}"
    fi

    [[ "$#" -le 1 ]] && { err "too few args." "$FUNCNAME"; return 1; }

    # filter out prog name
    readonly prog="${@: -1}"  # last arg; alternatively ${@:$#}
    if ! command -v -- "$prog" >/dev/null; then
        err "[$prog] is not installed." "$FUNCNAME"
        return 1
    fi

    set -- "${@:1:${#}-1}"  # shift the last arg

    [[ -z "$@" ]] && set -- '*'
    #fo --with-prog $opts "$@"  # TODO
}


# collect all found files into global array
foc() {
    local opts default_depth

    opts="$1"

    readonly default_depth="m10"

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-${default_depth}"
    fi

    [[ -z "$@" ]] && set -- '*'
    fo --collect $opts "$@"
}


# finds files/dirs using ffind() (find wrapper) and opens them.
# accepts different 'special modes' to be defined as first arg (modes defined in $special_modes array).
#
# if NOT in special mode, and no args provided, then default to opening regular files in current dir.
#
# mnemonic: file open
fo() {
    local DMENU matches match count filetype dmenurc editor image_viewer video_player file_mngr
    local pdf_viewer nr_of_dmenu_vertical_lines special_mode special_modes single_selection i
    local office image_editor matches_concat

    dmenurc="$HOME/.dmenurc"
    nr_of_dmenu_vertical_lines=20
    readonly special_modes="--goto --openall --newest --collect --delete"  # special mode definitions; mode basically decides how to deal with the found match(es)
    editor="$EDITOR"
    image_viewer="sxiv"
    video_player="smplayer"
    file_mngr="ranger"
    pdf_viewer="zathura"
    office="libreoffice"
    image_editor="gimp"

    list_contains "$1" "$special_modes" && { readonly special_mode="$1"; shift; }
    [[ -z "$@" && -z "$special_mode" ]] && set -- '-fm1' '*'
    [[ -z "$@" ]] && { err "args required for ffind. see ffind -h" "$FUNCNAME"; return 1; }
    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    if [[ "$__REMOTE_SSH" -ne 1 && -z "$special_mode" ]]; then  # only check for progs if not ssh-d AND not using in "special mode"
        check_progs_installed find ffind "$PAGER" "$file_mngr" "$editor" "$image_viewer" \
                "$image_editor" "$video_player" "$pdf_viewer" "$office" dmenu file || return 1
    fi

    # filesearch begins:
    readonly matches_concat="$(ffind --_skip_msgs "$@")" || return 1
    matches=()
    while read i; do
        matches+=( "$i" )
    done < <(echo "$matches_concat")
    [[ -z "${matches[*]}" || ! -e "${matches[0]}" ]] && return 1
    count="${#matches[@]}"

    # logic to select wanted nodes from multiple matches:
    if [[ "$count" -gt 1 ]] && ! list_contains "$special_mode" "--openall --newest --collect --delete"; then
        report "found $count items" "$FUNCNAME"

        if [[ "$__REMOTE_SSH" -eq 1 ]]; then  # TODO: check for $DISPLAY as well perhaps?
            if [[ "$count" -gt 200 ]]; then
                report "no way of using dmenu over ssh; these are the found files:\n" "$FUNCNAME"
                echo -e "${matches[*]}"
                return 0
            fi

            [[ "$special_mode" == --goto ]] && readonly single_selection="--single"

            select_items $single_selection "${matches[@]}"
            matches=("${__SELECTED_ITEMS[@]}")
        else
            matches=()
            while read i; do
                matches+=( "$i" )
            done < <(echo "$matches_concat" | $DMENU -l $nr_of_dmenu_vertical_lines -p open)
        fi

        # TODO: if no items selected, pass the original lot through instead?
        [[ -z "${matches[*]}" ]] && return 1
    fi  # /select from multiple matches
    # /filesearch

    # handle special modes, if any:
    if [[ -n "$special_mode" ]]; then
        case $special_mode in
            --goto)
                goto "${matches[@]}"  # note that for --goto only one item should be allowed to select

                return
                ;;
            --openall)
                true  # fall through
                ;;
            --collect)
                report "found ${#matches[@]} files; stored in \$_FOUND_FILES global array." "$FUNCNAME"
                _FOUND_FILES=("${matches[@]}")

                return
                ;;
            --delete)
                report "found [${#matches[@]}] nodes:" "$FUNCNAME"
                for i in "${matches[@]}"; do
                    echo -e "\t${i}"
                done

                if confirm "wish to DELETE them?"; then
                    rm -r -- "${matches[@]}" || { _FOUND_FILES=("${matches[@]}"); err "something went wrong while deleting. (stored the files in \$_FOUND_FILES array)" "$FUNCNAME"; return 1; }
                fi

                return
                ;;
            --newest)
                check_progs_installed stat head || return 1

                [[ -z "$__FILE_OPEN_NEWEST_NTH" ]] && __FILE_OPEN_NEWEST_NTH=1  # by default, open THE newest
                [[ "$__FILE_OPEN_NEWEST_NTH" -gt "${#matches[@]}" ]] && { err "cannot open [${__FILE_OPEN_NEWEST_NTH}th] newest file, since total nr of found files was [${#matches[@]}]" "$FUNCNAME"; return 1; }
                matches=(
                    $(stat --format='%Y %n' -- "${matches[@]}" \
                        | sort -r -k 1 \
                        | sed -n ${__FILE_OPEN_NEWEST_NTH}p \
                        | cut -d ' ' -f 2- \
                    )
                )
                [[ -f "${matches[*]}" ]] || { err "something went wrong, found newest file [${matches[*]}] is not a valid file." "$FUNCNAME"; return 1; }

                # fall through, do not return!
                ;;
            *) err "unsupported special mode [$special_mode]" "$FUNCNAME"
               return 1
                ;;
        esac
    fi


    count="${#matches[@]}"
    # define filetype only by the first node:
    filetype="$(file -iLb -- "${matches[0]}")" || { err "issues testing [${matches[0]}] with \$ file cmd" "$FUNCNAME"; return 1; }

    # report
    if [[ "$count" -eq 1 ]]; then
        report "opening [${matches[*]}]" "$FUNCNAME"
    else
        report "opening:" "$FUNCNAME"
        for i in "${matches[@]}"; do
            echo -e "\t${i}"
        done
    fi

    case "$filetype" in
        'image/x-xcf; charset=binary')  # xcf is gimp
            "$image_editor" -- "${matches[@]}"
            ;;
        image/*)
            "$image_viewer" -- "${matches[@]}"
            ;;
        application/octet-stream*)
            # should be the logs on app servers
            "$PAGER" -- "${matches[@]}"
            ;;
        application/xml*)
            [[ "$count" -gt 1 ]] && { report "won't format multiple xml files! will just open them" "$FUNCNAME"; sleep 1.5; }
            if [[ "$(wc -l < "${matches[0]}")" -gt 2 || "$count" -gt 1 ]]; then  # note if more than 2 lines we also assume it's already formatted;
                # assuming it's already formatted:
                "$editor" -- "${matches[@]}"
            else
                xmlformat "${matches[@]}"
            fi
            ;;
        video/* | audio/mp4*)
            #"$video_player" -- "${matches[@]}"  # TODO: smplayer doesn't support '--' as per now
            "$video_player" "${matches[@]}"
            ;;
        text/*)
            # if we're dealing with a logfile, force open in PAGER
            if [[ "${matches[0]}" =~ \.log(\.[\.a-z0-9]+)*$ ]]; then
                "$PAGER" -- "${matches[@]}"
            else
                "$editor" -- "${matches[@]}"
            fi
            ;;
        application/pdf*)
            "$pdf_viewer" -- "${matches[@]}"
            ;;
        application/x-elc*)  # TODO: what exactly is it?
            "$editor" -- "${matches[@]}"
            ;;
        'application/x-executable; charset=binary'*)
            [[ "$count" -gt 1 ]] && { report "won't execute multiple files! select one please" "$FUNCNAME"; return 1; }
            confirm "${matches[*]} is executable. want to launch it from here?" || return
            report "launching ${matches[0]}..." "$FUNCNAME"
            ${matches[0]}
            ;;
        'inode/directory;'*)
            [[ "$count" -gt 1 ]] && { report "won't navigate to multiple dirs! select one please" "$FUNCNAME"; return 1; }
            "$file_mngr" -- "${matches[0]}"
            ;;
        'inode/x-empty; charset=binary')  # touched file
            "$editor" -- "${matches[@]}"
            ;;
        # try keeping doc files' definitions in sync with the ones in ffind()
        'application/msword; charset=binary' \
                | 'application/'*'opendocument'*'; charset=binary' \
                | 'application/vnd.ms-office; charset=binary')
            "$office" "${matches[@]}"  # libreoffice doesn't like option ending marker '--'
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

function sethometime() { setspaintime; }  # home is where you make it;

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

    readonly tz="$*"

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
    local path input file match matches pattern DMENU dmenurc msg_loc iname_arg nr_of_dmenu_vertical_lines count i

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

    [[ "$(tolowercase "$pattern")" == "$pattern" ]] && iname_arg="iname"

    matches="$(find -L "$path" -maxdepth 1 -mindepth 1 -type d -${iname_arg:-name} '*'"$pattern"'*')"
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


# dockers
#############################

# consider also https://github.com/spotify/docker-gc
#
# from http://stackoverflow.com/questions/32723111/how-to-remove-old-and-unused-docker-images
function dcleanup() {
    check_progs_installed docker || return 1

    # TODO: don't report err status perhaps? might be ok, which also explains the 2>/dev/nulls;
    docker rm -v $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null || { err "something went wrong with removing exited containers." "$FUNCNAME"; }
    docker rmi $(docker images --filter dangling=true -q 2>/dev/null) 2>/dev/null || { err "something went wrong with removing dangling images." "$FUNCNAME"; }
    # ...and volumes:
    docker volume rm $(docker volume ls -qf dangling=true) || { err "something went wrong with removing dangling volumes." "$FUNCNAME"; }
}


# display available APs and their basic info
function wifi_list() {
    local wifi_device_file

    readonly wifi_device_file="$_WIRELESS_IF"

    [[ -r "$wifi_device_file" ]] || { err "can't read file \"$wifi_device_file\"; probably you have no wireless devices." "$FUNCNAME"; }
    [[ -z "$(cat "$wifi_device_file")" ]] && { err "$wifi_device_file is empty." "$FUNCNAME"; }
    nmcli device wifi list
    return $?
}


function keepsudo() {
    check_progs_installed sudo || return 1

    while true; do
        sudo -n true
        sleep 30
        kill -0 "$$" || exit
    done 2>/dev/null &
}


# transfer.sh alias - file sharing
# see  https://github.com/dutchcoders/transfer.sh/
transfer() {
    local tmpfile file

    readonly file="$1"

    [[ "$#" -ne 1 || -z "$file" ]] && { err "one argument, file to share, required." "$FUNCNAME"; return 1; }
    [[ -e "$file" ]] || { err "[$file] does not exist." "$FUNCNAME"; return 1; }
    check_progs_installed curl || return 1

    # write to output to tmpfile because of progress bar
    readonly tmpfile=$(mktemp -t transfer_XXX.tmp) || { err; return 1; }
    curl --progress-bar --upload-file "$file" "https://transfer.sh/$(basename "$file")" >> "$tmpfile" || { err; return 1; }
    cat -- "$tmpfile"
    copy_to_clipboard "$(cat -- "$tmpfile")" && report "copied link to clipboard" "$FUNCNAME" || err "copying to clipboard failed" "$FUNCNAME"

    rm -f -- "$tmpfile"
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


function mkf() { mkcd "$@"; }  # alias to mkcd

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
mkgif() {
    local input_file output optimized

    readonly input_file="$1"

    readonly output='/tmp/output.gif'
    readonly optimized='/tmp/output_optimized.gif'

    [[ -z "$input_file" ]] && { err "video file to convert to gif required as a param." "$FUNCNAME"; return 1; }
    [[ -f "$input_file" ]] || { err "[$input_file] is not a file" "$FUNCNAME"; return 1; }
    check_progs_installed ffmpeg

    ffmpeg -ss 00:00:00.000 -i "$input_file" -pix_fmt rgb24 -r 10 -s 320x240 -t 00:00:10.000 "$output"
    check_progs_installed convert || { err "convert is not installed; can't optimise final output [$output]" "$FUNCNAME"; return 1; }

    convert -layers Optimize "$output" "$optimized"

    report "final file at [$optimized]" "$FUNCNAME"
}


# also consider running  vokoscreen  instead.
capture() {
    local name screen_dimensions regex dest

    name="$1"

    readonly dest='/tmp'  # dir where recorded file will be written into
    readonly regex='^[0-9]+x[0-9]+$'

    check_progs_installed ffmpeg xdpyinfo || return 1
    [[ "$-" != *i* ]] && return 1  # don't launch if we're not in an interactive shell;
    [[ "$(dirname "$name")" != '.' ]] && { err "please enter only filename, not path; it will be written to [$dest]" "$FUNCNAME"; return 1; }
    [[ -n "$name" ]] && readonly name="$dest/${name}.mkv" || { err "need to provide output filename as first arg (without an extension)." "$FUNCNAME"; return 1; }

    readonly screen_dimensions="$(xdpyinfo | awk '/dimensions:/{printf $2}')" || { err "unable to find screen dimensions via xdpyinfo (exit code $?)" "$FUNCNAME"; return 1; }
    [[ "$screen_dimensions" =~ $regex ]] || { err "found screen dimensions \"$screen_dimensions\" do not conform with validation regex \"$regex\"" "$FUNCNAME"; return 1; }

    #recordmydesktop --display=$DISPLAY --width=1024 height=768 -x=1680 -y=0 --fps=15 --no-sound --delay=10
    #recordmydesktop --display=0 --width=1920 height=1080 --fps=15 --no-sound --delay=10
    ffmpeg -f alsa -ac 2 -i default -framerate 25 -f x11grab -s "$screen_dimensions" -i "$DISPLAY" -acodec pcm_s16le -vcodec libx264 -- "${name}"
    echo
    report "screencap saved at [$name]" "$FUNCNAME"

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


# Copies our public key to clipboard
#
# @returns {void}
function pubkey() {
    local key contents
    readonly key="$HOME/.ssh/id_rsa.pub"

    [[ -f "$key" ]] || { err "$key does not exist" "$FUNCNAME"; return 1; }
    readonly contents="$(cat "$key")" || { err "cat-ing [$key] failed." "$FUNCNAME"; return 1; }

    copy_to_clipboard "$contents" && report "copied pubkey to clipboard" "$FUNCNAME"
    return $?
}


# FZF based functions
# see  https://github.com/junegunn/fzf/wiki/Examples


# fd - cd to selected directory
fd() {
    local dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be source dir." "$FUNCNAME"; return 1; }
    dir=$(find "${src:-.}" -path '*/\.*' -prune \
                    -o -type d -print 2> /dev/null | fzf +m) && cd -- "$dir"
}


# fda - including hidden directories
fda() {
    local dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be source dir." "$FUNCNAME"; return 1; }
    dir=$(find "${src:-.}" -type d 2> /dev/null | fzf +m) && cd -- "$dir"
}


# fdu - cd to selected parent directory
fdu() {
    local dirs dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be source dir." "$FUNCNAME"; return 1; }

    dirs=()
    _get_parent_dirs() {
        if [[ -d "${1}" ]]; then dirs+=("$1"); else return; fi
        if [[ "${1}" == '/' ]]; then
            for _dir in "${dirs[@]}"; do echo $_dir; done
        else
            _get_parent_dirs $(dirname "$1")
        fi
    }

    dir=$(_get_parent_dirs $(realpath "${src:-$(pwd)}") | fzf-tmux --tac)
    cd -- "$dir"

    unset _get_parent_dirs
}


# cdf - cd into the directory of the selected file
# (same as our fog())
cdf() {
    local file dir pattern

    readonly pattern="$1"
    [[ -d "$pattern" ]] && report "fyi, input argument is a search pattern, not source dir" "$FUNCNAME"

    file=$(fzf +m -q "$pattern") && dir=$(dirname -- "$file") && cd -- "$dir"
}


# utility function used to write the command in the shell
__writecmd() {
    perl -e '$TIOCSTI = 0x5412; $l = <STDIN>; $lc = $ARGV[0] eq "-run" ? "\n" : ""; $l =~ s/\s*$/$lc/; map { ioctl STDOUT, $TIOCSTI, $_; } split "", $l;' -- $1
}


# fh - repeat history
# note: no reason to use when ctrl+r mapping works;
# only differing characteristic is that this one executes selected history immediately,
# whereas ctrl+r lets you edit in command line;
fh() {
    [[ "$#" -ne 0 ]] && err "$FUNCNAME does not expect any input" "$FUNCNAME"
    ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -re 's/^\s*[0-9]+\s*//' | __writecmd -run
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


# fbr - checkout git branch (including remote branches)
fbr() {
    local branches branch

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }
    [[ "$#" -ne 0 ]] && err "$FUNCNAME does not expect any input" "$FUNCNAME"

    branches=$(git branch --all | grep -v HEAD) &&
            branch=$(echo "$branches" |
                    fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
            git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}


# fco - checkout git branch/tag
fco() {
    local tags branches target

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }
    [[ "$#" -ne 0 ]] && err "$FUNCNAME does not expect any input" "$FUNCNAME"

    tags=$(
        git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
    branches=$(
        git branch --all | grep -v HEAD             |
        sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
        sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
    target=$(
        (echo "$tags"; echo "$branches") |
        fzf-tmux -l30 -- --no-hscroll --ansi +m -d "\t" -n 2) || return
    git checkout $(echo "$target" | awk '{print $2}')
}


# fcoc - checkout git commit (as in commit hash, not branch et al)
fcoc() {
    local commits commit

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }
    [[ "$#" -ne 0 ]] && err "$FUNCNAME does not expect any input" "$FUNCNAME"

    commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
        commit=$(echo "$commits" | fzf --tac +s +m -e) &&
        git checkout $(echo "$commit" | sed "s/ .*//")
}


# fshow - git commit diff browser
fshow() {
    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    git log --graph --color=always \
        --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
    fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
        --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git difftool --dir-diff %') << 'FZF-EOF'
                {}
FZF-EOF"
}

# fcs - get git commit sha
# example usage: git rebase -i `fcs`
fcs() {
    local commits commit

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    commits=$(git log --color=always --pretty=oneline --abbrev-commit --reverse) &&
    commit=$(echo "$commits" | fzf --tac +s +m -e --ansi --reverse) &&
    commit="${commit%% *}" &&
    copy_to_clipboard "$commit" &&
    echo "copied commit sha [$commit] to clipboard" "$FUNCNAME"
}


# fstash - easier way to deal with stashes
# type fstash to get a list of your stashes
# enter shows you the contents of the stash
# ctrl-d shows a diff of the stash against your current HEAD
# ctrl-b checks the stash out as a branch, for easier merging
fstash() {
    local out q k sha

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    while out=$(
        git stash list --pretty="%C(yellow)%h %>(14)%Cgreen%cr %C(blue)%gs" |
            fzf --ansi --no-sort --query="$q" --print-query \
                --expect=ctrl-d,ctrl-b); do
        mapfile -t out <<< "$out"
        q="${out[0]}"
        k="${out[1]}"
        sha="${out[-1]}"
        sha="${sha%% *}"
        [[ -z "$sha" ]] && continue
        if [[ "$k" == 'ctrl-d' ]]; then
            #git diff "$sha"
            git difftool --dir-diff $sha
        elif [[ "$k" == 'ctrl-b' ]]; then
            report "not using c-b one atm" && return
            git stash branch "stash-$sha" "$sha"
            break;
        else
            #git stash show -p "$sha"
            git difftool --dir-diff "$sha"^ "$sha"
        fi
    done
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
##############################################
unset _MARKPATH  # otherwise we'll use the regular user defined _MARKPATH who changed into su
if [[ "$EUID" -eq 0 ]]; then
    _MARKPATH="$(find $BASE_DATA_DIR /home -mindepth 2 -maxdepth 2 -type d -name $_MARKPATH_DIR -print0 -quit 2>/dev/null)"
    [[ -z "$_MARKPATH" ]] && _MARKPATH="$HOME/$_MARKPATH_DIR"
else
    # if $BASE_DATA_DIR available, try writing it there so it'd be persisted between OS installs:
    [[ -d "$BASE_DATA_DIR" ]] && _MARKPATH="$BASE_DATA_DIR/$_MARKPATH_DIR" || _MARKPATH="$HOME/$_MARKPATH_DIR"
fi

#export _MARKPATH="${_MARKPATH:-$HOME/$_MARKPATH_DIR}"
export _MARKPATH

# jump to mark:
function jj {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in ${_MARKPATH} - dir not existing." "$FUNCNAME"; return 1; }
    cd -P "$_MARKPATH/$1" 2>/dev/null || err "no mark [$1] in [$_MARKPATH]" "$FUNCNAME"
}

# mark:
# pass '-o' as first arg to force overwrite existing target link
function jm {
    local overwrite target

    [[ "$1" == "-o" || "$1" == "--overwrite" ]] && { readonly overwrite=1; shift; }
    readonly target="$_MARKPATH/$1"

    [[ $# -ne 1 || -z "$1" ]] && { err "exactly one arg accepted" "$FUNCNAME"; return 1; }
    [[ -z "$_MARKPATH" ]] && { err "\$_MARKPATH not set, aborting." "$FUNCNAME"; return 1; }
    mkdir -p "$_MARKPATH" || { err "creating [$_MARKPATH] failed." "$FUNCNAME"; return 1; }
    [[ "$overwrite" -eq 1 && -h "$target" ]] && rm "$target" >/dev/null 2>/dev/null
    [[ -h "$target" ]] && { err "[$target] already exists; use jmo or $FUNCNAME -o to overwrite." "$FUNCNAME"; return 1; }

    ln -s "$(pwd)" "$target"
    return $?
}

# mark override:
# mnemonic: jm overwrite
function jmo {
    jm --overwrite "$@"
}

# un-mark:
function jum {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in ${_MARKPATH} - dir not existing." "$FUNCNAME"; return 1; }
    rm -i "$_MARKPATH/$1"
}

# list all saved marks:
function jjj {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in ${_MARKPATH} - dir not existing." "$FUNCNAME"; return 1; }
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

