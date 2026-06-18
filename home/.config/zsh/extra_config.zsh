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

        [[ "${(L)pattern}" == "$pattern" ]] && iname_arg='iname'  # is lower case
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
        for ((i=0; i <= (( ${#pattern} - 2 )); i++)); do
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

    paths=("${(@s:/:)${input%/}}")
    #echo "paths: [${paths[@]}]"  # debug

    # clean paths:
    # TODO: what if the first path element is '.'? '26 edit: should be fine, no?
    for ((i = 1; i <= $#paths; i++)); do
        [[ -z "${paths[$i]}" || "${paths[$i]}" == . ]] && unset 'paths[i]'
    done
    [[ "${#paths[@]}" -eq 0 ]] && paths=('*')
    #echo "cleaned paths: [${paths[@]}]"

    for i in "${paths[@]}"; do
        [[ -z "$dir" && "$i" =~ '^\.{3,}$' ]] && { __go_up "$i"; is_backing=0; continue; }
        [[ "$i" != '..' ]] && is_backing=0
        __select_dir "$i" "$dir" || { unset __find_fun __select_dir __go_up; return 1; }
    done

    unset __find_fun __select_dir __go_up
    #echo "cd to: [$dir]"  # debug
    cd -- "$dir"
}

