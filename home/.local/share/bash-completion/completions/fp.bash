# initial idea from https://nsg.cc/post/2018/fuzzy-bash-completion/
#
# per bash manual, the `complete -F` function recevies:
#    the first argument ($1) is the name of the command whose arguments are being completed,
#    the second argument ($2) is the word being completed, and
#    the third argument ($3) is the word preceding the word being completed on the current command line
_fp_completion() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"

  #local applications=$(flatpak list --app | awk -F '\t' '{print tolower($2)}')
  #COMPREPLY=( $(compgen -W "${applications}" -- ${cur}) )
  mapfile -t COMPREPLY < <(flatpak list --app | awk -F '\t' '{print tolower($2)}'| grep -iE "${cur//\*/.*}")
  #COMPREPLY=( $(compgen -W "$(flatpak list --app | awk -F '\t' '{print tolower($2)}')" -- $cur) )
}

complete -F _fp_completion fp

