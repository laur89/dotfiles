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
        echo -e "\n    ERROR: common file [$_SCRIPTS_COMMONS] not found!! Many functions will be unusable!!!"
        # !do not exit, or you won't be able to open shell
        # without the commons file being present!
    fi
fi
# =====================================================================

# gnu find wrapper.
# find files or dirs based on name or type
ffind() {
    local src srcdir iname_arg opt usage OPTIND file_type filetypeOptionCounter exact filetype follow_links
    local maxDepth maxDepthParam pathOpt regex defMaxDeptWithFollowLinks force_case caseOptCounter skip_msgs
    local quitFlag filetype_regex extra_params matches i delete deleteFlag printFlag

    __filter_for_filetype() {
        local filetype index

        [[ -z "${matches[*]}" ]] && return 1
        [[ -z "$filetype_regex" ]] && { err "[\$filetype_regex] not defined." "$FUNCNAME"; return 1; }
        index=0

        while IFS= read -r filetype; do
            if [[ "$filetype" =~ $filetype_regex ]]; then
                if [[ "$skip_msgs" -eq 1 ]]; then
                    printf '%s\0' "${matches[index]}"
                else
                    # trailing grep is for coloring only:
                    echo "${matches[index]}" | grep -iE --color=auto -- "$src|$"
                fi
            fi

            let index++
        done < <(file -iLb --print0 -- "${matches[@]}" || { err_display "file cmd returned [$?] @ $FUNCNAME" "${FUNCNAME[1]}"; return 1; })
    }

    __find_fun() {
        local wildcard

        # note exact and regex are mutually exclusive
        [[ "$exact" -eq 1 ]] || wildcard='*'
        [[ "$regex" -eq 1 ]] && wildcard='.*'
        [[ "$src" == '*' || "$src" == '.*' ]] && unset src

        if [[ -n "$src" ]]; then
            find $follow_links "${srcdir:-.}" $maxDepthParam $file_type ${iname_arg:--name} "$wildcard$src$wildcard" $extra_params $printFlag $quitFlag $deleteFlag 2>/dev/null
        else
            find $follow_links "${srcdir:-.}" $maxDepthParam $file_type $extra_params $printFlag $quitFlag $deleteFlag 2>/dev/null
        fi
    }

    [[ "$1" == --_skip_msgs ]] && { skip_msgs=1; shift; printFlag='-print0'; } || printFlag='-print'  # skip showing informative messages, as the result will be directly echoed to other processes;
                                                                                                      # also denotes that caller is a script not a human, and results should be null-separated;
    readonly defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) is selected;

    readonly usage="\n$FUNCNAME: find files/dirs by name. smartcase.

    Usage: $FUNCNAME  [options]  [fileName pattern]  [top_level_dir_to_search_from]

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
        -e  search for exact filename, not for a partial (you still can use wildcards)
        -p  expand the pattern search for path as well (adds the -path option);
            might want to consider regex, that also searches across the whole path;
        -0  null-terminated output."

    filetypeOptionCounter=0
    caseOptCounter=0
    matches=()

    while getopts "m:isrefdlbLDqphVPIC0" opt; do
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
              readonly filetype_regex='x-executable; charset=binary'
              shift $((OPTIND-1))
                ;;
           V) readonly filetype=1
              extra_params='-size +100M'  # search for min. x megs files, so mp4 wouldn't (likely) return audio files
              readonly filetype_regex='video/|audio/mp4'
              shift $((OPTIND-1))
                ;;
           P) readonly filetype=1
              readonly filetype_regex='application/pdf; charset=binary'
              shift $((OPTIND-1))
                ;;
           I) readonly filetype=1
              readonly filetype_regex='image/\w+; charset=binary'
              shift $((OPTIND-1))
                ;;
           C)  # for doC
              readonly filetype=1
              shift $((OPTIND-1))

              # try keeping doc files' definitions in sync with the ones in __fo()
              # no linebreaks in regex!
              readonly filetype_regex='application/msword; charset=binary|application/.*opendocument.*; charset=binary|application/.*ms-office; charset=binary|application/.*ms-excel; charset=binary'
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
           D) readonly delete=1     # to include nonempty dirs as well, run     find . -name "3" -type d -exec rm -rf {} +
              readonly deleteFlag='-delete'
              shift $((OPTIND-1))
                ;;
           0) printFlag='-print0'
              shift $((OPTIND-1))
                ;;
           *) echo -e "$usage"
              [[ "$skip_msgs" -eq 1 ]] && return 9 || return 1
                ;;
        esac
    done

    if [[ "$#" -eq 1 && -d "$1" && "$1" == */* ]]; then
        srcdir="$1"
        [[ "$skip_msgs" -ne 1 ]] && { report "assuming starting dir [$srcdir] was given" "$FUNCNAME"; sleep 2; }
    else
        src="$1"
        srcdir="$2"  # optional
    fi

    if [[ "$#" -gt 2 ]]; then
        err "incorrect nr of aguments; max 2 allowed." "$FUNCNAME"
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
        err "-D and filetype (eg -V) flags are exclusive." "$FUNCNAME"  # because find executes before filetype filter
        echo -e "$usage"
        return 1
    elif [[ "$delete" -eq 1 && -z "$src" ]] && ! confirm "wish to delete ALL nodes? note you haven't defined filename pattern to search, so everything gets returned."; then
        return
    elif [[ "$delete" -eq 1 && -n "$src" ]] && ! confirm "wish to delete nodes that match [$src]?"; then
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
            err "provided directory to search from [$srcdir] is not a directory. abort." "$FUNCNAME"
            return 1
        elif [[ "$srcdir" != */ ]]; then
            srcdir="${srcdir}/"  # add trailing slash if missing; required for gnu find; necessary in case it's a link and -L was not defined.
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
        if ! is_digit "$maxDepth" || [[ "$maxDepth" -le 0 ]]; then
            err "maxdepth (the -m flag) arg value has to be a positive digit, but was [$maxDepth]" "$FUNCNAME"
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
        iname_arg="-regextype posix-extended -${iname_arg:+i}regex"
    fi

    if [[ "$filetype" -eq 1 ]]; then
        printFlag='-print0'
        while IFS= read -r -d $'\0' i; do
            matches+=( "$i" )
        done < <(__find_fun)

        __filter_for_filetype
    elif [[ "$skip_msgs" -eq 1 ]]; then
        __find_fun
    else
        # trailing grep is for coloring only:
        __find_fun | grep -iE --color=auto -- "$src|$"
    fi

    unset __filter_for_filetype __find_fun
}

# Find a file with a pattern in name (inside wd);
# essentially same as ffind(), but a bit simplified:
#function ff() {
    #find . -type f -iname '*'"$*"'*'  -ls
#}

ffindproc() {
    [[ -z "$1" ]] && { err "process name required" "$FUNCNAME"; return 1; }
    # last grep for re-coloring:
    ps -ef | grep -v '\bgrep\b' | grep -i --color=auto -- "$1"

    # TODO: add also exact match option?:
    #   grep '\$1\b'
}

# find top 5/x biggest or smallest nodes:
__find_top_big_small_fun() {
    local usage opt OPTIND itemsToShow file_type maxDepthParam maxDepth follow_links reverse du_size_unit
    local bigOrSmall du_include_regular_files duMaxDepthParam filetypeOptionCounter i

    du_size_unit="$1"  # default unit provided by the invoker (can be overridden)
    bigOrSmall="$2"
    itemsToShow="$3"   # default top number of items displayed
    shift 3

    filetypeOptionCounter=0

    usage="\n${FUNCNAME[1]}: find top $bigOrSmall nodes from current dir.\nif node type not specified, defaults to searching for everything.\n
    Usage: ${FUNCNAME[1]}  [-f] [-d] [-L] [-m depth]  [nr_of_top_items_to_show]  [block_size_unit]
        -f  search only for regular files
        -d  search only for directories
        -L  follow/dereference symlinks
        -m<digit>   max depth to descend; unlimited by default.

        note that optional  args [nr_of_top_items_to_show]  and  [block_size_unit]  can be
        given in either order.

        examples:
            ${FUNCNAME[1]} 20       - seek top 20 $bigOrSmall files and dirs;
            ${FUNCNAME[1]} -f 15 G  - seek top 15 $bigOrSmall files and present their sizes in gigas;
            ${FUNCNAME[1]} -f G 15  - same as previous;
            ${FUNCNAME[1]} -dm3 K   - seek top $bigOrSmall dirs and present their sizes
                                   in kilos; descend up to 3 levels from current dir.
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
           *) echo -e "$usage"; return 1 ;;
        esac
    done


    if [[ "$#" -gt 2 ]]; then
        err "maximum of 2 args are allowed" "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi

    # parse optional args:
    for i in "$@"; do
        if is_digit "$i"; then
            [[ "$i" -le 0 ]] && { err "something larger than 0 would make sense." "${FUNCNAME[1]}"; return 1; }
            itemsToShow="$i"
        else
            du_size_unit="$i"
        fi
    done

    if ! [[ "$du_size_unit" =~ ^[KMGTPEZYB]$ ]]; then
        err "unsupported du block size unit: [$du_size_unit]" "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth"; then
            err "maxdepth arg value has to be... y'know, a digit" "${FUNCNAME[1]}"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="-maxdepth $maxDepth"
        duMaxDepthParam="--max-depth=$maxDepth"
    fi

    if [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f and -d flags are exclusive." "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi

    # invoker sanity: (and define whether sort output should be reversed)
    case "$bigOrSmall" in
        small)
            true
            ;;
        large)
            reverse='-r'
            ;;
        *)
            err "could not detect whether we should look for top big or small files" "$FUNCNAME"
            return 1
            ;;
    esac

    report "seeking for top $itemsToShow $bigOrSmall files (in $du_size_unit units)...\n" "${FUNCNAME[1]}"

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

ffindtopbig() {
    __find_top_big_small_fun "M" "large" 10 "$@"
}

ffindtopsmall() {
    #find . -type f -exec ls -s --block-size=K {} \; | sort -n | head -$itemsToShow 2>/dev/null
    __find_top_big_small_fun "K" "small" 10 "$@"
}

# find smaller/bigger than Xmegas files
__find_bigger_smaller_common_fun() {
    local usage opt OPTIND file_type maxDepthParam maxDepth follow_links reverse du_size_unit biggerOrSmaller sizeArg
    local du_include_regular_files duMaxDepthParam plusOrMinus filetypeOptionCounter sizeArgLastChar du_blk_sz find_size_unit

    du_size_unit="$1"     # default unit provided by the invoker
    biggerOrSmaller="$2"  # denotes whether larger or smaller than X size units were queried
    shift 2

    filetypeOptionCounter=0

    if ! [[ "$du_size_unit" =~ ^[KMGTPEZYB]$ ]]; then
        err "unsupported du block size unit: [$du_size_unit]" "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi

    usage="\n${FUNCNAME[1]}: find nodes $biggerOrSmaller than X $du_size_unit from current dir.\nif node type not specified, defaults to searching for everything.\n
    Usage: ${FUNCNAME[1]}  [-f] [-d] [-L] [-m depth]  base_size_in_[du_size_unit]

        the [du_size_unit] can be any of [KMGTPEZYB]; if not provided, defaults to $du_size_unit.
        ('B' is for bytes; KB, MB etc for base 1000 not supported)

        -f  search only for regular files
        -d  search only for directories
        -L  follow/dereference symlinks
        -m<digit>   max depth to descend; unlimited by default.

        examples:
            ${FUNCNAME[1]} 300       - seek files and dirs $biggerOrSmaller than 300 default
                                        du_size_units, which is $du_size_unit;
            ${FUNCNAME[1]} -f 12G    - seek files $biggerOrSmaller than 12 gigs;
            ${FUNCNAME[1]} -dm3 12K  - seek dirs $biggerOrSmaller than 12 kilobytes;
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
        err "exactly one arg required" "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth" || [[ "$maxDepth" -le 0 ]]; then
            err "maxdepth arg value has to be... y'know, a digit" "${FUNCNAME[1]}"
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
            if ! [[ "$sizeArgLastChar" =~ ^[KMGTPEZYB]$ ]]; then
                err "unsupported du block size unit provided: [$sizeArgLastChar]" "${FUNCNAME[1]}"
                return 1
            fi

            # override du_size_unit defined by the invoker:
            du_size_unit="$sizeArgLastChar"
            # clean up the numeric sizeArg:
            sizeArg="${sizeArg:0:$(( ${#sizeArg} - 1))}"
        fi

        if [[ -z "$sizeArg" ]]; then
            err "base size has to be provided as well, not only the unit." "${FUNCNAME[1]}"
            echo -e "$usage"
            return 1
        elif ! is_digit "$sizeArg"; then
            err "base size has to be a positive digit, but was [$sizeArg]." "${FUNCNAME[1]}"
            echo -e "$usage"
            return 1
        fi
    else
        #sizeArg=5
        err "need to provide base size in $du_size_unit" "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi

    if [[ "$filetypeOptionCounter" -gt 1 ]]; then
        err "-f and -d flags are exclusive." "${FUNCNAME[1]}"
        echo -e "$usage"
        return 1
    fi


    # invoker sanity: (and +/- definition for find -size and du --threshold args)
    case "$biggerOrSmaller" in
        smaller)
            plusOrMinus='-'
            ;;
        bigger)
            plusOrMinus='+'
            reverse='-r'
            ;;
        *)
            err "could not detect whether we should look for smaller or larger than ${sizeArg}$du_size_unit files" "$FUNCNAME"
            return 1
            ;;
    esac

    report "seeking for files $biggerOrSmaller than ${sizeArg}${du_size_unit}...\n" "${FUNCNAME[1]}"

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
            err "unsupported block size unit for find: [$find_size_unit]. refer to man find and search for [-size]" "${FUNCNAME[1]}"
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
        #if [[ "$biggerOrSmaller" == "smaller" ]]; then  # meaning that ffindsmallerthan function was invoker
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

        du $follow_links $du_include_regular_files $du_blk_sz $duMaxDepthParam \
                --threshold=${plusOrMinus}${sizeArg}${du_size_unit} 2>/dev/null | \
                sort -n $reverse
    fi
}

# find  nodes bigger than x mb:
ffindbiggerthan() {
    #find . -size +${size}M -exec ls -s --block-size=M {} \; | sort -nr 2>/dev/null
    __find_bigger_smaller_common_fun "M" "bigger" "$@"
}

# find  nodes smaller than x mb:
ffindsmallerthan() {
    #find . -size -${size}M -exec ls -s --block-size=M {} \; | sort -n 2>/dev/null
    __find_bigger_smaller_common_fun "M" "smaller" "$@"
}

aptsearch() {
    [[ -z "$@" ]] && { err "provide partial package name to search for." "$FUNCNAME"; return 1; }
    check_progs_installed apt-cache || return 1

    apt-cache search -- "$@"
    #aptitude search -- "$@"
}

aptsrc() { aptsearch "$@"; }  # alias

aptreset() {
    local apt_lists_dir

    readonly apt_lists_dir="/var/lib/apt/lists"

    report "note that sudo passwd is required" "$FUNCNAME"

    if [[ -d "$apt_lists_dir" ]]; then
        report "deleting contents of $apt_lists_dir" "$FUNCNAME"
        sudo rm -rf $apt_lists_dir/*
    else
        err "[$apt_lists_dir] is not a dir; can't delete the contents in it." "$FUNCNAME"
    fi

    report "running apt-get clean..." "$FUNCNAME"
    sudo apt-get clean
    #sudo apt-get update
    #sudo apt-get upgrade
}

aptclean() { aptreset; }

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of grep).
# !!! deprecated by ag/astr
# TODO: find whether we could stop using find here and use grep --include & --exclude flags instead.
ffstr() {
    local grepcase OPTIND usage opt max_result_line_length caseOptCounter force_case regex i
    local iname_arg maxDepth maxDepthParam defMaxDeptWithFollowLinks follow_links
    local pattern file_pattern collect_files open_files dir

    caseOptCounter=0
    OPTIND=1
    max_result_line_length=300      # max nr of characters per grep result line
    defMaxDeptWithFollowLinks=25    # default depth if depth not provided AND follow links (-L) option selected;

    readonly usage="\n$FUNCNAME: find string in files. smartcase both for filename and search patterns.
    Usage: $FUNCNAME  [opts]  \"pattern\"  [filename pattern]  [starting dir]
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
              collect_files=1  # so we can use the collected array
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

    if [[ "$#" -eq 3 && ! -d "${@: -1}" ]]; then
        err "last arg can only be starting dir" "$FUNCNAME"
        return 1
    elif [[ "$#" -gt 1 ]]; then
        i="${@: -1}"  # last arg; alternatively ${@:$#}
        if [[ -d "$i" ]]; then
            [[ "$#" -lt 3 ]] && report "assuming starting path [$i] was given\n" "$FUNCNAME" && sleep 1.5  # if less than 3 args, we need to assume
            dir="$i"
            set -- "${@:1:${#}-1}"  # shift the last arg
        fi
        unset i
    fi

    pattern="$1"
    file_pattern="$2"

    if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
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
            err "there are slashes in the filename." "$FUNCNAME"
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
        else  # no regex, make sure find metacharacters are not mistaken for regex ones:
            if [[ "$file_pattern" == *\.\** ]]; then
                err "err in filename pattern: only use asterisks (*) for wildcards, not .*; provide -r flag if you want to use regex." "$FUNCNAME"
                return 1
            fi

            if [[ "$file_pattern" == *\.* ]]; then
                report "note that period (.) in the filename pattern will be used as a literal period, not as a wildcard. provide -r flag to use regex.\n" "$FUNCNAME"
            fi
        fi
    elif [[ "$regex" -eq 1 ]]; then  # -z $file_pattern
        err "with -r flag, filename pattern is required." "$FUNCNAME"
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth" || [[ "$maxDepth" -le 0 ]]; then
            err "maxdepth (the -m flag) arg value has to be a positive digit, but was [$maxDepth]" "$FUNCNAME"
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

    __find_fun() {
        local wildcard

        wildcard='*'

        # note exact and regex are mutually exclusive
        if [[ "$regex" -eq 1 ]]; then
            wildcard='.*'
            iname_arg="-regextype posix-extended -${iname_arg:+i}regex"
        fi
        [[ "$file_pattern" == '*' || "$file_pattern" == '.*' ]] && unset file_pattern

        if [[ -n "$file_pattern" ]]; then
            find $follow_links ${dir:-.} $maxDepthParam -type f "${iname_arg:--name}" "${wildcard}${file_pattern}${wildcard}" -print0 2>/dev/null
        else
            find $follow_links ${dir:-.} $maxDepthParam -type f -print0 2>/dev/null
        fi
        # TODO: convert to  'find . -name "$ext" -type f -exec grep "$pattern" /dev/null {} +' perhaps?
    }

    if [[ "$collect_files" -eq 1 ]]; then
        _FOUND_FILES=()
        while IFS= read -r -d $'\0' i; do
            _FOUND_FILES+=("$i")
        done < <(__find_fun | xargs -0 grep -Esl --null --color=never ${grepcase} -- "$pattern")

        report "found ${#_FOUND_FILES[@]} files containing [$pattern]; stored in \$_FOUND_FILES global array." "$FUNCNAME"
        [[ "${#_FOUND_FILES[@]}" -eq 0 ]] && return 1

        [[ "$open_files" -eq 1 ]] && __fo "${_FOUND_FILES[@]}"
    else
        __find_fun | \
            xargs -0 grep -Esn --color=always --with-filename -m 1 ${grepcase} -- "$pattern" | \
            cut -c 1-$max_result_line_length | \
            more
            #less
        #__find_fun | \
            #xargs -P10 -n20 -0 grep --line-buffered -Esn --color=always --with-filename -m 1 $grepcase -- "$pattern" | \
            #cut -c 1-$max_result_line_length | \
            #more
     fi

    unset __find_fun
}

memmost(){
    # $1: number of process to view (default 10).
    local num

    readonly num=${1:-10}

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 4 | head -n $num
}


cpumost(){
    # $1: number of process to view (default 10).

    local num=$1
    [ "$num" == "" ] && num="10"

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 3 | head -n $num
}

cpugt(){
    # $1: percentage of cpu. Default 90%

    local perc=$1
    [ "$perc" == "" ] && perc="90"

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 3 | awk -v "q=$perc" '($3>=q){print $0}'
}

memgt(){
    # $1: percentage of memory. Default 90%

    local perc=$1
    [ "$perc" == "" ] && perc="90"

    local ps_out=$(ps -auxf)
    echo "$ps_out" | head -n 1
    echo "$ps_out" | sort -nr -k 4 | awk -v "q=$perc" '($4>=q){print $0}'
}


touser(){
    # $1: name of the user
    ps -U $1 -u $1 u
}

frompid(){
    # $1: PID of the process
    ps -p $1 -o comm=
}


topid(){
    # $1: name of the process
    ps -C $1 -o pid=
}


astr() {
    local grepcase OPTIND usage opt file_pattern caseOptCounter maxDepth follow_links
    local pattern defMaxDeptWithFollowLinks dir i

    readonly defMaxDeptWithFollowLinks=25
    OPTIND=1
    caseOptCounter=0
    readonly usage="\n$FUNCNAME: find string in files using ag. smartcase by default.
    Usage: $FUNCNAME [options]  \"pattern\"  [filename pattern]  [starting dir]
        -i  force case insensitive
        -s  force case sensitivity
        -L  follow symlinks
        -m<digit>   max depth to descend; unlimited by default, but limited to $defMaxDeptWithFollowLinks if -L opt selected;"

    check_progs_installed ag
    report "consider using ag directly; it has really sane syntax (compared to find + grep)
      for instance, with this wrapper you can't use the filetype & path options.\n" "$FUNCNAME"

    while getopts "isLhm:" opt; do
        case "$opt" in
           i) grepcase=" -i "
              caseOptCounter+=1
              shift $(( $OPTIND - 1 ))
              ;;
           s) grepcase=" -s "
              caseOptCounter+=1
              shift $((OPTIND-1))
                ;;
           m) maxDepth="$OPTARG"
              shift $((OPTIND-1))
                ;;
           L) follow_links="--follow"
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

    if [[ "$#" -eq 3 && ! -d "${@: -1}" ]]; then
        err "last arg can only be starting dir" "$FUNCNAME"
        return 1
    elif [[ "$#" -gt 1 ]]; then
        i="${@: -1}"  # last arg; alternatively ${@:$#}
        if [[ -d "$i" ]]; then
            [[ "$#" -lt 3 ]] && report "assuming starting path [$i] was given" "$FUNCNAME"  # if less than 3 args, we need to assume
            dir="$i"
            set -- "${@:1:${#}-1}"  # shift the last arg
        fi
        unset i
    fi

    pattern="$1"
    file_pattern="$2"

    if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
        err "incorrect nr of arguments." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$caseOptCounter" -gt 1 ]]; then
        err "-i and -s flags are exclusive." "$FUNCNAME"
        echo -e "$usage"
        return 1
    fi

    if [[ -n "$maxDepth" ]]; then
        if ! is_digit "$maxDepth" || [[ "$maxDepth" -le 0 ]]; then
            err "maxdepth (the -m flag) arg value has to be a positive digit, but was [$maxDepth]" "$FUNCNAME"
            echo -e "$usage"
            return 1
        fi

        maxDepthParam="--depth $maxDepth"
    elif [[ -n "$follow_links" ]]; then
        maxDepthParam="--depth $defMaxDeptWithFollowLinks"
    fi

    # regex sanity:
    if [[ "$@" == *\** && "$@" != *\.\** ]]; then
        err "use .* as wildcards, not a single *" "$FUNCNAME"
        return 1
    elif [[ "$(echo "$@" | tr -dc '.' | wc -m)" -lt "$(echo "$@" | tr -dc '*' | wc -m)" ]]; then
        err "nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
        return 1
    fi

    if [[ -n "$file_pattern" ]]; then
        if [[ "$file_pattern" == */* ]]; then
            err "there are slashes in the filename." "$FUNCNAME"
            return 1
        elif [[ "$file_pattern" == *\ * ]]; then
            err "there is whitespace in the filename." "$FUNCNAME"
            return 1
        fi
        file_pattern="-G $file_pattern"
    fi

    ag $follow_links $maxDepthParam $file_pattern $grepcase -- "$pattern" $dir 2>/dev/null
}


# Swap 2 files around, if they exist (from Uzi's bashrc):
swap() {
    local tmp file_size space_left_on_target first_file sec_file i

    tmp="/tmp/${FUNCNAME}_function_tmpFile.$RANDOM"
    first_file="${1%/}"  # strip trailing slash
    sec_file="${2%/}"    # strip trailing slash

    [[ "$#" -ne 2 ]] && { err "2 args required" "$FUNCNAME"; return 1; }
    [[ ! -e "$first_file" ]] && err "[$first_file] does not exist" "$FUNCNAME" && return 1
    [[ ! -e "$sec_file" ]] && err "[$sec_file] does not exist" "$FUNCNAME" && return 1
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
        mv -- "$first_file" "$sec_file"
        mv -- "$tmp" "$first_file"
        return 1
    fi
}

# list current directory and search for a file/dir by name:
lgrep() {
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
        [[ "$src" == *\.\** ]] && { err "only use asterisks (*) for wildcards, not .*" "$FUNCNAME"; return 1; }
        find "${srcdir:-.}" -maxdepth 1 -mindepth 1 -name "$src" -printf '%f\n' | grep -iE --color=auto "$src|$"
    else
        ls -lA "${srcdir:-.}" | grep --color=auto -i -- "$src"
        #find "${srcdir:-.}" -maxdepth 1 -mindepth 1 -iname '*'"$src"'*' -printf '%f\n' | grep -iE --color=auto "$src|$"
    fi
}


# search for shell command history
histgrep() {
    err "deprecated; use fh()"; return 1;
}


# Make your directories and files access rights sane.
# (sane as in rw for owner, r for group, none for others)
sanitize() {
    [[ -z "$@" ]] && { err "provide a file/dir name plz." "$FUNCNAME"; return 1; }
    [[ ! -e "$@" ]] && { err "[$*] does not exist." "$FUNCNAME"; return 1; }
    chmod -R u=rwX,g=rX,o= -- "$@";
}

# TODO: stop accepting args and hardcode to ~/.ssh?
sanitize_ssh() {
    local node="$*"

    [[ -z "$node" ]] && { err "provide a file/dir name plz. (most likely you want the .ssh dir)" "$FUNCNAME"; return 1; }
    [[ ! -e "$node" ]] && { err "[$node] does not exist." "$FUNCNAME"; return 1; }
    if [[ "$node" != *ssh*  ]]; then
        confirm  "\nthe node name you're about to $FUNCNAME does not contain string [ssh]; still continue? (y/n)" || return 1
    fi

    chmod -R u=rwX,g=,o= -- "$node";
}

ssh_sanitize() { sanitize_ssh "$@"; }  # alias for sanitize_ssh

myip() {  # Get internal & external ip addies:
    local connected_interface interfaces if_dir interface external_ip

    if_dir="/sys/class/net"

    __get_internal_ip_for_if() {
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
            while IFS= read -r -d $'\0' interface; do
                # filter out blacklisted interfaces:
                list_contains "$interface" "lo loopback" || interfaces+=" $interface "
            done < <(find "$if_dir" -maxdepth 1 -mindepth 1 -print0)

            # old solution:
            #interfaces="$(ls "$if_dir")"
        else
            interfaces="eth0 eth1 eth2 eth3"
            report "can't read interfaces from [$if_dir] [not a (readable) dir]; trying these interfaces: [$interfaces]" "$FUNCNAME"
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

whatsmyip() { myip; }  # alias for myip

# !! lrzip might offer best compression when it comes to text: http://unix.stackexchange.com/questions/78262/which-file-compression-software-for-linux-offers-the-highest-size-reduction
compress() {
    local usage file type opt

    file="$1"
    type="$2"
    readonly usage="$FUNCNAME  fileOrDir  [zip|tar|rar|7z]\n\tif optional second arg not provided, compression type defaults to tar (tar.bz2) "

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
    [[ -z "$type" ]] && { report "no compression type selected, defaulting to tar.bz2\n" "$FUNCNAME"; type="tar"; }  # default to tar

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

pack() { compress "$@"; }  # alias for compress

# Creates an archive (*.tar.gz) from given directory.
maketar() { tar cvzf "${1%%/}.tar.gz" -- "${1%%/}/"; }

# Creates an archive (*.tar.bz2) from given directory.
# j - use bzip2 compression rather than z option  (heavier compression)
maketar2() { tar cvjf "${1%%/}.tar.bz2" -- "${1%%/}/"; }

# Create a rar archive.
# -m# - compresson lvl, 5 being max level, 0 just storage;
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

# helper wrapper for uncompressing archives. it uncompresses into new directory, which
# name is the same as the archive's, minus the file extension. this avoids the situations
# where gazillion files are being extracted into workin dir. note that if the dir
# already exists, then unpacking fails (since mkdir fails).
extract() {
    local file="$*"
    local file_without_extension="${file%.*}"
    #file_extension="${file##*.}"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz." "$FUNCNAME"
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "[$file] is not a regular file or read rights not granted." "$FUNCNAME"
        return 1
    fi

    case "$file" in
        *.tar.bz2)   file_without_extension="${file_without_extension%.*}"  # because two extensions
                        mkdir -- "$file_without_extension" && tar xjf "$file" -C "$file_without_extension"
                        ;;
        *.tar.gz)    file_without_extension="${file_without_extension%.*}"  # because two extensions
                        mkdir -- "$file_without_extension" && tar xzf "$file" -C "$file_without_extension"
                        ;;
        *.tar.xz)    file_without_extension="${file_without_extension%.*}"  # because two extensions
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
        *)           err "[$file] cannot be extracted; this filetype is not supported." "$FUNCNAME"
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
    is_digit "$1" && limit=$1 || limit=1
    for ((i=1; i <= limit; i++)); do
        d="$d/.."
    done
    d="$(echo "$d" | sed 's/^\///')"

    cd -- "$d"
}

# clock - A bash clock that can run in your terminal window:
clock() {
    while true; do
        clear
        printf "==========\n %s\n==========" "$(date +'%R:%S')"
        sleep 1
    done
}

# format xml into readable shape:
#    xmlformat file1 [file2...]
#    xmlformat '<xml> unformatted </xml>'
xmlformat() {
    local file regex result

    readonly regex='^\s*<'
    [[ -z "$@" ]] && { echo -e "usage:   $FUNCNAME  <filename>  OR  $FUNCNAME  'raw xml string'"; return 1; }
    check_progs_installed xmllint "$EDITOR" || return 1;

    if [[ "$#" -eq 1 && ! -f "$*" && "$*" =~ $regex ]]; then
        result="$(echo "$*" | xmllint --format -)" || { err "formatting input xml failed" "$FUNCNAME"; return 1; }
        echo
        echo "$result"
        echo
        copy_to_clipboard "$result" && report "formatted xml is on clipboard" "$FUNCNAME"
        return 0
    fi

    for file in "$@"; do
        [[ -f "$file" && -r "$file" ]] || { err "provided file [$file] is not a regular file or is not readable. abort." "$FUNCNAME"; return 1; }
    done

    xmllint --format "$@" | "$EDITOR"  "+set foldlevel=99" -;
}

xmlf() { xmlformat "$@"; }  # alias for xmlformat;

createUsbIso() {
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
    readonly device="${2%/}"  # strip trailing slash

    readonly cleaned_devicename="${device##*/}"  # strip everything before last slash (slash included)

    if [[ -z "$file" || -z "$device" || -z "$cleaned_devicename" ]]; then
        err "either file or device weren't provided" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ ! -f "$file" && "$reverse" -ne 1 ]]; then
        err "[$file] is not a regular file" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ -f "$file" && "$reverse" -eq 1 ]]; then
        err "[$file] already exists. choose another file to write into, or delete it." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ "$reverse" -eq 1 && ! -d "$(dirname "$file")" ]]; then
        err "[$file] doesn't appear to be defined on a valid path. please check." "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif [[ ! -e "$device" ]]; then
        err "[$device] device does not exist" "$FUNCNAME"
        echo -e "$usage"
        return 1;
    elif ! find /dev -name "$cleaned_devicename" -print0 -quit 2> /dev/null | grep -q .; then
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

    confirm  "\nis selected device [$device] the correct one? (y/n)" || { report "aborting, nothing written." "$FUNCNAME"; return 1; }

    # find if device is mounted:
    #lsblk -o name,size,mountpoint /dev/sda
    report "unmounting [$cleaned_devicename] partitions... (may ask for sudo password)"
    for partition in ${device}* ; do
        echo "$full_lsblk_output" | grep -Eq "${partition##*/}\b" || continue  # not all partitions are listed by lsblk; dunno what's with that

        mountpoint="$(lsblk -o mountpoint -- "$partition")" || { err "some issue occurred running [lsblk -o mountpoint ${partition}]" "$FUNCNAME"; return 1; }
        mountpoint="$(echo "$mountpoint" | sed -n 2p)"
        if [[ -n "$mountpoint" ]]; then
            report "[$partition] appears to be mounted at [$mountpoint], trying to unmount..." "$FUNCNAME"
            if ! sudo umount "$mountpoint"; then
                err "something went wrong while unmounting [$mountpoint]. please unmount the device and try again." "$FUNCNAME"
                return 1
            fi
            report "...success." "$FUNCNAME"
        fi
    done

    [[ "$reverse" -eq 1 ]] && { inf="$device"; ouf="$file"; } || { inf="$file"; ouf="$device"; }

    echo
    confirm "last confirmation: wish to write [$inf] into [$ouf]?" || { report "aborting." "$FUNCNAME"; return 1; }
    report "Please provide sudo passwd for running dd:" "$FUNCNAME"
    sudo echo
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
mkgit() {
    local user passwd repo dir project_name OPTIND opt usage mainOptCounter http_statuscode
    local newly_created_dir curl_output namespace_id

    mainOptCounter=0
    readonly usage="usage:   $FUNCNAME  -g|-b|-w  <dirname> [project_name]
           -g   create repo in github
           -b   create repo in bitbucket
           -w   create repo in work (not supported as of now)

     if  [project_name]  is not given, then project name will be same as  <dirname>"

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
           w) user="laliste"
              repo="$(getnetrc "${user}@git.url.workplace")"
              let mainOptCounter+=1
              shift $((OPTIND-1))
              ;;
           *) echo -e "$usage";
              return 1
              ;;
        esac
    done

    readonly dir="${1%/}"  # strip trailing slash
    readonly project_name="${2:-$dir}"  # default to dir name

    readonly curl_output="/tmp/curl_create_repo_output_${RANDOM}.out"

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
    elif ! check_progs_installed git getnetrc curl jq; then
        return 1
    elif [[ -z "$dir" ]]; then
        err "need to provide dirname at minimum" "$FUNCNAME"
        echo -e "$usage"
        return 1
    elif [[ -d "$dir/.git" ]]; then
        err "[$dir] is already a git repo. abort." "$FUNCNAME"
        return 1
    elif is_git; then
        err "you're already in a git project; don't nest them." "$FUNCNAME"
        return 1
    elif [[ "$project_name" == */* ]]; then
        err "project name [$project_name] contains slashes." "$FUNCNAME"
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

    # offers user to choose the namespace/group to create project in, and returns
    # its numeric id (NOT the namespace name).
    __select_namespace() {
        local gitlab_namespaces_json namespace_to_id namespace is_id_field
        local i j fzf_selection

        # https://forum.gitlab.com/t/create-a-new-project-in-a-group-using-api/1552/2
        #
        # find our namespaces:
        readonly gitlab_namespaces_json="$(curl -sL --insecure \
            --header "PRIVATE-TOKEN: $passwd" \
            "https://${repo}/api/v3/namespaces")"

        [[ "$gitlab_namespaces_json" == '[{"'* ]] || { err "found namespaces curl reply isn't expected json array" "$FUNCNAME"; return 1; }

        is_id_field=0
        declare -A namespace_to_id
        while read -r i; do
            [[ "$is_id_field" -eq 0 ]] && { j="$i"; is_id_field=1; continue; }

            [[ -n "$j" ]] || { err "found namespace name was empty string; gitlab namespaces json response: $gitlab_namespaces_json" "$FUNCNAME"; return 1; }
            is_digit "$i" || { err "found namespace id [$i] was not a digit; gitlab namespaces json response: $gitlab_namespaces_json" "$FUNCNAME"; return 1; }
            namespace_to_id[$j]="$i"
            fzf_selection+="${j}\n"
            is_id_field=0
        done <  <(echo "$gitlab_namespaces_json" | jq -r '.[] | .path,.id')

        readonly fzf_selection="${fzf_selection:0:$(( ${#fzf_selection} - 2 ))}"  # strip the trailing newline
        readonly namespace="$(echo -e "$fzf_selection" | fzf --exit-0)" || return 1
        i="${namespace_to_id[$namespace]}"
        is_digit "$i" || { err "unable to find namespace id from name [$namespace]" "$FUNCNAME"; return 1; }

        echo "$i"
        return 0
    }

    # create remote repo, if not existing:
    if ! git ls-remote "git@${repo}:${user}/${project_name}" &> /dev/null; then
        case "$repo" in
            'github.com')
                readonly http_statuscode="$(curl -sL \
                    -w '%{http_code}' \
                    -u "$user:$passwd" \
                    https://api.github.com/user/repos \
                    -d "{ \"name\":\"$project_name\", \"private\":\"true\" }" \
                    -o "$curl_output")"
                ;;
            'bitbucket.org')
                readonly http_statuscode="$(curl -sL -X POST \
                    -w '%{http_code}' \
                    -H "Content-Type: application/json" \
                    -u "$user:$passwd" \
                    "https://api.bitbucket.org/2.0/repositories/$user/$project_name" \
                    -d '{ "scm": "git", "is_private": "true", "fork_policy": "no_public_forks" }' \
                    -o "$curl_output")"
                ;;
            "$(getnetrc "${user}@git.url.workplace")")
                namespace_id="$(__select_namespace)" || { [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"; return 1; }  # delete the dir we just created
                unset __select_namespace
                readonly http_statuscode="$(curl -sL --insecure \
                    -w '%{http_code}' \
                    --header "PRIVATE-TOKEN: $passwd" \
                    -X POST "https://${repo}/api/v3/projects?name=${project_name}&namespace_id=${namespace_id}&visibility_level=0" \
                    -o "$curl_output")"
                ;;
            *)
                err "unexpected repo [$repo]" "$FUNCNAME"
                [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
                return 1
                ;;
        esac

        if [[ "$http_statuscode" != 20* || "${#http_statuscode}" -ne 3 ]]; then
            err "curl request for creating the repo @ [$repo] apparently failed; response code was [$http_statuscode]" "$FUNCNAME"
            if [[ -f "$curl_output" ]]; then
                err "curl output can be found in [$curl_output]. contents are:\n\n" "$FUNCNAME"
                jq . < "$curl_output"
            fi
            echo
            err "abort" "$FUNCNAME"

            [[ "$newly_created_dir" -eq 1 ]] && rm -r -- "$dir"  # delete the dir we just created
            return 1
        fi

        report "created new repo @ ${repo}/${user}/${project_name}" "$FUNCNAME"
        echo
    fi

    pushd -- "$dir" &> /dev/null || return 1
    git init || { err "bad return from git init - code [$?]" "$FUNCNAME"; return 1; }
    git remote add origin "git@${repo}:${user}/${project_name}.git" || { err "adding remote failed. abort." "$FUNCNAME"; return 1; }
    echo

    if confirm "want to add README.md (recommended)?"; then
        report "adding README.md ..." "$FUNCNAME"
        touch README.md
        git add README.md
        git commit -a -m 'inital setup, adding readme - automated'
        git push -u origin master
    fi

    unset __select_namespace
}

########################################
## Open file inside git tree with vim ##
########################################
gito() {
    local src matches git_root cwd i

    readonly cwd="$PWD"

    if [[ "$__REMOTE_SSH" -ne 1 ]]; then
        check_progs_installed git fzf || return 1
    fi

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    readonly src="$*"
    readonly git_root="$(git rev-parse --show-toplevel)"
    [[ "$cwd" != "$git_root" ]] && pushd "$git_root" &> /dev/null  # git root

    if [[ -n "$src" ]]; then
        if [[ "$src" == *\** && "$src" != *\.\** ]]; then
            err 'use .* as wildcards, not a single *' "$FUNCNAME"
            [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back
            return 1
        elif [[ "$(echo "$src" | tr -dc '.' | wc -m)" -lt "$(echo "$src" | tr -dc '*' | wc -m)" ]]; then
            err "nr of periods (.) was less than stars (*); are you misusing regex?" "$FUNCNAME"
            [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back
            return 1
        fi
    fi

    __git_ls_fun() {
        git ls-files | grep -Ei -- "${src:-$}"
    }

    if ! command -v fzf > /dev/null 2>&1; then
        while read -r i; do
            matches+=("$i")
        done < <(__git_ls_fun)

        select_items "${matches[@]}"  # don't return here as we need to change wd to starting location;
        matches=("${__SELECTED_ITEMS[@]}")
    else
        while read -r i; do
            matches+=("$i")
        done < <(__git_ls_fun | fzf --select-1 --multi --exit-0)
    fi

    unset __git_ls_fun
    [[ "$cwd" != "$git_root" ]] && popd &> /dev/null  # go back to starting dir
    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }

    for ((i=0; i <= (( ${#matches[@]} - 1 )); i++)); do
        matches[i]="$git_root/${matches[i]}"  # convert to absolute
    done

    __fo "${matches[@]}"
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

    glt || err "unable to find latest tag. not affecting ${FUNCNAME}(), continuing..." "$FUNCNAME"

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
    local opts default_depth matches i

    opts="$1"

    readonly default_depth="m10"
    matches=()

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"  # depth opt has to come last
        #echo $opts  # debug

        shift
    else
        opts="-f${default_depth}"
    fi

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$opts" "$@")

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }
    __fo "${matches[@]}"
}


# finds files/dirs and DELETES them
#
# mnemonic: file open delete
fod() {
    local matches i

    matches=()

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$@")

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }

    report "found [${#matches[@]}] nodes:" "$FUNCNAME"
    for i in "${matches[@]}"; do
        echo -e "\t${i}"
    done

    if confirm "wish to DELETE them?"; then
        rm -r -- "${matches[@]}" || { _FOUND_FILES=("${matches[@]}"); err "something went wrong while deleting. (stored the files in \$_FOUND_FILES array)" "$FUNCNAME"; return 1; }
    fi
}


# finds files/dirs and goes to containing dir (or same dir if found item is already a dir)
#
# mnemonic: file open go
fog() {
    local opts default_depth matches i

    opts="$1"

    readonly default_depth="m10"
    matches=()

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-$default_depth"
    fi

    [[ "$#" -eq 0 ]] && { err "too few args." "$FUNCNAME"; return 1; }

    if ! command -v fzf > /dev/null 2>&1; then
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@")

        select_items --single "${matches[@]}" || return 1
        matches=("${__SELECTED_ITEMS[@]}")
    else
        while read -r i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$opts" "$@" | fzf --select-1 --read0 --exit-0)
    fi

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }

    goto "${matches[@]}"
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
    matches=()

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *f* ]] && opts="-f${opts:1}"
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-f${default_depth}"
    fi

    check_progs_installed stat sort || return 1

    if [[ "$#" -eq 1 ]] && is_digit "$1"; then
        report "note that when you want the nth newest, then filename pattern has to be provided as first arg\n" "$FUNCNAME"

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
    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }

    [[ "$n" -gt "${#matches[@]}" ]] && { err "cannot open [${n}th] newest file, since total nr of found files was [${#matches[@]}]" "$FUNCNAME"; return 1; }

    readonly newest="$(stat --format='%Y %n' -- "${matches[@]}" \
            | sort -r -k 1 \
            | sed -n ${n}p \
            | cut -d ' ' -f 2-)"

    [[ -f "$newest" ]] || { err "something went wrong, found newest file [$newest] is not a valid file." "$FUNCNAME"; return 1; }
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
    matches=()

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
    [[ -d "$prog" ]] && report "last arg needs to be the program to open with, not dir arg for ffind" "$FUNCNAME"
    if ! command -v -- "$prog" >/dev/null; then
        err "[$prog] is not installed." "$FUNCNAME"
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

    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }
    report "opening [${matches[*]}] with [$prog]" "$FUNCNAME"
    $prog -- "${matches[@]}"
}


# collect all found files into global array
foc() {
    local opts default_depth matches i

    opts="$1"

    readonly default_depth="m10"
    matches=()

    if [[ "$opts" == -* ]]; then
        [[ "$opts" != *m* ]] && opts+="$default_depth"
        #echo $opts  # debug
        shift
    else
        opts="-${default_depth}"
    fi

    while IFS= read -r -d $'\0' i; do
        matches+=("$i")
    done < <(ffind --_skip_msgs "$opts" "$@")

    report "found ${#matches[@]} files; stored in \$_FOUND_FILES global array." "$FUNCNAME"
    _FOUND_FILES=("${matches[@]}")

    return
}


# finds files/dirs using ffind() (find wrapper) and opens them.
# accepts different 'special modes' to be defined as first arg (modes defined in $special_modes array).
#
# if no args provided, then default to opening regular files in current dir.
#
# mnemonic: file open
fo() {
    local matches

    [[ -z "$@" ]] && set -- '-fm1'

    if ! command -v fzf > /dev/null 2>&1; then
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(ffind --_skip_msgs "$@")

        select_items "${matches[@]}" || return 1
        __fo "${__SELECTED_ITEMS[@]}"
    else
        #while IFS= read -r -d $'\0' i; do
            #matches+=("$i")
        #done < <(ffind --_skip_msgs "$@" | fzf --select-1 --multi --read0 | __fo)
        ffind --_skip_msgs "$@" | fzf --select-1 --multi --read0 --exit-0 | __fo  # add --print0 to fzf once implemented; also update __fo
    fi
}


__fo() {
    local files count filetype editor image_viewer video_player file_mngr
    local pdf_viewer office image_editor i

    editor="$EDITOR"
    image_viewer="sxiv"
    video_player="smplayer"
    file_mngr="ranger"
    pdf_viewer="zathura"
    office="libreoffice"
    image_editor="gimp"

    files=()

    if [[ "$__REMOTE_SSH" -ne 1 ]]; then  # only check for progs if not ssh-d
        check_progs_installed "$PAGER" "$file_mngr" "$editor" "$image_viewer" \
                "$image_editor" "$video_player" "$pdf_viewer" "$office" file || return 1
    fi

    if [[ -z "$@" ]]; then  # no params provided, meaning expect input via stdin
        #while IFS= read -r -d $'\0' i; do  # TODO enable once fzf gets the --print0 option
        while read -r i; do
            files+=("$i")
        done
    else  # $FUNCNAME was invoked with arguments, not feeding files via stdin;
        readonly files=("$@")
    fi

    [[ "${#files[@]}" -eq 0 ]] && return  # quit silently
    readonly count="${#files[@]}"
    # define filetype only by the first node:  # TODO: perhaps verify all nodes are of same type?
    readonly filetype="$(file -iLb -- "${files[0]}")" || { err "issues testing [${files[0]}] with \$ file cmd" "${FUNCNAME[1]}"; return 1; }

    # report
    if [[ "$count" -eq 1 ]]; then
        report "opening [${files[*]}]" "${FUNCNAME[1]}"
    else
        report "opening:" "${FUNCNAME[1]}"
        for i in "${files[@]}"; do
            echo -e "\t${i}"
        done
    fi

    case "$filetype" in
        'image/x-xcf; charset=binary')  # xcf is gimp
            "$image_editor" -- "${files[@]}"
            ;;
        image/*)
            "$image_viewer" -- "${files[@]}"
            ;;
        application/octet-stream*)
            # should be the logs on app servers
            "$PAGER" -- "${files[@]}"
            ;;
        application/xml*)
            [[ "$count" -gt 1 ]] && { report "won't format multiple xml files! will just open them" "${FUNCNAME[1]}"; sleep 1.5; }
            if [[ "$(wc -l < "${files[0]}")" -gt 2 || "$count" -gt 1 ]]; then  # note if more than 2 lines we also assume it's already formatted;
                # assuming it's already formatted:
                "$editor" -- "${files[@]}"
            else
                xmlformat "${files[@]}"
            fi
            ;;
        video/* | audio/mp4*)
            #"$video_player" -- "${files[@]}"  # TODO: smplayer doesn't support '--' as per now
            "$video_player" "${files[@]}"
            ;;
        text/*)
            # if we're dealing with a logfile (including *.out), force open in PAGER
            if [[ "${files[0]}" =~ \.(log|out)(\.[\.a-z0-9]+)*$ ]]; then
                "$PAGER" -- "${files[@]}"
            else
                "$editor" -- "${files[@]}"
            fi
            ;;
        application/pdf*)
            "$pdf_viewer" -- "${files[@]}"
            ;;
        application/x-elc*)  # TODO: what exactly is it?
            "$editor" -- "${files[@]}"
            ;;
        'application/x-executable; charset=binary'*)
            [[ "$count" -gt 1 ]] && { report "won't execute multiple files! select one please" "${FUNCNAME[1]}"; return 1; }
            confirm "${files[*]} is executable. want to launch it from here?" || return
            report "launching ${files[0]}..." "${FUNCNAME[1]}"
            ${files[0]}
            ;;
        'inode/directory;'*)
            [[ "$count" -gt 1 ]] && { report "won't navigate to multiple dirs! select one please" "${FUNCNAME[1]}"; return 1; }
            "$file_mngr" -- "${files[0]}"
            ;;
        'inode/x-empty; charset=binary')
            "$editor" -- "${files[@]}"
            ;;
        # try keeping doc files' definitions in sync with the ones in ffind()
        'application/msword; charset=binary' \
                | 'application/'*'opendocument'*'; charset=binary' \
                | 'application/'*'ms-office; charset=binary' \
                | 'application/'*'ms-excel; charset=binary')
            "$office" "${files[@]}"  # libreoffice doesn't like option ending marker '--'
            ;;
        *)
            err "dunno what to open this type of file with:\n\t$filetype" "${FUNCNAME[1]}"
            return 1
            ;;
    esac
}

sethometime() { setspaintime; }  # home is where you make it;

setromaniatime() {
    __settz Europe/Bucharest
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

__settz() {
    local tz

    readonly tz="$*"

    check_progs_installed timedatectl || return 1
    [[ -z "$tz" ]] && { err "provide a timezone to switch to (e.g. Europe/Madrid)." "${FUNCNAME[1]}"; return 1; }
    [[ "$tz" =~ [a-zA-Z]+/[a-zA-Z]+ ]] || { err "invalid timezone format; has to be in a format like [Europe/Madrid]." "${FUNCNAME[1]}"; return 1; }

    timedatectl set-timezone "$tz" || { err "setting tz to [$tz] failed (code $?)" "${FUNCNAME[1]}"; return 1; }
}

killmenao() {
    confirm "you sure?" || return
    clear
    report 'you ded.' "$FUNCNAME"
    :(){ :|:& };:
}

########################
## Print window class ##
########################
xclass() {
    check_progs_installed xprop || return 1

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
    local path input matches pattern msg_loc iname_arg i

    input="$*"

    [[ -d "$input" && ! "$input" =~ ^\.+$ ]] && { cd -- "$input"; return; }
    [[ -z "$input" ]] && input='*'

    #[[ "$input" == */* ]] && path="${input%%/*}"  # strip everything after last slash(included)
    path="$(dirname -- "$input")"
    [[ -d "$path" ]] || { err "something went wrong - dirname result [$path] is not a dir." "$FUNCNAME"; return 1; }
    pattern="${input##*/}"  # strip everything before last slash (included)
    [[ -z "$pattern" ]] && { err "no search pattern provided" "$FUNCNAME"; return 1; }
    [[ "$path" == '.' ]] && msg_loc="here" || msg_loc="$path/"

    [[ "$(tolowercase "$pattern")" == "$pattern" ]] && iname_arg="iname"

    __find_fun() {
        find -L "$path" -maxdepth 1 -mindepth 1 -type d -${iname_arg:-name} '*'"$pattern"'*' -print0
    }

    if ! command -v fzf > /dev/null 2>&1; then
        while IFS= read -r -d $'\0' i; do
            matches+=("$i")
        done < <(__find_fun)

        select_items --single "${matches[@]}" || return 1
        matches=("${__SELECTED_ITEMS[@]}")
    else
        while read -r i; do
            matches+=("$i")
        done < <(__find_fun | fzf --select-1 --read0 --exit-0)
    fi

    unset __find_fun
    [[ "${#matches[@]}" -eq 0 ]] && { err "no matches found" "$FUNCNAME"; return 1; }
    [[ "${#matches[@]}" -gt 1 ]] && { err "[${#matches[@]}] matches were found; max 1 allowed. fix ${FUNCNAME}()" "$FUNCNAME"; return 1; }
    [[ -d "${matches[0]}" ]] || { err "no such dir like [${matches[0]}] in $msg_loc" "$FUNCNAME"; return 1; }
    cd -- "${matches[0]}"
}


# dockers
#############################

# from http://stackoverflow.com/questions/32723111/how-to-remove-old-and-unused-docker-images
#
# consider also https://github.com/spotify/docker-gc
dcleanup() {
    check_progs_installed docker || return 1

    report "¡¡¡ make sure the containers you want to keep are running; otherwise you'll lose them !!!" "$FUNCNAME"
    confirm "\ncontinue?" || return

    # TODO: don't report err status perhaps? might be ok, which also explains the 2>/dev/nulls;
    docker rm -v $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null || { err "something went wrong with removing exited containers." "$FUNCNAME"; }
    docker rmi $(docker images --filter dangling=true -q 2>/dev/null) 2>/dev/null || { err "something went wrong with removing dangling images." "$FUNCNAME"; }
    # ...and volumes:
    docker volume rm $(docker volume ls -qf dangling=true) || { err "something went wrong with removing dangling volumes." "$FUNCNAME"; }
}


# display available APs and their basic info
wifilist() {
    local wifi_device_file

    readonly wifi_device_file="$_WIRELESS_IF"

    check_progs_installed nmcli || return 1

    [[ -r "$wifi_device_file" ]] || { err "can't read file [$wifi_device_file]; probably you have no wireless devices." "$FUNCNAME"; }
    [[ -z "$(cat -- "$wifi_device_file")" ]] && { err "$wifi_device_file is empty." "$FUNCNAME"; }
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


# transfer.sh alias - file sharing
# see  https://github.com/dutchcoders/transfer.sh/
transfer() {
    local tmpfile file

    readonly file="$1"

    [[ "$#" -ne 1 || -z "$file" ]] && { err "file to upload required." "$FUNCNAME"; return 1; }
    [[ -e "$file" ]] || { err "[$file] does not exist." "$FUNCNAME"; return 1; }
    check_progs_installed curl || return 1

    # write to output to tmpfile because of progress bar
    readonly tmpfile=$(mktemp -t transfer_XXX.tmp) || { err "unable to create temp with mktemp" "$FUNCNAME"; return 1; }
    curl --progress-bar --upload-file -- "$file" "https://transfer.sh/$(basename -- "$file")" >> "$tmpfile" || { err; return 1; }
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
mkcd() {
    [[ -z "$@" ]] && { err "name of a directory to be created required." "$FUNCNAME"; return 1; }
    mkdir -p -- "$@" && cd -- "$@"
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
    [[ "$screen_dimensions" =~ $regex ]] || { err "found screen dimensions [$screen_dimensions] do not conform with validation regex [$regex]" "$FUNCNAME"; return 1; }

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
pubkey() {
    local key contents
    readonly key="$HOME/.ssh/id_rsa.pub"

    [[ -f "$key" ]] || { err "[$key] does not exist" "$FUNCNAME"; return 1; }
    readonly contents="$(cat -- "$key")" || { err "cat-ing [$key] failed." "$FUNCNAME"; return 1; }

    copy_to_clipboard "$contents" && report "copied pubkey to clipboard" "$FUNCNAME"
    return $?
}


##############################################
# FZF based functions                       ##
##############################################
# see  https://github.com/junegunn/fzf/wiki/Examples


# fd - cd to selected directory
fd() {
    local dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be starting dir." "$FUNCNAME"; return 1; }
    dir=$(find "${src:-.}" -path '*/\.*' -prune \
                    -o -type d -print 2> /dev/null | fzf +m) && cd -- "$dir"
}


# fda - same as fd(), but includes hidden directories;
# kinda same as `cd **<Tab>`
fda() {
    local dir src

    readonly src="$1"
    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be starting dir." "$FUNCNAME"; return 1; }
    dir=$(find "${src:-.}" -type d 2> /dev/null | fzf +m) && cd -- "$dir"
}


# fdu - cd to selected *parent* directory
fdu() {
    local dirs dir src pwd

    readonly src="$1"
    readonly pwd="$(realpath -- "$PWD")"

    [[ -n "$src" && ! -d "$src" ]] && { err "first argument can only be starting dir." "$FUNCNAME"; return 1; }

    dirs=()
    _get_parent_dirs() {
        [[ -d "$1" ]] || return
        [[ "$1" != "$pwd" ]] && dirs+=("$1")
        if [[ "$1" == '/' ]]; then
            for _dir in "${dirs[@]}"; do echo "$_dir"; done
        else
            _get_parent_dirs "$(dirname -- "$1")"
        fi
    }

    dir=$(_get_parent_dirs "$(realpath -- "${src:-$pwd}")" | fzf-tmux --tac)
    cd -- "$dir"

    unset _get_parent_dirs
}


# cdf - cd into the directory of the selected file
# (same as our fog())
cdf() {
    local file dir pattern

    readonly pattern="$1"
    [[ -d "$pattern" ]] && report "fyi, input argument has to be a search pattern, not starting dir." "$FUNCNAME"

    file=$(fzf +m -q "$pattern") && dir=$(dirname -- "$file") && cd -- "$dir"
}


# utility function used to write the command in the shell (used by fzf wrappers)
# pass '-run' as first argument to run the passed command
__writecmd() {
    perl -e '$TIOCSTI = 0x5412; $l = <STDIN>; $lc = $ARGV[0] eq "-run" ? "\n" : ""; $l =~ s/\s*$/$lc/; map { ioctl STDOUT, $TIOCSTI, $_; } split "", $l;' -- $1
}


# fh - repeat history
# note: no reason to use when ctrl+r mapping works;
# ctrl-e instead of enter lets you edit the command, just like with ctrl+r binding.
fh() {
    local input regex cmd out ifs_old k

    readonly input="$*"

    readonly regex='^\s*\d+\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+\K.*$'
    #([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -re 's/^\s*[0-9]+\s*//' | __writecmd -run

    if command -v fzf > /dev/null 2>&1; then
        out="$(history \
                | grep -vE -- "\s+$FUNCNAME\b" \
                | fzf --no-sort --tac --print-query --query="$input" --expect=ctrl-e +m -e --exit-0)"
        mapfile -t out <<< "$out"
        readonly k="${out[1]}"
        readonly cmd="$(echo "${out[-1]}" | grep -oP -- "$regex")"
        if [[ "$k" == 'ctrl-e' ]]; then
            echo "$cmd" | __writecmd
        else
            echo "$cmd" | __writecmd -run
        fi
        # oneliner without the binding:
        #([ -n "$ZSH_NAME" ] && fc -l 1 || history) \
            #| grep -vE -- "\s+$FUNCNAME\b" \
            #| fzf --no-sort --tac --query="$input" +m -e \
            #| grep -oP -- "$regex" \
            #| __writecmd -run
    else
        readonly ifs_old="$IFS"
        IFS=$'\n'
        readonly cmd=( $(history \
                | grep -vE -- "\s+$FUNCNAME\b" \
                | grep -iE --color=auto -- "$input" \
                | grep -oP -- "$regex") )

        [[ -z "${cmd[*]}" ]] && { err "no matching entries found" "$FUNCNAME"; return 1; }
        select_items --single "${cmd[@]}"
        #echo "woo: ${__SELECTED_ITEMS[@]}"
        IFS="$ifs_old"
    fi
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
    local branches branch q

    q="$*"
    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    branches=$(git branch --all | grep -v HEAD) &&
            branch=$(echo "$branches" |
                    fzf-tmux --query="$q" -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
            git checkout "$(echo "$branch" | sed 's/.* //' | sed 's#remotes/[^/]*/##')"
}


# fco - checkout git branch/tag
fco() {
    local tags branches target q

    q="$*"
    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    tags=$(git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
    branches=$(
        git branch --all | grep -v HEAD             |
        sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
        sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
    target=$(
        (echo "$tags"; echo "$branches") |
        fzf-tmux --query="$q" -l30 -- --no-hscroll --ansi +m -d "\t" -n 2) || return
    git checkout "$(echo "$target" | awk '{print $2}')"
}


# fcoc - checkout git commit (as in commit hash, not branch or tag)
fcoc() {
    local commits commit q

    q="$*"
    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
        commit=$(echo "$commits" | fzf --query="$q" --tac +s +m -e --exit-0) &&
        git checkout "$(echo "$commit" | sed 's/ .*//')"
}


# fshow - git commit diff browser
# - enter shows the changes of the commit
# - ctrl-s lets you squash commits - select the *last* commit that should be squashed.
# - ctrl-c generates the jira commit message.
# - ctrl-u generates gitlab commit url.
# - ctrl-b check the selected commit out.
fshow() {
    local q k out sha url

    q="$*"

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }
    #git log -i --all --graph --source --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative |
    while out=$(
            git log --graph --color=always \
                --format="%C(auto)%h%d %s %C(black)%C(bold)(%cr) %C(bold blue)<%an>%Creset" |
                fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-z:toggle-sort --query="$q" --print-query \
                    --expect=ctrl-s,ctrl-c,ctrl-u,ctrl-b --exit-0); do
        mapfile -t out <<< "$out"
        q="${out[0]}"
        k="${out[1]}"
        # note we also need to include git log's graph slashes, pipes and stars to the regex:
        sha="$(echo "${out[-1]}" | grep -Po '^[|\ /\\*]+\s*\K[a-z0-9]+(?=.*$)')" || { err "unable to parse out commit sha" "$FUNCNAME"; return 1; }
        [[ "$sha" =~ [a-z0-9]{7} ]] || { err "commit sha was [$sha]" "$FUNCNAME"; return 1; }

        case "$k" in
            'ctrl-s')
                if [[ "$sha" == "$(git log -n 1 --pretty=format:%h HEAD)" ]]; then
                    report "won't rebase on HEAD lol" "$FUNCNAME" && sleep 1.5 && continue
                elif [[ -n "$q" ]]; then
                    confirm "\nyou've filtered commits by query [$q]; still continue with rebase?" || continue
                fi

                git rebase -i "$sha"~ && continue || return 1
                ;;
            'ctrl-c')
                is_function generate_jira_commit_comment || { err "can't generate commit msg as dependency is missing" "$FUNCNAME"; return 1; }
                generate_jira_commit_comment "$sha"
                break
                ;;
            'ctrl-u')
                is_function generate_git_commit_url || { err "can't generate git commit url as dependency is missing" "$FUNCNAME"; return 1; }
                url="$(generate_git_commit_url "$sha")" || { err "creating commit url failed" "$FUNCNAME"; return 1; }
                copy_to_clipboard "$url" \
                    && { report "git commitcommit url on clipboard"; return 0; } \
                    || err "unable to copy git commit url to clipboard. here it is:\n$url"
                break
                ;;
            'ctrl-b')
                git checkout "$sha"
                break
                ;;
            *)
                git difftool --dir-diff "$sha"^ "$sha"
                ;;
        esac
    done
}


# fsha - get git commit sha
# example usage: git rebase -i `fsha`
fsha() {
    local commits commit

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    commits=$(git log --color=always --pretty=oneline --abbrev-commit --reverse) &&
    commit=$(echo "$commits" | fzf --tac +s +m -e --ansi --reverse --exit-0) &&
    commit="${commit%% *}" &&
    copy_to_clipboard "$commit" &&
    report "copied commit sha [$commit] to clipboard" "$FUNCNAME"
}


# fstash - easier way to deal with stashes; type fstash to get a list of your stashes.
# - enter shows you the contents of the stash
# - ctrl-d asks to drop the selected stash
# - ctrl-a asks to apply the selected stash
# - ctrl-b checks the stash out as a branch, for easier merging (TODO: not using)
fstash() {
    local out q k stsh stash_name_regex stash_name

    readonly stash_name_regex='^\s*\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\K(.*)'

    is_git || { err "not in git repo." "$FUNCNAME"; return 1; }

    while out=$(
            git stash list --pretty="%C(red)%gd %C(yellow)%h %>(14)%Cgreen%cr %C(blue)%gs" |
                fzf --ansi --no-sort --query="$q" --print-query \
                    --expect=ctrl-d,ctrl-b,ctrl-a --exit-0); do
        mapfile -t out <<< "$out"
        q="${out[0]}"
        k="${out[1]}"
        stsh="${out[-1]}"
        stsh="${stsh%% *}"
        [[ -z "$stsh" ]] && continue

        stash_name="$(echo "${out[-1]}" | grep -Po "$stash_name_regex")"  # name/description of the stash

        case "$k" in
            'ctrl-d')
                confirm " -> drop stash $stsh ($stash_name)?" || continue
                git stash drop "$stsh" || { err "something went wrong (code $?)" "$FUNCNAME"; return 1; }
                unset stsh  # so it wouldn't get copied to clipboard
                ;;
            'ctrl-a')
                confirm " -> apply (pop) stash $stsh ($stash_name)?" || continue
                git stash pop "$stsh" || { err "something went wrong (code $?)" "$FUNCNAME"; return 1; }
                unset stsh  # so it wouldn't get copied to clipboard
                ;;
            'ctrl-b')
                report "not using c-b binding atm" "$FUNCNAME" && return
                git stash branch "stash-$sha" "$sha"
                break;
                ;;
            *)  # default, ie diff view mode
                #git stash show -p "$sha"
                git difftool --dir-diff "$stsh"^ "$stsh"
                ;;
        esac
    done

    # copy last viewed stash id to clipboard:
    [[ -z "$k" && -n "$stsh" ]] \
        && copy_to_clipboard "$stsh" \
        && echo && report " -> copied [$stsh] to clipboard" "$FUNCNAME"
}


# select recent file with fasd and open for editing
e() {  # mnemonic: edit
    local file

    check_progs_installed fasd fzf "$EDITOR" || return 1

    file="$(fasd -Rfl "$@" | fzf -1 -0 --no-sort +m --exit-0)" && $EDITOR "$file" || return 1
}


# select recent dir with fasd and cd into
# note: d clashes with fasd alias; make sure you remove that one (in generated cache)
d() {  # mnemonic: dir
    local dir

    #command -v ranger >/dev/null && fm=ranger
    #check_progs_installed "$fm" || return 1

    check_progs_installed fasd fzf || return 1
    dir="$(fasd -Rdl "$@" | fzf -1 -0 --no-sort +m --exit-0)" && cd -- "$dir" || return 1
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
    [[ "$#" -ne 1 ]] && { err "provide a mark to jump to" "$FUNCNAME"; return 1; }
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in ${_MARKPATH} - dir does not exist." "$FUNCNAME"; return 1; }
    cd -P -- "$_MARKPATH/$1" 2>/dev/null || err "no mark [$1] in [$_MARKPATH]" "$FUNCNAME"
}

# mark:
# pass '-o' as first arg to force overwrite existing target link
function jm {
    local overwrite target

    [[ "$1" == "-o" || "$1" == "--overwrite" ]] && { readonly overwrite=1; shift; }
    readonly target="$_MARKPATH/$1"

    [[ $# -ne 1 || -z "$1" ]] && { err "exactly one arg accepted" "$FUNCNAME"; return 1; }
    [[ -z "$_MARKPATH" ]] && { err "\$_MARKPATH not set, aborting." "$FUNCNAME"; return 1; }
    mkdir -p -- "$_MARKPATH" || { err "creating [$_MARKPATH] failed." "$FUNCNAME"; return 1; }
    [[ "$overwrite" -eq 1 && -h "$target" ]] && rm -- "$target" >/dev/null 2>/dev/null
    [[ -h "$target" ]] && { err "[$target] already exists; use jmo() or $FUNCNAME -o to overwrite." "$FUNCNAME"; return 1; }

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
    [[ $# -ne 1 || -z "$1" ]] && { err "exactly one arg accepted" "$FUNCNAME"; return 1; }
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in [$_MARKPATH] - dir does not exist." "$FUNCNAME"; return 1; }
    rm -i -- "$_MARKPATH/$1"
}

# list all saved marks:
function jjj {
    [[ -d "$_MARKPATH" ]] || { err "no marks saved in [$_MARKPATH] - dir does not exist." "$FUNCNAME"; return 1; }
    ls -l -- "$_MARKPATH" | sed 's/  / /g' | cut -d' ' -f9- | sed 's/ -/\t-/g' && echo
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

