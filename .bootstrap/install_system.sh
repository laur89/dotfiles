#!/usr/bin/env bash
# shellcheck disable=SC2317
#
# base version taken from https://github.com/rastasheep/dotfiles/blob/master/script/bootstrap
#
# Base installation script intended to be executed on freshly installed
# Debian testing(!) release netinstall installation.
#
# Note that this is very user-specific installation, which is largely based on the
# configuration & scripts pulled via the homeshick repositories defined in this scipt.
# If you're not familiar with homeshick, then some of the variables/concepts in this
# script might not be straight-forward (eg 'castle' is essentially a git repo managed
# by homeshick).
#
# see also:
# - https://github.com/romkatv/dotfiles-public/blob/master/bin/setup-machine.sh
#   - has some WSL logic as well; note they install dbus-x11 if wsl - why's that?
# - ansible playbooks:
#   - https://gitlab.com/folliehiyuki/sysconfig
#
#------------------------
#---   Configuration  ---
#------------------------
set -o pipefail
shopt -s nullglob       # unmatching globs to expand into empty string/list instead of being left unexpanded

TMP_DIR=/tmp
readonly PRIVATE_KEY_LOC="$HOME/.ssh/id_rsa"  # TODO: change to id_ed25519
readonly SHELL_ENVS="$HOME/.bash_env_vars"       # location of our shell vars; expected to be pulled in via homesick;
                                                 # note that contents of that file are somewhat important, as some
                                                 # (script-related) configuration lies within.
#readonly BASH_COMPLETIONS="$XDG_DATA_HOME/bash-completion/completions"  # as per https://github.com/scop/bash-completion#faq  # cannot set before importing SHELL_ENVS!
readonly ZSH_COMPLETIONS='/usr/local/share/zsh/site-functions'  # as per https://unix.stackexchange.com/a/607810/47501
readonly APT_KEY_DIR='/usr/local/share/keyrings'  # dir where per-application apt keys will be stored in
readonly SERVER_IP='10.42.21.10'             # default server address; likely to be an address in our LAN
readonly NFS_SERVER_SHARE='/data'            # default node to share over NFS
readonly SSH_SERVER_SHARE='/data'            # default node to share over SSH

readonly BUILD_DOCK='deb-build-box'          # name of the build container

# just for info, current testing = trixie
readonly DEB_STABLE=bookworm                 # current _stable_ release codename; when updating it, verify that all the users have their counterparts (eg 3rd party apt repos)
readonly DEB_OLDSTABLE=bullseye              # current _oldstable_ release codename; when updating it, verify that all the users have their counterparts (eg 3rd party apt repos)

readonly USER_AGENT='Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0'
#------------------------
#--- Global Variables ---
#------------------------
IS_SSH_SETUP=0       # states whether our ssh keys are present. 1 || 0
__SELECTED_ITEMS=''  # only select_items() *writes* into this one.
PROFILE=''           # work || personal
ALLOW_OFFLINE=0      # whether script is allowed to run when we're offline
CONNECTED=0          # are we connected to the web? 1 || 0
GIT_RLS_LOG=''       # log of all installed/fetched assets from git releases/latest page; will be defined later on at init;
LOGGING_LVL=0                   # execution logging level (full install mode logs everything);
                                # don't set log level too soon; don't want to persist bullshit.
                                # levels are currently 0, 1 and 10; 0 being no logging, 1 being the lowest (from lvl 1 to 9 only execute() errors are logged)
NON_INTERACTIVE=0               # whether script's running non-attended
EXECUTION_LOG="$HOME/installation-execution-$(date +%d-%b-%y--%R).log"  # do not create logfile here! otherwise cleanup()
                                                                        # picks it up and reports of its existence, opening
                                                                        # up for false positives.
SCRIPT_LOG="$HOME/installation-execution-term-$(date +%d-%b-%y--%R).log"
SYSCTL_CHANGED=0       # states whether sysctl config got changed
umask 0077  # keep this in sync with what we set via systemd & ~/.profile!

#------------------------
#--- Global Constants ---
#------------------------
readonly BASE_DATA_DIR="/data"  # try to keep this value in sync with equivalent defined in $SHELL_ENVS;
readonly BASE_PROGS_DIR="/progs"
readonly BASE_BUILDS_DIR="$BASE_PROGS_DIR/custom_builds"  # hosts our built progs and/or their .deb packages;
# !! note homeshick env vars are likely also defined/duplicated in our env_var files !!
readonly BASE_HOMESICK_REPOS_LOC="$HOME/.homesick/repos"  # !! keep real location in $HOME! otherwise some apparmor whitelisting won't work (eg for msmtp)
readonly COMMON_DOTFILES="$BASE_HOMESICK_REPOS_LOC/dotfiles"
readonly COMMON_PRIVATE_DOTFILES="$BASE_HOMESICK_REPOS_LOC/private-common"
PRIVATE__DOTFILES=''   # installation specific private castle location (eg for 'work' or 'personal')
PLATFORM_DOTFILES=''   # platform-speific castle location for machine-specific configs; optional

readonly SELF="${0##*/}"

declare -A COLORS=(
    [RED]=$'\033[0;31m'
    [GREEN]=$'\033[0;32m'
    [BLUE]=$'\033[0;34m'
    [PURPLE]=$'\033[0;35m'
    [CYAN]=$'\033[0;36m'
    [WHITE]=$'\033[0;37m'
    [YELLOW]=$'\033[0;33m'
    [OFF]=$'\033[0m'
    [BOLD]=$'\033[1m'
)
readonly NPMRC_BAK="/tmp/npmrc.bak.$RANDOM"  # temp location where we _might_ move our npmrc to for the duration of this script;
readonly GIT_OPTS=(--depth 1 -j8)

# this configures our platform-specific dotfile repos:
declare -A HOSTNAME_TO_PLATFORM=(
    [p14s]="$BASE_HOMESICK_REPOS_LOC/p14s-dotfiles"
)
#-----------------------
#---    Functions    ---
#-----------------------


print_usage() {
    printf "${SELF}:  install/provision system.
        usage: $SELF [-NFSUQO] [-P platform] [-L log_lvl] ] [-T /tmp/dir]  work|personal
          -N            non-interactive usage
          -F            full install mode
          -S            single task
          -U            update/quick refresh
          -Q            faster update
          -P platform   force platform dots castle
          -L log_lvl    int, log level to use
          -T /tmp/dir/  path to temp dir to use, defaults to /tmp
    "
}


validate_and_init() {
    local i

    check_connection && CONNECTED=1 || CONNECTED=0
    [[ "$CONNECTED" -eq 0 && "$ALLOW_OFFLINE" -ne 1 ]] && fail "no internet connection. abort."

    # need to define PRIVATE__DOTFILES here, as otherwise 'single-step' mode of this
    # script might fail. be sure the repo names are in sync with the repos actually
    # pulled in fetch_castles().
    case "$PROFILE" in
        work)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && ! __is_work; then
                confirm "you selected [${COLORS[RED]}${COLORS[BOLD]}$PROFILE${COLORS[OFF]}] profile on non-work machine; sure you want to continue?" || exit
            fi

            PRIVATE__DOTFILES="$BASE_HOMESICK_REPOS_LOC/work_dotfiles"
            ;;
        personal)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && __is_work; then
                confirm "you selected [${COLORS[RED]}${COLORS[BOLD]}$PROFILE${COLORS[OFF]}] profile on work machine; sure you want to continue?" || exit
            fi

            PRIVATE__DOTFILES="$BASE_HOMESICK_REPOS_LOC/personal-dotfiles"
            ;;
        *)
            err "unsupported PROFILE [$PROFILE]"
            print_usage
            exit 1 ;;
    esac

    report "private castle defined as [$PRIVATE__DOTFILES]"

    # derive our platform castle from hostname, if not explicitly provided:
    if [[ -n "$PLATFORM" ]]; then  # provided via cmd opt
        for i in "${!HOSTNAME_TO_PLATFORM[@]}"; do
            [[ "$i" == "$PLATFORM" ]] && break
            unset i
        done

        [[ -z "$i" ]] && fail "selected platform [$PLATFORM] is not known"
        # TODO: prompt if selected platform doesn't match our hostname?
        unset i
    elif [[ -n "${HOSTNAME_TO_PLATFORM[$HOSTNAME]}" ]]; then
        PLATFORM="$HOSTNAME"
    fi

    if [[ -n "$PLATFORM" ]]; then
        PLATFORM_DOTFILES="${HOSTNAME_TO_PLATFORM[$PLATFORM]}"
        #is_native || confirm "platform either selected or resolved on non-native setup -- continue?" || exit 1  # TODO: any reason for this check?
        report "platform castle defined as [$PLATFORM_DOTFILES]"
    else
        ! is_native || confirm "no platform selected nor automatically resolved -- continue?" || exit 1
        report "no platform castle defined"
    fi

    # verify we have our key(s) set up and available:
    if is_ssh_key_available; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    else
        report "ssh keys not present at the moment, be prepared to enter user & passwd for private git repos."
        report "(unless they're pulled from elsewhere)"
        IS_SSH_SETUP=0
    fi

    # ask for the admin password upfront:
    sudo --validate || fail "is user in sudoers file? is sudo installed? if not, then [su && apt-get install sudo]"
    #clear

    # keep-alive: update existing `sudo` time stamp; search tags:  keep sudo, keepsudo, staysudo stay sudo
    while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &
}


# check dependencies required for this installation script
check_dependencies() {
    local dir prog perms exec_to_pkg

    readonly perms='u=rwX,g=,o='  # can't be 777, nor 766, since then you'd be unable to ssh into;
    declare -A exec_to_pkg=(
        [gpg]=gnupg
    )

    for prog in \
            git cmp wc wget curl tar unzip atool \
            realpath dirname basename head tee jq \
            gpg mktemp file date id html2text \
            pwd uniq sort xxd openssl mokutil \
                ; do
        if ! command -v "$prog" >/dev/null; then
            report "[$prog] not installed yet, installing..."
            [[ -n "${exec_to_pkg[$prog]}" ]] && prog=${exec_to_pkg[$prog]}

            install_block "$prog" || fail "unable to install required prog [$prog] this script depends on. abort."
            report "...done"
        fi
    done

    # TODO: need to create dev/ already here, since both dotfiles and private-common
    # either point to it, or point at something in it; not a good solution.
    # better finalise scripts and move them to the public/common dotfiles repo.
    #
    #
    # verify required dirs are existing and have $perms perms:
    for dir in \
            "$BASE_DATA_DIR" \
            "$BASE_DATA_DIR/dev" \
            "$BASE_PROGS_DIR" \
                ; do
        if ! [[ -d "$dir" ]]; then
            if confirm -d Y "[$dir] mountpoint/dir does not exist; simply create a directory instead? (answering 'no' aborts script)"; then
                ensure_d -s "$dir" || fail
            else
                fail "expected [$dir] to be an already-existing dir. abort"
            fi
        fi

        exe "sudo chown $USER:$USER -- '$dir'" || fail "unable to change [$dir] ownership to [$USER:$USER]. abort."
        exe "sudo chmod $perms -- '$dir'" || fail "unable to change [$dir] permissions to [$perms]. abort."
    done
}


install_acpi_events() {
    local file dir  acpi_target  acpi_src  tmpfile

    readonly acpi_target='/etc/acpi/events'
    acpi_src=(
        "$COMMON_DOTFILES/backups/acpi_event_triggers"
    )

    is_laptop && acpi_src+=("$COMMON_DOTFILES/backups/acpi_event_triggers/laptop")
    [[ -n "$PLATFORM" ]] && acpi_src+=("$PLATFORM_DOTFILES/acpi_event_triggers")

    is_d -m 'skipping acpi event triggers installation' "$acpi_target" || return 1

    for dir in "${acpi_src[@]}"; do
        is_d -qn "$dir" || continue
        for file in "$dir/"*; do
            [[ -f "$file" ]] || continue  # TODO: how to validate acpi event files? what are the rules?
            tmpfile="$TMP_DIR/.acpi_setup-$RANDOM"
            exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$file' > '$tmpfile'" || return 1
            exe "sudo install -m644 -CT '$tmpfile' '$acpi_target/$(basename -- "$file")'" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
        done
    done

    return 0
}


setup_udev() {
    local udev_src udev_target file dir tmpfile

    readonly udev_target='/etc/udev/rules.d'
    udev_src=(
        "$COMMON_PRIVATE_DOTFILES/backups/udev"
        "$PRIVATE__DOTFILES/backups/udev"
    )

    is_laptop && udev_src+=("$COMMON_PRIVATE_DOTFILES/backups/udev/laptop")
    [[ -n "$PLATFORM" ]] && udev_src+=("$PLATFORM_DOTFILES/udev")

    is_d -m 'skipping udev file(s) installation' "$udev_target" || return 1

    for dir in "${udev_src[@]}"; do
        is_d -qn "$dir" || continue
        for file in "$dir/"*; do
            [[ -s "$file" && "$file" == *.rules ]] || continue  # note we require '.rules' suffix
            tmpfile="$TMP_DIR/.udev_setup-$RANDOM"
            exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$file' > '$tmpfile'" || return 1
            exe "sudo install -m644 -CT '$tmpfile' '$udev_target/$(basename -- "$file")'" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
        done
    done

    exe "sudo udevadm control --reload-rules"

    return 0
}


setup_pm() {
    local pm_src pm_target file dir pm_state_dir tmpfile target

    readonly pm_target='/etc/pm'
    pm_src=(
        "$COMMON_PRIVATE_DOTFILES/backups/pm"
        "$PRIVATE__DOTFILES/backups/pm"
    )

    is_laptop && pm_src+=("$COMMON_PRIVATE_DOTFILES/backups/pm/laptop")
    [[ -n "$PLATFORM" ]] && pm_src+=("$PLATFORM_DOTFILES/pm")

    is_d -m 'skipping pm file(s) installation' "$pm_target" || return 1

    for dir in "${pm_src[@]}"; do
        is_d -qn "$dir" || continue
        for pm_state_dir in "$dir/"*.d; do
            is_d "$pm_state_dir" || continue
            target="$pm_target/$(basename -- "$pm_state_dir")"  # e.g. /etc/pm/sleep.d, ...power.d
            [[ -d "$target" ]] || { err "[$target] does not exist. should we just create it?"; continue; }

            for file in "$pm_state_dir/"*; do
                is_f -n "$file" || continue
                tmpfile="$TMP_DIR/.pm_setup-$RANDOM"
                exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$file' > '$tmpfile'" || return 1
                exe "sudo install -m755 -CT '$tmpfile' '$target/$(basename -- "$file")'" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
            done
        done
    done

    return 0
}


# https://flatpak.org/setup/Debian
# https://docs.flathub.org/docs/for-users/verification
#   (note providing --user flag would make it per-user, skipping need for sudo)
#
# useful commands:
#   flatpak list --show-details
install_flatpak() {
    install_block 'flatpak flatseal' || return 1  # flatseal is GUI app to manage perms
    #exe 'sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo'  # <- normal/non-verified-only remote

    # only include the 'verified' packages, taken from this secureblue comment:
    # https://www.reddit.com/r/linux/comments/1bq9d3b/flathub_now_marks_unverified_apps/kx1adws/ :
    exe 'sudo flatpak remote-add --if-not-exists --subset=verified flathub-verified https://flathub.org/repo/flathub.flatpakrepo'
}


# see https://wiki.archlinux.org/index.php/S.M.A.R.T.
#
# TODO: maybe instead of systemctl, enable smartd via     sudo vim /etc/default/smartmontools. Uncomment the line start_smartd=yes.   ?
# TODO: enable smart on all drives if not enabeld & remove logic from common_startup?
setup_smartd() {
    local conf c

    conf='/etc/smartd.conf'
    c='DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,35,40 -m smart_mail_alias -M exec /usr/local/bin/smartdnotify'  # TODO: create the script! from there we mail & notify; note script shouldn't write anything to stdout/stderr, otherwise it ends up in syslog

    is_f -m 'cannot configure smartd' "$conf" || return 1
    exe "sudo sed -i --follow-symlinks '/^DEVICESCAN.*$/d' '$conf'"  # nuke previous setting
    exe "echo '$c' | sudo tee --append $conf > /dev/null"

    exe 'systemctl enable --now smartd.service'
}


# needed for wayland, see https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
# also read this: https://wiki.archlinux.org/title/GTK#Wayland_backend
setup_gtk() {
    true  # TODO
}


# TODO: set up msmtprc for system (/etc/msmtprc ?) so sendmail works; don't forget to add aliases, eg 'smart_mail_alias'; refer to arch wiki for more info
setup_mail() {
    true
}


# TODO: how does it compare to monit that debian appears to mention? https://www.debian.org/releases/trixie/release-notes/upgrading.en.html#stop-monitoring-systems
#       nope, monit is general process moniror, see https://mmonit.com/
setup_needrestart() {
    local src_dirs target_confdir file dir tmpfile filename

    readonly target_confdir='/etc/needrestart/conf.d'
    src_dirs=(
        "$COMMON_PRIVATE_DOTFILES/backups/needrestart"
        "$PRIVATE__DOTFILES/backups/needrestart"
    )

    is_laptop && src_dirs+=("$COMMON_PRIVATE_DOTFILES/backups/needrestart/laptop")
    #[[ -n "$PLATFORM" ]] && src_dirs+=("$PLATFORM_DOTFILES/systemd/global")

    is_d -m 'skipping needrestart file(s) installation' "$target_confdir" || return 1

    for dir in "${src_dirs[@]}"; do
        is_d -qn "$dir" || continue
        for file in "$dir/"*; do
            [[ -f "$file" && "$file" =~ \.(conf)$ ]] || continue  # note we require certain suffix
            filename="$(basename -- "$file")"
            tmpfile="$TMP_DIR/.needrestart_setup-$filename"
            filename="${filename/\{USER_PLACEHOLDER\}/$USER}"  # replace the placeholder in filename in case it's templated servicefile

            exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$file' > '$tmpfile'" || { err "sed-ing needrestart file [$file] failed"; continue; }
            exe "sudo install -m644 -CT '$tmpfile' '$target_confdir/$filename'" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
        done
    done
}


setup_logind() {
    local logind_conf logind_confd file

    readonly logind_conf='/etc/systemd/logind.conf'
    readonly logind_confd='/etc/systemd/logind.conf.d'
    file="$COMMON_DOTFILES/backups/logind.conf"

    is_f -m 'skipping configuring logind' "$logind_conf" "$file" || return 1

    if ! grep -Fq "$logind_confd" "$logind_conf"; then  # sanity
        err "[$logind_confd] is not referenced/mentioned in [$logind_conf]! something's changed?"
        return 1
    fi

    exe "sudo install -m644 -CTD '$file' '$logind_confd/custom.conf'" || { err "installing [$file] failed w/ $?"; return 1; }
}


# to temporarily disable lid-switch events:   systemd-inhibit --what=handle-lid-switch sleep 1d
# Note: for env variables, see https://wiki.archlinux.org/title/Systemd/User#Environment_variables
#       likely reasonable to create .conf file in ~/.config/environment.d/ dir
#       alternatively, we already call $ systemctl --user --wait import-environment
#       from our .xsession file
# cmds:
# - see failed services:  sudo systemctl --failed
setup_systemd() {
    local global_sysd_src usr_sysd_src global_sysd_target usr_sysd_target dir

    readonly global_sysd_target='/etc/systemd/system'
    readonly usr_sysd_target="$HOME/.config/systemd/user"
    global_sysd_src=(
        "$COMMON_PRIVATE_DOTFILES/backups/systemd/global"
        "$PRIVATE__DOTFILES/backups/systemd/global"
    )
    usr_sysd_src=(
        "$COMMON_PRIVATE_DOTFILES/backups/systemd/user"
        "$PRIVATE__DOTFILES/backups/systemd/user"
    )

    is_laptop && global_sysd_src+=("$COMMON_PRIVATE_DOTFILES/backups/systemd/global/laptop") && usr_sysd_src+=("$COMMON_PRIVATE_DOTFILES/backups/systemd/user/laptop")
    [[ -n "$PLATFORM" ]] && global_sysd_src+=("$PLATFORM_DOTFILES/systemd/global") && usr_sysd_src+=("$PLATFORM_DOTFILES/systemd/user")

    is_d -m 'skipping systemd file(s) installation' "$global_sysd_target" || return 1
    ensure_d "$usr_sysd_target" || return 1

    __var_expand_move() {
        local sudo in outf tmpfile
        [[ "$1" == -s ]] && { shift; readonly sudo=TRUE; }

        in="$1"; outf="$2"
        tmpfile="$TMP_DIR/.sysd_setup-$RANDOM"

        is_f -n "$in" || return 1
        exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$in' > '$tmpfile'" || { err "sed-ing systemd file [$in] failed"; return $?; }
        exe "${sudo:+sudo }install -m644 -CT '$tmpfile' '$outf'" || { err "installing [$tmpfile] failed"; return 1; }
        return 0
    }

    __process() {
        local usr sudo dir tdir node fname t fname f
        sudo='-s'

        [[ "$1" == --user ]] && { readonly usr=TRUE; unset sudo; shift; }
        readonly dir="$1"; readonly tdir="$2"  # indir, target_dir

        [[ -d "$dir" ]] || return 1
        for node in "$dir/"*; do
            fname="$(basename -- "$node")"
            fname="${fname/\{USER_PLACEHOLDER\}/$USER}"  # replace the placeholder in filename in case it's templated servicefile

            if [[ -f "$node" && "$node" =~ \.(service|target|unit|timer)$ ]]; then  # note we require certain suffixes
                __var_expand_move $sudo "$node" "$tdir/$fname" || continue

                # note do not use the '--now' flag with systemctl enable, nor exe systemctl start,
                # as some service files might be listening on something like target.sleep - those shouldn't be started on-demand like that!
                if [[ "$fname" == *.service ]]; then
                    exe "${sudo:+sudo }systemctl ${usr:+--user }enable '$fname'" || { err "enabling ${usr:+user}${sudo:+global} systemd service [$fname] failed w/ [$?]"; continue; }
                elif [[ "$fname" == *.timer ]]; then
                    exe "${sudo:+sudo }systemctl ${usr:+--user }enable --now '$fname'" || { err "enabling ${usr:+user}${sudo:+global} systemd timer [$fname] failed w/ [$?]"; continue; }
                fi
            elif [[ -d "$node" && "$node" == *.d ]]; then
                t="$tdir/$fname"
                for f in "$node/"*; do
                    is_f -n "$f" && [[ "$f" == *.conf ]] || continue  # note we require certain suffix
                    ensure_d $sudo "$t" || continue
                    __var_expand_move $sudo "$f" "$t/$(basename -- "$f")" || continue
                done
            fi
        done
    }

    # global/system systemd files:
    for dir in "${global_sysd_src[@]}"; do
        __process "$dir" "$global_sysd_target" || continue
    done

    # user systemd files:
    #
    # Note that user services will only run while a user is logged in unless you
    # explicitly enable them to run at boot with $ loginctl enable-linger <username>.
    # "linger" means remain after logout, but also start at boot.
    for dir in "${usr_sysd_src[@]}"; do
        __process --user "$dir" "$usr_sysd_target" || continue
    done

    # reload the rules in case existing rules changed:
    exe 'systemctl --user --now daemon-reload'  # --user flag manages the user services under ~/.config/systemd/user/
    exe 'sudo systemctl daemon-reload'

    unset __var_expand_move __process
}

# unlock default keyring on login
#
# as per https://wiki.archlinux.org/title/GNOME/Keyring#PAM_step
# this should only be used if not using DM/display manager
#
# see also: https://wiki.gnome.org/Projects/GnomeKeyring/Pam/Manual
#
# TODO: should we perhaps see if the line exists, but is commented out? note hyphen might be a valid comment-character for PAM files
setup_pam_login() {
    local f
    f='/etc/pam.d/login'

    is_f "$f" || return 1

    if ! grep -Eq '^auth\s+optional\s+pam_gnome_keyring.so$' "$f"; then
        exe "echo 'auth       optional     pam_gnome_keyring.so' | sudo tee --append '$f' > /dev/null"
    fi

    if ! grep -Eq '^session\s+optional\s+pam_gnome_keyring.so\s+auto_start$' "$f"; then
        exe "echo 'session    optional     pam_gnome_keyring.so auto_start' | sudo tee --append '$f' > /dev/null"
    fi
}


# https://wiki.debian.org/AppArmor/HowToUse
# note profiles from apparmor-profiles are not installed by default; to do that, don
# $ sudo cp /usr/share/apparmor/extra-profiles/usr.bin.example /etc/apparmor.d/   # to install profile
# $ sudo aa-complain /etc/apparmor.d/usr.bin.example   # set profile to complain mode
#
# good resource: https://documentation.ubuntu.com/server/how-to/security/apparmor/index.html
# note minor changes to profiles can be done under /etc/apparmor.d/local/
# some commands:
#   - view current status of aa profles:
#     sudo apparmor_status
#   - place profile into complain mode:
#     sudo aa-complain /path-to-bin
#   - place profile into enforce mode:
#     sudo aa-enforce /path-to-bin
#   - load a profile into kernel; -r option makes modifications to take effect:
#     sudo apparmor_parser -r /etc/apparmor.d/profile.name
#   - reload all profiles:
#     sudo systemctl reload apparmor.service
#   - scan apparomor audit messages, review them & update the profiles:
#     sudo aa-logprof
setup_apparmor() {
    [[ "$(cat /sys/module/apparmor/parameters/enabled)" != Y ]] && err "apparmor not enabled!!"  # sanity
    add_to_group  adm  # adm used for system monitoring tasks; members can read log files etc

    # as per https://wiki.debian.org/AppArmor/HowToUse :
    # if auditd is installed, then aa-notify desktop should be modified to use auditd log:
    if is_pkg_installed 'auditd'; then
        local aa_notif_desktop=/etc/xdg/autostart/aa-notify.desktop

        if [[ -s "$aa_notif_desktop" ]]; then
            local cmd='Exec=sudo aa-notify -p -f /var/log/audit/audit.log'
            if ! grep -Fxq "$cmd" "$aa_notif_desktop"; then
                exe "sudo sed -i --follow-symlinks 's/^Exec=/#Exec=/g' $aa_notif_desktop"  # comment original one out
                exe "echo $cmd | sudo tee --append $aa_notif_desktop > /dev/null"
            fi
        else
            err "[$aa_notif_desktop] not a file - is apparmor-notify pkg installed?"
        fi
    fi
}


# note it should be automatically installed as flatpak dependency.
#
# other alternatives:
# - firejail; larger attack surface (https://madaidans-insecurities.github.io/linux.html#firejail), but _way_ easier to use
#   - https://github.com/netblue30/firejail
#   - comparison to bubblewrap, docker etc: https://github.com/netblue30/firejail/wiki/Frequently-Asked-Questions#how-does-it-compare-with-docker-lxc-nspawn-bubblewrap
# - am: (appimage package manager that also does sandboxing)  https://github.com/ivan-hc/AM
#   - somewhat similar is https://github.com/mijorus/gearlever (avail as flatpak lol)
# - systemd-nspawn
# - good hackernews on the topic: https://news.ycombinator.com/item?id=36681912
# see also:
# - https://github.com/igo95862/bubblejail
# - https://gist.github.com/ageis/f5595e59b1cddb1513d1b425a323db04  (hardening via systemd)
setup_bubblewrap() {
    true
}


setup_hosts() {
    local file tmpfile current_hostline

    readonly file="$PRIVATE__DOTFILES/backups/hosts-header.tmpl"
    readonly tmpfile="$TMP_DIR/hosts.head"  # note result file won't be 'hosts', but 'hosts.head'

    _extract_current_hostname_line() {
        local file current

        readonly file="$1"
        current="$(grep -E '^127\.0\.1\.1\s+' "$file")"
        if ! is_single "$current"; then
            err "[$file] contained either more or less than 1 line(s) containing our hostname. check manually."
            return 1
        fi

        echo "$current"
        return 0
    }

    is_f /etc/hosts || return 1

    if [[ -f "$file" ]]; then
        current_hostline="$(_extract_current_hostname_line /etc/hosts)" || return 1
        exe "sed -e 's/{HOSTS_LINE_PLACEHOLDER}/$current_hostline/g' -e 's/{HOSTNAME}/$HOSTNAME/g' $file > $tmpfile" || { err; return 1; }

        exe "sudo install -m644 -C --backup=numbered '$tmpfile' /etc" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
        exe "rm -- '$tmpfile'"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
        return 1
    fi

    unset _extract_current_hostname_line
}


setup_sudoers() {
    local sudoers_dest file tmpfile

    readonly sudoers_dest='/etc/sudoers.d'
    readonly tmpfile="$TMP_DIR/sudoers-$RANDOM"
    readonly file="$COMMON_PRIVATE_DOTFILES/backups/sudoers"

    is_d -m 'skipping sudoers file installation' "$sudoers_dest" || return 1
    is_f -m "won't install it" "$file" || return 1

    exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$file' > '$tmpfile'" || return 1
    exe "sudo install -m440 -CT '$tmpfile' '$sudoers_dest/sudoers'" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
}


# https://wiki.debian.org/UnattendedUpgrades for unattended-upgrades setup
setup_apt() {
    local apt_dir file

    readonly apt_dir='/etc/apt'

    is_d -m 'skipping apt conf installation' "$apt_dir" || return 1
    for file in \
            preferences \
            apt.conf \
                ; do
        file="$COMMON_DOTFILES/backups/apt_conf/$file"

        is_f -m "won't install it" "$file" || continue
        exe "sudo install -m644 -C --backup=numbered '$file' '$apt_dir'" || { err "installing [$file] failed w/ $?"; return 1; }
    done

    for file in \
            debian.sources \
                ; do
        file="$COMMON_DOTFILES/backups/apt_conf/$file"

        is_f -m "won't install it" "$file" || continue
        exe "sudo install -m644 -C '$file' '$apt_dir/sources.list.d'" || { err "installing [$file] failed w/ $?"; return 1; }
    done

    # NOTE: 02periodic _might_ be duplicating the unattended-upgrades activation
    # config located at apt/apt.conf.d/20auto-upgrades; you should go with either,
    # not both (see the debian wiki link), ie it might be best to remove 20auto-upgrades; TODO: do it maybe automatically?
    # if both it and 02periodic exist;
    # # TODO 2: according to
    # https://wiki.debian.org/UnattendedUpgrades#Modifying_download_and_upgrade_schedules_.28on_systemd.29,
    # we _might_ need to install periodic, as systemd timers are already doing _something_
    #
    # copy to apt.conf.d/:
    for file in \
            02periodic \
                ; do
        file="$COMMON_DOTFILES/backups/apt_conf/$file"

        is_f -m "won't install it" "$file" || continue
        exe "sudo install -m644 -C '$file' '$apt_dir/apt.conf.d'" || { err "installing [$file] failed w/ $?"; return 1; }
    done

    retry 2 "sudo apt-get --allow-releaseinfo-change  -y update" || err "apt-get update failed with $?"

    if [[ "$MODE" -eq 1 ]]; then
        retry 2 "sudo apt-get upgrade --without-new-pkgs -y" || err "[apt-get upgrade] failed with $?"
        retry 2 "sudo apt-get dist-upgrade -y" || err "[apt-get dist-upgrade] failed with $?"
    fi
}


# symlinked crontabs don't work!
# TODO: deprecate crontab & move to systemd timers?
setup_crontab() {
    local cron_dir weekly_crondir tmpfile file i

    readonly cron_dir='/etc/cron.d'  # where crontab will be installed at
    readonly tmpfile="$TMP_DIR/.crontab-$RANDOM"
    readonly file="$PRIVATE__DOTFILES/backups/crontab"
    readonly weekly_crondir='/etc/cron.weekly'

    is_d -m 'skipping crontab installation' "$cron_dir" || return 1

    if [[ -f "$file" ]]; then
        exe "sed --follow-symlinks 's/{USER_PLACEHOLDER}/$USER/g' '$file' > '$tmpfile'" || return 1
        exe "sudo install -m644 -CT '$tmpfile' '$cron_dir/$(basename -- "$file")'" || { err "installing [$tmpfile] failed w/ $?"; return 1; }
        exe "rm -- '$tmpfile'"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
    fi

    # install/link weekly scripts:
    is_d -m 'skipping weekly scripts installation' "$weekly_crondir" || return 1
    for i in \
            hosts-block-update \
                ; do
        i="$BASE_DATA_DIR/dev/scripts/$i"
        is_f -nm "can't dump into $weekly_crondir" "$i" || continue

        #create_link -s "$i" "${weekly_crondir}/"  # linked crontabs don't work!
        exe "sudo install -m644 -CT '$i' '$weekly_crondir/$(basename -- "$i")'" || { err "installing [$i] failed w/ $?"; return 1; }
    done
}


# pass '-s' or '--sudo' as first arg to execute as sudo
# TODO: mv, cp, ln, install commands have --backup option (eg --backup=numbered)
#
backup_original_and_copy_file() {
    local sudo file dest_dir filename i old_suffixes

    [[ "$1" == -s || "$1" == --sudo ]] && { shift; readonly sudo=sudo; }
    readonly file="$1"          # full path of the file to be copied
    readonly dest_dir="${2%/}"  # full path of the destination directory to copy to

    readonly filename="$(basename -- "$file")"

    $sudo test -d "$dest_dir" || { err "second arg [$dest_dir] was not a dir"; return 1; }
    [[ "$dest_dir" == *.d ]] && err "sure we want to be backing up in [$dest_dir]?"  # sanity

    # back up the destination file, if it already exists and differs from new content:
    if $sudo test -f "$dest_dir/$filename"; then
        $sudo cmp -s "$file" "$dest_dir/$filename" && return 0  # same contents, bail
        declare -a old_suffixes

        # collect older .orig files' suffixes and increment latest value for the new file:
        while IFS= read -r -d $'\0' i; do
            i="${i##*.}"
            is_digit "$i" && old_suffixes+=("$i")
        done < <($sudo find -L "$dest_dir/" -maxdepth 1 -mindepth 1 -type f -regextype posix-extended -regex ".*/${filename}\.orig\.[0-9]+$" -print0)

        i=0  # default
        if [[ ${#old_suffixes[@]} -gt 0 ]]; then
            i="$(printf '%d\n' "${old_suffixes[@]}" | sort -rn | head -n1)"  # take largest (ie latest) suffix value
            is_digit "$i" || { err "last found suffix was not digit: [$i]; setting suffix to RANDOM"; i="$RANDOM"; } && (( i++ ))  # note (( i++ )) errors if i=0, but it increments just fine
        fi

        exe "$sudo cp -- '$dest_dir/$filename' '$dest_dir/${filename}.orig.$i'"  # TODO: should we mv instead?
    fi

    exe "$sudo cp -- '$file' '$dest_dir'"
}


# !! note the importance of optional trailing slash for $install_dir param;
clone_repo_subdir() {
    local user repo path install_dir hub tmpdir

    readonly user="$1"
    readonly repo="$2"
    readonly path="${3#/}"  # note remove leading slash
    install_dir="$4"  # if has trailing / then $repo won't be appended, eg pass './' to clone to $PWD
    readonly hub=${5:-github.com}  # OPTIONAL; defaults to github.com;

    [[ -z "$install_dir" ]] && { err "need to provide target directory."; return 1; }
    [[ "$install_dir" != */ ]] && install_dir+="/$(basename -- "$path")"

    if [[ -d "$install_dir" ]]; then
        rm -rf -- "$install_dir" || { err "removing existing install_dir [$install_dir] failed w/ $?"; return 1; }
    fi

    tmpdir="$TMP_DIR/$repo-${user}-${RANDOM}"
    exe "git clone -n --depth=1 --filter=tree:0 https://$hub/$user/${repo}.git '$tmpdir'" || { err "cloning [$hub/$user/$repo] failed w/ $?"; return 1; }
    exe "git -C '$tmpdir' sparse-checkout set --no-cone $path" || return 1
    exe "git -C '$tmpdir' checkout" || return 1
    exe "mv -- '$tmpdir/$path' '$install_dir'" || return 1
    #exe "git -C '$install_dir' pull" || return 1
}


# !! note the importance of optional trailing slash for $install_dir param;
clone_or_pull_repo() {
    local user repo install_dir hub

    readonly user="$1"
    readonly repo="$2"
    install_dir="$3"  # if has trailing / then $repo won't be appended, eg pass './' to clone to $PWD
    readonly hub=${4:-github.com}  # OPTIONAL; defaults to github.com;

    [[ -z "$install_dir" ]] && { err "need to provide target directory."; return 1; }
    [[ "$install_dir" != */ ]] && install_dir+="/$repo"

    if ! [[ -d "$install_dir/.git" ]]; then
        exe "git clone --recursive -j8 https://$hub/$user/${repo}.git '$install_dir'" || { err "cloning [$hub/$user/$repo] failed w/ $?"; return 1; }

        exe "git -C '$install_dir' remote set-url origin git@${hub}:$user/${repo}.git" || return 1
        exe "git -C '$install_dir' remote set-url --push origin git@${hub}:$user/${repo}.git" || return 1
    elif is_ssh_key_available; then
        exe "git -C '$install_dir' pull" || { err "git pull for [$hub/$user/$repo] failed w/ $?"; return 1; }  # TODO: retry?
        exe "git -C '$install_dir' submodule update --init --recursive" || return 1  # make sure to pull submodules
    fi
}


# tip: run "exportfs -v" to show all exported nfs shares
# loads of mounting examples also @ https://help.ubuntu.com/community/Fstab
install_nfs_server() {
    local nfs_conf client_ip share

    readonly nfs_conf='/etc/exports'

    confirm "wish to install & configure nfs server?" || return 1
    is_laptop && ! confirm "you're on laptop; sure you wish to install nfs server?" && return 1

    install_block 'nfs-kernel-server' || { err "unable to install nfs-kernel-server. aborting nfs server install/config."; return 1; }

    is_f -m 'skipping nfs server installation' "$nfs_conf" || return 1

    while true; do
        confirm "$(report "add ${client_ip:+another }client IP for the exports list?")" || break

        read -r -p "enter client ip: " client_ip

        is_valid_ip "$client_ip" || { err "not a valid ip: [$client_ip]"; continue; }

        read -r -p "enter share to expose (leave blank to default to [$NFS_SERVER_SHARE]): " share

        share=${share:-"$NFS_SERVER_SHARE"}
        [[ "$share" != /* ]] && { err "share needs to be defined as full path."; continue; }
        is_d "$share" || continue

        # TODO: automate multi client/range options:
        # entries are basically:         directory machine1(option11,option12) machine2(option21,option22)
        # to set a range of ips, then:   directory 192.168.0.0/255.255.255.0(ro)
        if ! grep -q "${share}.*${client_ip}" "$nfs_conf"; then
            report "adding [$share] for $client_ip to $nfs_conf"
            exe "echo $share ${client_ip}\(rw,sync,no_subtree_check\) | sudo tee --append $nfs_conf > /dev/null"
        else
            report "an entry for exposing [$share] to $client_ip is already present in $nfs_conf"
        fi
    done

    # exports the shares:
    exe 'sudo exportfs -ra' || err

    return 0
}


# fstab entries are ok only if we're a desktop, and the NFS server is _always_ on
# TODO: consider moving from fstab to systemd mount @ /run/systemd/generator/
_install_nfs_client_stationary() {
    local fstab mountpoint nfs_share default_mountpoint server_ip prev_server_ip
    local mounted_shares used_mountpoints changed

    readonly fstab='/etc/fstab'
    readonly default_mountpoint='/mnt/nfs'

    declare -a mounted_shares used_mountpoints

    is_f -m 'cannot add fstab entry' "$fstab" || return 1

    prev_server_ip="$SERVER_IP"  # default

    while true; do
        confirm "$(report "add ${server_ip:+another }nfs server entry to fstab?")" || break

        read -r -p "enter server ip${prev_server_ip:+ (leave blank to default to [$prev_server_ip])}: " server_ip
        [[ -z "$server_ip" ]] && server_ip="$prev_server_ip"
        is_valid_ip "$server_ip" || { err "not a valid ip: [$server_ip]"; continue; }

        read -r -p "enter local mountpoint to mount nfs share to (leave blank to default to [$default_mountpoint]): " mountpoint
        [[ -z "$mountpoint" ]] && mountpoint="$default_mountpoint"
        list_contains "$mountpoint" "${used_mountpoints[@]}" && { report "selected mountpoint [$mountpoint] has already been used for previous definition"; continue; }
        create_mountpoint "$mountpoint" || continue

        read -r -p "enter remote share to mount (leave blank to default to [$NFS_SERVER_SHARE]): " nfs_share
        [[ -z "$nfs_share" ]] && nfs_share="$NFS_SERVER_SHARE"
        list_contains "${server_ip}${nfs_share}" "${mounted_shares[@]}" && { report "selected [${server_ip}:${nfs_share}] has already been used for previous definition"; continue; }
        [[ "$nfs_share" != /* ]] && { err "remote share needs to be defined as full path."; continue; }

        if ! grep -q "${server_ip}:${nfs_share}.*${mountpoint}" "$fstab"; then
            report "adding [${server_ip}:$nfs_share] mounting to [$mountpoint] in $fstab"
            exe "echo ${server_ip}:${nfs_share} ${mountpoint} nfs noauto,x-systemd.automount,x-systemd.mount-timeout=10,_netdev,x-systemd.device-timeout=10,timeo=14,rsize=8192,wsize=8192,x-systemd.idle-timeout=1min 0 0 \
                    | sudo tee --append $fstab > /dev/null"
            changed=1
        else
            err "an nfs share entry for [${server_ip}:${nfs_share}] in $fstab already exists."
        fi

        prev_server_ip="$server_ip"
        used_mountpoints+=("$mountpoint")
        mounted_shares+=("${server_ip}${nfs_share}")
    done

    # force fstab reload & mount the new remote share(s):
    [[ "$changed" == 1 ]] && exe 'sudo systemctl daemon-reload' && exe "sudo systemctl restart remote-fs.target local-fs.target"

    return 0
}


# more lax mounting than fstab mountpoints
_install_nfs_client_laptop() {
    local autofs_d root_confd filename i changed target

    readonly autofs_d='/etc/auto.master.d'
    readonly root_confd="$COMMON_PRIVATE_DOTFILES/backups/autofs"

    install_block 'autofs' || { err "unable to install autofs. aborting nfs client install/config."; return 1; }

    is_d -m 'cannot add autofs nfs config' "$autofs_d" || return 1
    [[ -d "$root_confd" ]] && ! is_dir_empty "$root_confd" || return 0

    for i in "$root_confd/servers/"*; do
        [[ -f "$i" ]] || continue
        filename="$(basename -- "$i")"
        [[ "$filename" == auto.* ]] || { err "incorrect filename for autofs server definition: [$filename]"; continue; }
        target="/etc/$filename"
        cmp -s "$i" "$target" && continue  # no changes
        exe "sudo install -m644 -CT '$i' '$target'" || { err "installing [$i] failed w/ $?"; return 1; }
        changed=1
    done

    for i in "$root_confd/master.d/"*; do
        [[ -f "$i" ]] || continue
        filename="$(basename -- "$i")"
        [[ "$filename" == *.autofs ]] || { err "incorrect filename for autofs master.d definition: [$filename]"; continue; }
        target="$autofs_d/$filename"
        cmp -s "$i" "$target" && continue  # no changes
        exe "sudo install -m644 -CT '$i' '$target'" || { err "installing [$i] failed w/ $?"; return 1; }
        changed=1
    done

    [[ "$changed" == 1 ]] && exe 'sudo service autofs reload'

    return 0
}


install_nfs_client() {
    confirm "wish to install & configure nfs client?" || return 1

    install_block 'nfs-common' || { err "unable to install nfs-common. aborting nfs client install/config."; return 1; }

    if is_laptop; then
        _install_nfs_client_laptop
    else
        _install_nfs_client_stationary
    fi
}


# as for security, look:
#  - https://linux-audit.com/audit-and-harden-your-ssh-configuration/
#  - https://www.debian.org/doc/manuals/securing-debian-howto/
#  - https://wiki.debian.org/SELinux/Setup
#  - http://adeptus-mechanicus.com/codex/sudoctrl/sudoctrl.html
#  - https://vincent.bernat.ch/en/blog/2017-linux-bridge-isolation
#  - https://github.com/CISOfy/lynis - security audit script
install_ssh_server() {
    local sshd_confdir config banner

    readonly sshd_confdir="/etc/ssh"
    readonly config="$COMMON_PRIVATE_DOTFILES/backups/sshd_config"
    readonly banner="$COMMON_PRIVATE_DOTFILES/backups/ssh_banner"

    confirm "wish to install & configure ssh server?" || return 1
    is_laptop && ! confirm "you're on laptop; sure you wish to install ssh server?" && return 1

    install_block 'openssh-server' || { err "unable to install openssh-server. aborting sshd install/config."; return 1; }

    is_d -m 'skipping sshd conf installation' "$sshd_confdir" || return 1

    # install sshd config:
    if [[ -f "$config" ]]; then
        exe "sudo install -m644 -C '$config' '$sshd_confdir'" || { err "installing [$config] failed w/ $?"; return 1; }
    else
        err "expected configuration file at [$config] does not exist; aborting sshd configuration."
        return 1
    fi

    # install ssh banner:
    if [[ -f "$banner" ]]; then
        exe "sudo install -m644 -C '$banner' '$sshd_confdir'" || { err "installing [$banner] failed w/ $?"; return 1; }
    else
        err "expected sshd banner file at [$banner] does not exist; won't install it."
        #return 1  # don't return, it's just a banner.
    fi

    exe "sudo systemctl enable --now sshd.service"  # note --now flag effectively also starts the service immediately

    return 0
}


create_mountpoint() {
    local mountpoint

    readonly mountpoint="$1"

    [[ -z "$mountpoint" ]] && { err "cannot pass empty mountpoint arg"; return 1; }
    ensure_d -s "$mountpoint" || return 1
    exe "sudo chmod 777 -- '$mountpoint'" || { err; return 1; }  # TODO: why 777 ???

    return 0
}


# TODO: consider moving from fstab to systemd mount @ /run/systemd/generator/
install_sshfs() {
    local fuse_conf mountpoint default_mountpoint fstab server_ip remote_user ssh_port sel_ips_to_user
    local prev_server_ip used_mountpoints mounted_shares ssh_share identity_file

    readonly fuse_conf="/etc/fuse.conf"
    readonly default_mountpoint="/mnt/ssh"
    readonly fstab="/etc/fstab"
    readonly ssh_port=443
    readonly identity_file="$HOME/.ssh/id_rsa_only_for_server_connect"
    declare -a mounted_shares used_mountpoints
    declare -A sel_ips_to_user

    confirm "wish to install and configure sshfs?" || return 1
    [[ -f "$fstab" ]] || { err "[$fstab] does not exist; cannot add fstab entry!"; return 1; }
    if ! [[ -f "$identity_file" ]]; then
        confirm "[$identity_file] ssh key does not exist; still continue?" || return 1
    fi
    install_block 'sshfs' || { err "unable to install sshfs. aborting sshfs install/config."; return 1; }

    # note that 'user_allow_other' uncommenting makes sense only if our related fstab
    # entry has the 'allow_other' opt:
    if ! [[ -r "$fuse_conf" && -f "$fuse_conf" ]]; then
        err "[$fuse_conf] is not readable; cannot uncomment '#user_allow_other' prop in it."
    elif grep -Eq '^#user_allow_other' "$fuse_conf"; then  # hasn't been uncommented yet
        exe "sudo sed -i --follow-symlinks 's/#user_allow_other/user_allow_other/g' $fuse_conf"
        [[ $? -ne 0 ]] && { err "uncommenting '#user_allow_other' in [$fuse_conf] failed"; return 2; }
    elif grep -q 'user_allow_other' "$fuse_conf"; then
        true  # do nothing; already uncommented, all good;
    else
        err "[$fuse_conf] appears not to contain config value 'user_allow_other'; check manually what's up; not aborting"
    fi

    prev_server_ip="$SERVER_IP"  # default

    while true; do
        confirm "$(report "add ${server_ip:+another }sshfs entry to fstab?")" || break

        read -r -p "enter server ip${prev_server_ip:+ (leave blank to default to [$prev_server_ip])}: " server_ip
        [[ -z "$server_ip" ]] && server_ip="$prev_server_ip"
        is_valid_ip "$server_ip" || { err "not a valid ip: [$server_ip]"; continue; }

        read -r -p "enter remote user to log in as (leave blank to default to your local user, [$USER]): " remote_user
        [[ -z "$remote_user" ]] && remote_user="$USER"

        read -r -p "enter local mountpoint to mount sshfs share to (leave blank to default to [$default_mountpoint]): " mountpoint
        [[ -z "$mountpoint" ]] && mountpoint="$default_mountpoint"
        list_contains "$mountpoint" "${used_mountpoints[@]}" && { report "selected mountpoint [$mountpoint] has already been used for previous definition"; continue; }
        create_mountpoint "$mountpoint" || continue

        read -r -p "enter remote share to mount (leave blank to default to [$SSH_SERVER_SHARE]): " ssh_share
        [[ -z "$ssh_share" ]] && ssh_share="$SSH_SERVER_SHARE"
        list_contains "${server_ip}${ssh_share}" "${mounted_shares[@]}" && { report "selected [${server_ip}:${ssh_share}] has already been used for previous definition"; continue; }
        [[ "$ssh_share" != /* ]] && { err "remote share needs to be defined as full path."; continue; }

        if ! grep -Eq "${remote_user}@${server_ip}:${ssh_share}.*${mountpoint}" "$fstab"; then
            report "adding [${server_ip}:$ssh_share] mounting to [$mountpoint] in $fstab..."
            # TODO: you might want to add 'default_permissions,uid=USER_ID_N,gid=USER_GID_N' to the mix as per https://wiki.archlinux.org/index.php/SSHFS:
            exe "echo ${remote_user}@${server_ip}:${ssh_share} $mountpoint fuse.sshfs port=${ssh_port},noauto,x-systemd.automount,_netdev,users,idmap=user,follow_symlinks,IdentityFile=${identity_file},allow_other,reconnect 0 0 \
                    | sudo tee --append $fstab > /dev/null"

            sel_ips_to_user["$server_ip"]="$remote_user"
        else
            err "an ssh share entry for [${server_ip}:${ssh_share}] in $fstab already exists."
        fi

        prev_server_ip="$server_ip"
        used_mountpoints+=("$mountpoint")
        mounted_shares+=("${server_ip}${ssh_share}")
    done

    #report "sudo ssh-ing to entered IPs [${!sel_ips_to_user[*]}], so our root would have the remote in the /root/.ssh/known_hosts ..."
    #report "select [yes] if asked whether to add entry to known hosts"

    for server_ip in "${!sel_ips_to_user[@]}"; do
        remote_user="${sel_ips_to_user[$server_ip]}"
        #report "testing ssh connection to ${remote_user}@${server_ip}..."
        #exe "sudo ssh -p ${ssh_port} -o ConnectTimeout=7 ${remote_user}@${server_ip} echo ok"

        if [[ -f "${identity_file}.pub" ]]; then
            if confirm "try to ssh-copy-id public key to [$server_ip]?"; then
                # install public key on ssh server:
                ssh-copy-id -i "${identity_file}.pub" -p "$ssh_port" ${remote_user}@${server_ip} || err "ssh-copy-id to [${remote_user}@${server_ip}] failed with $?"
            fi
        fi

        # add $server_ip to root's known_hosts, if not already present:
        check_progs_installed  ssh-keygen ssh-keyscan || { err "some necessary ssh tools not installed, check that out"; return 1; }
        if [[ -z "$(sudo ssh-keygen -F "$server_ip")" ]]; then
            exe "sudo ssh-keyscan -H '$server_ip' >> /root/.ssh/known_hosts" || err "adding host [$server_ip] to /root/.ssh/known_hosts failed"
        fi
        # note2: also could circumvent known_hosts issue by adding 'StrictHostKeyChecking=no'; it does add a bit insecurity tho
    done

    # force fstab reload & mount the new remote share(s):
    [[ "${#sel_ips_to_user[@]}" -gt 0 ]] && exe 'sudo systemctl daemon-reload' && exe "sudo systemctl restart remote-fs.target local-fs.target"

    return 0
}


# "deps" as in git repos/py modules et al our system setup depends on;
# if equivalent is avaialble at deb repos, its installation should be
# moved to  install_from_repo()
#
# aslo, should we extract python modules out?
install_deps() {
    local u

    _install_tmux_deps() {
        local plugins_dir dir

        readonly plugins_dir="$HOME/.tmux/plugins"

        if ! [[ -d "$plugins_dir/tpm" ]]; then
            clone_or_pull_repo "tmux-plugins" "tpm" "$plugins_dir"
            report "don't forget to install tmux plugins by running <prefix + I> in tmux later on." && sleep 4
        elif ! is_dir_empty "$plugins_dir"; then
            # update all the tmux plugins, including the plugin manager itself:
            for dir in "$plugins_dir"/*; do
                [[ -d "$dir" && -d "$dir/.git" ]] && exe "git -C '$dir' pull"
            done
        fi

        # install tmux-fingers plugin binary counterpart:
        # note there's rust port of fingers
        # - https://github.com/fcsonline/tmux-thumbs - but appears to be unmaintained ('25) & working poorly
        install_bin_from_git -N tmux-fingers  Morantron/tmux-fingers '-linux-x86_64'  # expected binary name from https://github.com/Morantron/tmux-fingers/blob/master/tmux-fingers.tmux
    }

    _install_mutt_deps() {
        true
    }

    # see also: https://github.com/romkatv/zsh4humans
    #           https://github.com/zimfw/zimfw (yes, for real)
    # essentially the same installer stanza we have at the header of .zshrc
    _install_zsh_deps() {
        local install_dir

        readonly install_dir="$BASE_PROGS_DIR/zinit"
        clone_or_pull_repo zdharma-continuum zinit "$BASE_PROGS_DIR"  # https://github.com/zdharma-continuum/zinit#manual

        # default ZINIT[HOME_DIR], where zinit creates all working dirs:
        ensure_d "$HOME/.local/share/zinit/"
    }

    _install_vifm_deps() {
        local plugins_dir plugin

        readonly plugins_dir="$HOME/.config/vifm/plugins"
        is_d -m "can't install vifm plugin(s)" "$plugins_dir" || return 1

        # https://github.com/vifm/vifm/tree/master/data/plugins/ueberzug
        for plugin in 'ueberzug'; do
            clone_repo_subdir  vifm vifm "data/plugins/$plugin" "$plugins_dir"
        done
    }

    _install_laptop_deps() {  # TODO: does this belong in install_deps()?
        is_laptop || return

        __install_wifi_driver() {
            local wifi_info rtl_driver

            # TODO: deprecated installation method, we should install via DKMS
            #       instead: https://github.com/lwfinger/rtw88#installation-using-dkms-
            __install_rtlwifi_new() {  # custom driver installation, pulling from github
                local repo tmpdir

                err "lwfinger github-hosted driver logic is out-dated in our script, have to abort until we've updated it :("
                return 1

                # TODO: different repo for different card series! e.g. there's also /rtw89
                repo='https://github.com/lwfinger/rtw88'

                report "installing Realtek rtw88 series driver for card [$rtl_driver]"
                tmpdir="$TMP_DIR/realtek-driver-${RANDOM}/build"
                exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
                exe "pushd $tmpdir" || return 1
                exe "make clean" || return 1

                #create_deb_install_and_store realtek-wifi-github  # doesn't work with checkinstall
                exe "sudo make install" || err "[$rtl_driver] realtek wifi driver make install failed"

                exe "popd"
                exe "sudo rm -rf -- $tmpdir"
            }

            # consider using   lspci -vnn | grep -A5 WLAN | grep -qi intel
            readonly wifi_info="$(sudo lshw -C network | grep -iA 5 'Wireless interface')"

            # TODO: with one intel card we had some UNCLAIMED in lspci output, instead of
            # wireless interface'; went ok after intel drivers were installed tho
            if grep -iq 'vendor.*Intel' <<< "$wifi_info"; then
                report "we have intel wifi; installing intel drivers..."
                install_block 'firmware-iwlwifi'
            elif grep -iq 'vendor.*Realtek' <<< "$wifi_info"; then
                report "we have realtek wifi; installing realtek drivers..."
                rtl_driver="$(grep -Poi '\s+driver=\Krtl\w+(?=\s+\S+)' <<< "$(sudo lshw -C network)")"
                is_single "$rtl_driver" || { err "realtek driver from lshw output was [$rtl_driver]"; return 1; }

                install_block 'firmware-realtek'                     # either from repos, or...
                #__install_rtlwifi_new; unset __install_rtlwifi_new  # ...this

                # add config to solve the intermittent disconnection problem; YMMV (https://github.com/lwfinger/rtlwifi_new/issues/126):
                #     note: 'ips, swlps, fwlps' are power-saving options.
                #     note2: ant_sel=1 or =2
                #exe "echo options $rtl_driver ant_sel=1 fwlps=0 | sudo tee /etc/modprobe.d/$rtl_driver.conf"
                #exe "echo options $rtl_driver ant_sel=1 msi=1 ips=0 | sudo tee /etc/modprobe.d/$rtl_driver.conf"

                #exe "sudo modprobe -r $rtl_driver" || { err "unable removing modprobe [$rtl_driver]"; return 1; }
                #exe "sudo modprobe $rtl_driver" || { err "unable adding modprobe [$rtl_driver]; make sure secure boot is turned off in BIOS"; return 1; }
            else
                err "can't detect Intel nor Realtek wifi; whose card do we have?"
            fi
        }

        # xinput is for input device configuration; see  https://wiki.archlinux.org/index.php/Libinput
        # evtest can display pressure and placement of touchpad input in realtime; note it cannot run together w/ xserver, so better ctrl+alt+F2 to another tty
        # TODO: doesn't xinput depend on synaptic driver, ie it doesnt work with the newer libinput driver?
        #       fyi: "xinput is utility to list available input devices, query information about a device and change input device settings"
        #       note some of our scripts depend on xinput
        # note: blueman lists bluez as dep, that contains the daemon for bt devices
        # note: evtest is EOL and evemu-record from evemu-tools pkg should be used
        install_block '
            libinput-tools
            xinput
            evtest
            evemu-tools
            blueman
        '
        # old removed ones:
        #   - xfce4-power-manager

        # batt output (requires spark):
        clone_or_pull_repo "laur89" "Battery" "$BASE_PROGS_DIR"  # https://github.com/laur89/Battery
        create_link "${BASE_PROGS_DIR}/Battery/battery" "$HOME/bin/battery"

        __install_wifi_driver && sleep 5; unset __install_wifi_driver  # keep last, as this _might_ restart wifi kernel module
    }

    # ls colors:  # https://github.com/trapd00r/LS_COLORS
    # used by both bash & zsh
    # see also:
    #   - https://github.com/sharkdp/vivid - themeable LS_COLORS generator
    clone_or_pull_repo trapd00r LS_COLORS "$BASE_PROGS_DIR"

    # prettyping:  # https://github.com/denilsonsa/prettyping
    # see also: gping
    install_from_url  prettyping 'https://raw.githubusercontent.com/denilsonsa/prettyping/master/prettyping'

    # bash-git-prompt:
    # alternatively consider https://github.com/starship/starship !!
    clone_or_pull_repo "magicmonty" "bash-git-prompt" "$BASE_PROGS_DIR"

    # bash-preexec:  # https://github.com/rcaloras/bash-preexec
    # note this is known dependency of some functions/programs, such as
    # - atuin
    # - fancy-ctrl-z()
    clone_or_pull_repo rcaloras bash-preexec "$BASE_PROGS_DIR"

    # bars (as in bar-charts) in shell:
    #  note: see also https://github.com/sindresorhus/sparkly-cli
    clone_or_pull_repo "holman" "spark" "$BASE_PROGS_DIR"  # https://github.com/holman/spark
    create_link "${BASE_PROGS_DIR}/spark/spark" "$HOME/bin/spark"

    # imgur uploader:
    clone_or_pull_repo "ram-on" "imgurbash2" "$BASE_PROGS_DIR"  # https://github.com/ram-on/imgurbash2
    create_link "${BASE_PROGS_DIR}/imgurbash2/imgurbash2" "$HOME/bin/imgurbash2"

    # imgur uploader 2:
    #clone_or_pull_repo "tangphillip" "Imgur-Uploader" "$BASE_PROGS_DIR"  # https://github.com/tangphillip/Imgur-Uploader
    #create_link "${BASE_PROGS_DIR}/Imgur-Uploader/imgur" "$HOME/bin/imgur-uploader"

    # replace bash tab completion w/ fzf:
    # alternatively consider https://github.com/rockandska/fzf-obc
    clone_or_pull_repo "lincheney" "fzf-tab-completion" "$BASE_PROGS_DIR"  # https://github.com/lincheney/fzf-tab-completion

    # fasd - shell navigator similar to autojump:
    # note we're using whjvenyl's fork instead of original clvv, as latter was last updated 2015 (orig: https://github.com/clvv/fasd.git)
    # alternatives:
    #   - https://github.com/ajeetdsouza/zoxide
    #   - https://github.com/wyne/fasder  - go reimplementation
    clone_or_pull_repo "whjvenyl" "fasd" "$BASE_PROGS_DIR"  # https://github.com/whjvenyl/fasd
    create_link "$BASE_PROGS_DIR/fasd/fasd" "$HOME/bin/fasd"
    ensure_d "$XDG_DATA_HOME/fasd"  # referenced by ~/.config/fasd/config

    # maven bash completion:
    clone_or_pull_repo "juven" "maven-bash-completion" "$BASE_PROGS_DIR"  # https://github.com/juven/maven-bash-completion
    create_link "${BASE_PROGS_DIR}/maven-bash-completion/bash_completion.bash" "$BASH_COMPLETIONS/mvn"

    # gradle bash completion:  # https://github.com/gradle/gradle-completion/blob/master/README.md#installation-for-bash-32
    #curl -LA gradle-completion https://edub.me/gradle-completion-bash -o $HOME/.bash_completion.d/
    clone_or_pull_repo "gradle" "gradle-completion" "$BASE_PROGS_DIR"
    create_link "${BASE_PROGS_DIR}/gradle-completion/gradle-completion.bash" "$BASH_COMPLETIONS/gradle"

    # leiningen bash completion:  # https://codeberg.org/leiningen/leiningen/src/branch/main/bash_completion.bash
    #
    install_from_url -A -d "$BASH_COMPLETIONS" lein  "https://codeberg.org/leiningen/leiningen/raw/branch/main/bash_completion.bash"

    # vifm filetype icons: https://github.com/thimc/vifm_devicons
    clone_or_pull_repo "thimc" "vifm_devicons" "$BASE_PROGS_DIR"
    create_link "${BASE_PROGS_DIR}/vifm_devicons" "$HOME/.vifm_devicons"

    # git-fuzzy (yet another git fzf tool)   # https://github.com/bigH/git-fuzzy
    clone_or_pull_repo "bigH" "git-fuzzy" "$BASE_PROGS_DIR"

    # TODO: find alternative. note we have some scripts currently depending on it
    # notify-send with additional features  # https://github.com/M3TIOR/notify-send.sh
    # note it depends on libglib2.0-bin (should be already installed):   install_block libglib2.0-bin
    clone_or_pull_repo  M3TIOR  "notify-send.sh" "$BASE_PROGS_DIR"
    create_link "${BASE_PROGS_DIR}/notify-send.sh/src/notify-send.sh" "$HOME/bin/"


    # diff-so-fancy - human-readable git diff:  # https://github.com/so-fancy/diff-so-fancy#install
    # note: alternative would be https://github.com/dandavison/delta
    # either of those need manual setup in our gitconfig
    clone_or_pull_repo "so-fancy" "diff-so-fancy" "$BASE_PROGS_DIR" || return 1
    create_link "$BASE_PROGS_DIR/diff-so-fancy" "$HOME/bin/"

    # forgit - fzf-fueled git tool:  # https://github.com/wfxr/forgit
    clone_or_pull_repo "wfxr" "forgit" "$BASE_PROGS_DIR" || return 1

    # dynamic colors loader: (TODO: deprecated by pywal right?)
    #clone_or_pull_repo "sos4nt" "dynamic-colors" "$BASE_PROGS_DIR"  # https://github.com/sos4nt/dynamic-colors
    #create_link "${BASE_PROGS_DIR}/dynamic-colors" "$HOME/.dynamic-colors"
    #create_link "${BASE_PROGS_DIR}/dynamic-colors/bin/dynamic-colors" "$HOME/bin/dynamic-colors"

    # base16 shell colors:
    #clone_or_pull_repo "chriskempson" "base16-shell" "$BASE_PROGS_DIR"  # https://github.com/chriskempson/base16-shell
    #create_link "${BASE_PROGS_DIR}/base16-shell" "$HOME/.config/base16-shell"


    _install_tmux_deps; unset _install_tmux_deps
    _install_mutt_deps; unset _install_mutt_deps
    _install_zsh_deps; unset _install_zsh_deps

    # vifm plugins:
    # note ueberzug plugin commented out atm as we're using scripts from https://github.com/thimc/vifmimg
    #_install_vifm_deps; unset _install_vifm_deps

    # cheat.sh:  # https://github.com/chubin/cheat.sh#installation
    # see also:
    # - https://github.com/cheat/cheat
    install_from_url  cht.sh 'https://cht.sh/:cht.sh'

    # TODO: following are not deps, are they?:

    # this needs apt-get install  python-imaging ?:
    py_install scdl          # https://github.com/flyingrub/scdl (soundcloud downloader)
    #py_install rtv           # https://github.com/michael-lazar/rtv (reddit reader)  # TODO: active development has ceased; alternatives @ https://gist.github.com/michael-lazar/8c31b9f637c3b9d7fbdcbb0eebcf2b0a
    py_install tuir-continued  # https://gitlab.com/Chocimier/tuir  (now-discontinued rtv continuation)
    py_install tldr          # https://github.com/tldr-pages/tldr-python-client [tldr (short manpages) reader]
    py_install vit           # https://github.com/vit-project/vit (curses-based interface for taskwarrior (a todo list mngr we install from apt; executable is called 'task'))
                                                                                      #   note its conf is in bash_env_vars
    py_install httpstat       # https://github.com/reorx/httpstat  curl wrapper to get request stats (think chrome devtools)
    py_install yamllint       # https://github.com/adrienverge/yamllint
    py_install awscli         # https://docs.aws.amazon.com/en_pv/cli/latest/userguide/install-linux.html#install-linux-awscli

    # colorscheme generator:
    # see also complementing script @ https://github.com/dylanaraps/bin/blob/master/wal-set
    # alternatives to pywal:
    #   - rust: https://codeberg.org/explosion-mental/wallust
    #   - c: https://github.com/danihek/hellwal
    py_install pywal16          # https://github.com/eylles/pywal16/wiki/Installation#pip-install

    # consider also perl alternative @ https://github.com/pasky/speedread
    #rb_install speed_read  # https://github.com/sunsations/speed_read  (spritz-like terminal speedreader)

    py_install update-conf.py # https://github.com/rarylson/update-conf.py  (generate config files from conf.d dirs)
    #py_install starred     # https://github.com/maguowei/starred  - create list of your github starts; note it's updated by CI so no real reason to install it locally

    # rofi-based emoji picker
    # change rofi command to something like [-modi combi#ssh#emoji:rofimoji] to use.
    py_install -g fdw/rofimoji  # https://github.com/fdw/rofimoji

    # keepass cli tool
    py_install passhole     # https://github.com/Evidlo/passhole

    # keepass rofi/demnu tool (similar to passhole (aka ph), but w/ rofi gui)
    py_install keepmenu     # https://github.com/firecat53/keepmenu

    #if is_native; then
        ## mopidy-spotify        # https://mopidy.com/ext/mpd/
        ##py_install Mopidy-MPD
        #install_block  mopidy-mpd

        ##  TODO: spotify extensions need to be installed globally??
        ## mopidy-youtube        # https://mopidy.com/ext/youtube/
        #install_block  gstreamer1.0-plugins-bad
        #py_install Mopidy-Youtube

        ## mopidy-local        # https://mopidy.com/ext/local/
        ## (provides us with 'mopidy local scan' command)
        ##py_install Mopidy-Local
        #install_block  mopidy-local

        ## mopidy-soundcloud     # https://mopidy.com/ext/soundcloud/
        ##py_install Mopidy-SoundCloud
        #install_block  mopidy-soundcloud

        ## mopidy-spotify        # https://mopidy.com/ext/spotify/
        ##py_install Mopidy-Spotify
        #install_block  mopidy-spotify
    #fi

    # some py deps requred by scripts:  # TODO: should we not install these via said scripts' requirements.txt file instead?
    #py_install exchangelib vobject icalendar arrow
    # note: if exchangelib fails with something like
                #In file included from src/kerberos.c:19:0:
                #src/kerberosbasic.h:17:27: fatal error: gssapi/gssapi.h: No such file or directory
                ##include <gssapi/gssapi.h>
                                            #^
                #compilation terminated.
                #error: command 'x86_64-linux-gnu-gcc' failed with exit status 1
    # you'd might wanna install  libkrb5-dev (or whatever ver avail at the time)   https://github.com/ecederstrand/exchangelib/issues/404

    # Google Calendar CLI       # https://github.com/insanum/gcalcli
    py_install gcalcli  # tag: gagenda

    # flashfocus - flash window when focus changes  https://github.com/fennerm/flashfocus
    # note on X systems it requires a compositor (e.g. picom) to be effective.
    # TODO: x11? project page mentions it's working on sway, but it has xcb dependencies, so...
    install_block 'libxcb-render0-dev libffi-dev python3-cffi'
    py_install flashfocus


    # work deps:  # TODO remove block?
    #if [[ "$PROFILE" == work ]]; then
        ## cx toolbox/vagrant env deps:  # TODO: deprecate? at least try to find what is _really_ required.
        #rb_install \
            #puppet puppet-lint bundler nokogiri builder
    #fi

    # laptop deps:
    is_native && is_laptop && _install_laptop_deps; unset _install_laptop_deps


    # install npm_modules:
    # https://github.com/FredrikNoren/ungit
    # https://github.com/dominictarr/JSON.sh
    # https://github.com/sindresorhus/fast-cli
    #
    exe "$NPM_PRFX npm install -g \
        neovim \
        ungit \
        fast-cli \
    "
}


setup_dirs() {
    local dir opts

    readonly BASH_COMPLETIONS="$XDG_DATA_HOME/bash-completion/completions"  # as per https://github.com/scop/bash-completion#faq  # cannot set before importing SHELL_ENVS!

    # create dirs:
    for dir in \
            $TMP_DIR \
            $HOME/bin \
            $BASH_COMPLETIONS \
            "${ZSH_COMPLETIONS}:R" \
            $HOME/.npm-packages \
            $BASE_DATA_DIR/.calendars \
            $BASE_DATA_DIR/.calendars/work \
            $BASE_DATA_DIR/.rsync \
            $BASE_DATA_DIR/.repos \
            $BASE_DATA_DIR/tmp \
            $BASE_DATA_DIR/vbox_vms \
            $BASE_PROGS_DIR \
            $BASE_BUILDS_DIR \
            $BASE_DATA_DIR/dev \
            $BASE_DATA_DIR/apps \
            $BASE_DATA_DIR/apps/maven/repo \
            $BASE_DATA_DIR/apps/gradle \
            $BASE_DATA_DIR/mail \
            $BASE_DATA_DIR/mail/work \
            $BASE_DATA_DIR/mail/personal \
            $BASE_DATA_DIR/Downloads \
            $BASE_DATA_DIR/Videos \
            $BASE_DATA_DIR/Music \
            $BASE_DATA_DIR/Documents \
                ; do
        IFS=: read -r dir opts <<< "$dir"
        [[ "$opts" == *R* ]] && ensure_d -s "$dir" || ensure_d "$dir"
    done

    # create logdir ($CUSTOM_LOGDIR defined in $SHELL_ENVS):
    if [[ -z "$CUSTOM_LOGDIR" ]]; then
        err "[CUSTOM_LOGDIR] env var is undefined. abort."; sleep 5
    elif ! [[ -d "$CUSTOM_LOGDIR" ]]; then
        report "[$CUSTOM_LOGDIR] does not exist, creating..."
        ensure_d -s "$CUSTOM_LOGDIR"
        exe "sudo chown root:$USER -- $CUSTOM_LOGDIR"
        exe "sudo chmod 'u=rwX,g=rwX,o=' -- $CUSTOM_LOGDIR"
    fi
}


install_homesick() {
    clone_or_pull_repo "andsens" "homeshick" "$BASE_HOMESICK_REPOS_LOC" || return 1
}


# homeshick specifics
#
# pass   -H   flag to set up path to our githooks
clone_or_link_castle() {
    local repo castle hub homesick_exe opt OPTIND set_hooks batch force_ssh

    while getopts 'HS' opt; do
        case "$opt" in
            H) set_hooks=1 ;;
            S) force_ssh=1 ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly repo="$1"  # user/repo
    readonly hub="${2:-github.com}"  # domain of the git repo, ie github.com/bitbucket.org...

    castle="$(basename -- "$repo")"
    readonly homesick_exe="$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick"

    [[ -z "$repo" || -z "$castle" || -z "$hub" ]] && { err "either repo or castle name were missing"; sleep 2; return 1; }
    [[ -x "$homesick_exe" ]] || { err "expected to see homesick script @ [$homesick_exe], but didn't. skipping cloning/linking castle [$castle]"; return 1; }
    is_noninteractive && batch=' --batch'

    if [[ -d "$BASE_HOMESICK_REPOS_LOC/$castle" ]]; then
        if is_ssh_key_available; then
            report "[$castle] already exists; pulling & linking"
            retry 3 "${homesick_exe}$batch pull $castle" || { err "pulling castle [$castle] failed with $?"; return 1; }  # TODO: should we exit here?
        else
            report "[$castle] already exists; linking..."
        fi

        exe "${homesick_exe}$batch link $castle" || { err "linking castle [$castle] failed with $?"; return 1; }  # TODO: should we exit here?
    else
        report "cloning castle ${castle}..."
        if is_ssh_key_available || [[ "$force_ssh" == 1 ]]; then
            retry 3 "$homesick_exe clone git@${hub}:${repo}.git" || { err "cloning castle [$castle] failed with $?"; return 1; }
        else
            # note we clone via https, not ssh:
            retry 3 "$homesick_exe clone https://${hub}/${repo}.git" || { err "cloning castle [$castle] failed with $?"; return 1; }

            # change just cloned repo remote from https to ssh:
            exe "git -C '$BASE_HOMESICK_REPOS_LOC/$castle' remote set-url origin git@${hub}:${repo}.git"
        fi

        # note this assumes $castle repo has a .githooks symlink at its root that points to dir that contains the actual hooks!
        if [[ "$set_hooks" == 1 ]]; then
            exe 'git -C '$BASE_HOMESICK_REPOS_LOC/$castle' config core.hooksPath .githooks' || err "git hook installation failed!"
        fi
    fi

    # just in case verify whether our ssh keys got cloned in:
    if [[ "$IS_SSH_SETUP" -eq 0 ]] && is_ssh_key_available; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    fi
}


fetch_castles() {
    local castle user hub

    # common private:
    clone_or_link_castle -H layr/private-common bitbucket.org || { err "failed pulling private dotfiles; it's required!"; return 1; }
    if [[ "$MODE" -eq 1 ]]; then
        exe "cp -- $COMMON_PRIVATE_DOTFILES/home/.ssh/ssh_common_client_config ~/.ssh/config" || { err "ssh initial config copy failed w/ $?"; return 1; }
        _sanitize_ssh
        is_proc_running ssh-agent || eval "$(ssh-agent)"
    fi

    # common public castles:
    clone_or_link_castle -H laur89/dotfiles || { err "failed pulling public dotfiles; it's required!"; return 1; }

    # !! if you change private repos, make sure you update PRIVATE__DOTFILES definitions @ validate_and_init()!
    case "$PROFILE" in
        work)
            export GIT_SSL_NO_VERIFY=1
            local host repo u
            host=git.nonprod.williamhill.plc
            repo="laliste/$(basename -- "$PRIVATE__DOTFILES")"
            if clone_or_link_castle -H "$repo" "$host"; then
                for u in "git@$host:${repo}.git"  "git@github.com:laur89/work-dots-mirror.git"; do
                    if ! grep -iq "pushurl.*$u" "$PRIVATE__DOTFILES/.git/config"; then  # need if-check as 'set-url --add' is not idempotent; TODO: create ticket for git?
                        exe "git -C '$PRIVATE__DOTFILES' remote set-url --add --push origin '$u'"
                    fi
                done
            else
                err "failed pulling work dotfiles; won't abort"
            fi

            unset GIT_SSL_NO_VERIFY
            ;;
        personal)
            clone_or_link_castle -HS "layr/$(basename -- "$PRIVATE__DOTFILES")" bitbucket.org || err "failed pulling personal dotfiles; won't abort"
            ;;
        *) fail "unexpected \$PROFILE [$PROFILE]" ;;
    esac

    if [[ -n "$PLATFORM" ]]; then
        clone_or_link_castle -HS "laur89/$(basename -- "$PLATFORM_DOTFILES")" || err "failed pulling platform-specific dotfiles for [$PLATFORM]; won't abort"
    fi

    #while true; do
        #if confirm "$(report 'want to clone another castle?')"; then
            #echo -e "enter git repo domain (eg [github.com], [bitbucket.org]):"
            #read -r hub

            #echo -e "enter username:"
            #read -r user

            #echo -e "enter castle name (repo name, eg [dotfiles]):"
            #read -r castle

            #exe "clone_or_link_castle "$user/$castle" $hub"
        #else
            #break
        #fi
    #done
}


# check whether ssh key(s) were pulled with homeshick; if not, offer to create one:
verify_ssh_key() {

    [[ "$IS_SSH_SETUP" -eq 1 ]] && return 0
    err "expected ssh keys to be there after cloning repo(s), but weren't."

    confirm -d N "do you wish to generate set of ssh keys?" || return
    generate_ssh_key

    if is_ssh_key_available; then
        IS_SSH_SETUP=1
    else
        err "didn't find the key at [$PRIVATE_KEY_LOC] after generating keys."
    fi
}


# note: as homesick (and some of its managed castles) are paramount for the whole
# setup logic, then script should abort if this function returns non-0.
setup_homesick() {
    local https_castles

    install_homesick || return 1
    fetch_castles || return 1

    # just in case check if any of the castles are still tracking https instead of ssh:
    https_castles="$("$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick" list | grep -Ei '\bhttps://')"
    if [[ -n "$https_castles" ]]; then
        err "fyi, these homesick castles are for some reason still tracking https remotes:"
        err "$https_castles"
        err
    fi
}


setup_global_shell_links() {
    local global_dir real_file_locations file

    declare -ar real_file_locations=(
        "$SHELL_ENVS"
        "$HOME/.global-bash-init"
    )
    readonly global_dir='/etc'  # so our env vars would have user-agnostic location as well;
                                # that location will be used by various scripts.

    for file in "${real_file_locations[@]}"; do
        is_f -m "can't link it to ${global_dir}/" "$file" || continue
        create_link -s "$file" "${global_dir}/"
    done
}


# force private assets' (such as netrc) permissions private (only accessible by its owner);
# note this list would be best kept in sync with files in our common post-checkout githook;
setup_private_asset_perms() {
    local i

    for i in \
            ~/.ssh \
            ~/.netrc \
            ~/.electrum \
            ~/.gcalclirc \
            ~/.gcalcli_oauth \
            ~/.msmtprc \
            ~/.irssi \
            ~/.config/weechat \
            ~/.aider.conf.yml \
            "$GNUPGHOME" \
            ~/.gist \
            ~/.bash_hist \
            ~/.bash_history_eternal \
            ~/.config/revolut-py \
                ; do
        [[ -e "$i" ]] || { err "expected to find [$i] for permission sanitization, but it doesn't exist; is it normal?"; continue; }
        [[ -d "$i" && "$i" != */ ]] && i+='/'
        find -L "$i" -maxdepth 25 \( -type f -o -type d \) -exec chmod 'u=rwX,g=,o=' -- '{}' \+
    done
}


# sets:
# - global PS1
# - shell init glue code under /etc
setup_global_bash_settings() {
    local global_bashrc global_profile ps1

    readonly global_bashrc='/etc/bash.bashrc'
    readonly global_profile='/etc/profile.d'   # note this stuff might be sourced by other shells than Bournes (see https://unix.stackexchange.com/a/541585/47501); sourced by /etc/profile
    readonly ps1='PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} -eq 0 ]]; then echo "\[\033[0;33m\]\u\[\033[0;37m\]@\[\033\[\033[0;31m\]\h"; else echo "\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h"; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"  # own-ps1-def-marker'

    is_f -m 'cannot modify it' "$global_bashrc" || return 1

    ## setup prompt:
    # just in case first delete previous global PS1 def:
    exe "sudo sed -i --follow-symlinks '/^PS1=.*# own-ps1-def-marker$/d' '$global_bashrc'"
    exe "echo '$ps1' | sudo tee --append $global_bashrc > /dev/null"

    ## add the script shell init glue code under /etc for convenience/global access:
    # note this one only covers _interactive_ shells...:
    exe "sudo sed -i --follow-symlinks '/^source .*global_init_marker$/d' '$global_bashrc'"
    exe "echo 'source /etc/.global-bash-init  # global_init_marker' | sudo tee --append $global_bashrc > /dev/null"

    # ...and this one only covers _non-interactive_ shells (note cron still isn't covered!)
    # (BASH_ENV is documented here: https://www.gnu.org/software/bash/manual/bash.html#index-BASH_005fENV)
    # note we define & export BASH_ENV on separate files, as /etc/profile could be
    # read bu other shells than Bournes (see https://unix.stackexchange.com/a/541585/47501)
    is_d "$global_profile" || return 1
    exe "echo -e 'BASH_ENV=/etc/.global-bash-init  # global_init_marker\nexport BASH_ENV' | sudo tee $global_profile/bash-init-global.sh > /dev/null"
}


# setup system config files (the ones _not_ living under $HOME, ie not managed by homesick)
# has to be invoked AFTER homeschick castles are cloned/pulled!
#
# note that this block overlaps logically a bit with post_install_progs_setup() (not really tho, as p_i_p_s() requires specific progs to be installed beforehand)
setup_config_files() {

    #setup_swappiness
    setup_apt
    #setup_crontab
    setup_sudoers
    setup_hosts
    setup_systemd
    setup_apparmor
    is_pkg_installed needrestart && setup_needrestart  # TODO: should we include needrestart pkg?
    setup_pam_login
    setup_logind
    is_native && setup_udev
    is_native && setup_pm
    is_native && install_kernel_modules   # TODO: does this belong in setup_config_files()?
    #is_native && setup_smartd  #TODO: uncomment once finished!
    setup_mail
    setup_global_shell_links
    setup_private_asset_perms
    setup_global_bash_settings
    #is_native && swap_caps_lock_and_esc
    override_locale_time
}


# network manager wrapper script;
# see:
# - https://blogs.oracle.com/linux/post/networkmanager-dispatcher-scripts
# - https://manpages.debian.org/unstable/network-manager/NetworkManager-dispatcher.8.en.html
install_nm_dispatchers() {
    local dispatchers nm_wrapper_dest f

    readonly nm_wrapper_dest='/etc/NetworkManager/dispatcher.d'
    readonly dispatchers=(
        "$BASE_DATA_DIR/dev/scripts/network_manager_SSID_checker_wrapper.sh"
    )

    is_d -m "NM dispatcher script(s) won't be installed" "$nm_wrapper_dest" || return 1

    for f in "${dispatchers[@]}"; do
        is_f -m "this NM dispatcher won't be installed" "$f" || continue
        exe "sudo install -m744 -C '$f' '$nm_wrapper_dest'" || { err "installing [$f] failed w/ $?"; return 1; }
    done
}


source_shell_conf() {
    local i

    # source own functions and env vars:
    if [[ "$__ENV_VARS_LOADED_MARKER_VAR" != "loaded" ]]; then
        for i in \
                "$SHELL_ENVS" \
                    ; do  # note the sys-specific env_vars_overrides! also make sure env_vars are fist to be imported;
            [[ -r "$i" ]] && source "$i"
        done

        if [[ -d "$HOME/.bash_env_vars_overrides" ]]; then
            for i in "$HOME/.bash_env_vars_overrides/"*; do
                [[ -f "$i" ]] && source "$i"
            done
        fi
    fi

    if ! type __BASH_FUNS_LOADED_MARKER > /dev/null 2>&1; then
        # skip common funs import - we don't need 'em, and might cause conflicts:
        #[[ -r "$HOME/.bash_functions" ]] && source "$HOME/.bash_functions"

        if [[ -d "$HOME/.bash_funs_overrides" ]]; then
            for i in "$HOME/.bash_funs_overrides/"*; do
                [[ -f "$i" ]] && source "$i"
            done
       fi
    fi
}


setup_install_log_file() {
    if [[ -z "$GIT_RLS_LOG" ]]; then
        [[ -n "$CUSTOM_LOGDIR" ]] && readonly GIT_RLS_LOG="$CUSTOM_LOGDIR/install.log" || GIT_RLS_LOG="$TMP_DIR/.install.tmp"  # log of all installed debs/binaries from git releases/latest page
    fi
}


# see https://wiki.debian.org/SecureBoot#MOK_-_Machine_Owner_Key
setup_mok() {
    local target_dir
    target_dir='/var/lib/shim-signed/mok'

    ensure_d -s "$target_dir" || return 1
    if ! is_dir_empty -s "$target_dir"; then
        report "[$target_dir] not empty, assuming MOK keys already created; testing key enrollment..."
        # TODO: mokutil here exits /w 1 on success, so cannot use w/ pipefail:
        #sudo mokutil --test-key "$target_dir/MOK.der" | grep -q 'is already enrolled' || { err "[$target_dir/MOK.der] not enrolled, verify MOK!"; return 1; }
        local i="$(sudo mokutil --test-key "$target_dir/MOK.der")"
        grep -qF 'is already enrolled' <<< "$i" || { err "[$target_dir/MOK.der] not enrolled, verify MOK!"; return 1; }
        return 0
    fi

    is_noninteractive && { err "do not exec $FUNCNAME() in non-interactive mode; make sure to manually re-run this step!"; return 1; }

    exe "sudo openssl req -nodes -new -x509 -newkey rsa:2048 -keyout $target_dir/MOK.priv -outform DER -out $target_dir/MOK.der -days 36500 -subj '/CN=Laur Aliste/'" || return $?
    exe "sudo openssl x509 -inform der -in $target_dir/MOK.der -out $target_dir/MOK.pem" || return $?

    report "enrolling MOK, enter password to use for enrollment during next reboot..."
    exe "sudo mokutil --import $target_dir/MOK.der" || return $?  # prompts for one-time password

    _instruct_dkms_to_use_keys() {  # TODO: refactor out into setup_dkms() ?
        local conf_dir f
        conf_dir='/etc/dkms/framework.conf.d'
        f="$COMMON_PRIVATE_DOTFILES/backups/use_user_mok.conf"

        is_d -m "cannot setup DKMS to use our MOK keys" "$conf_dir" || return 1
        is_f -nm 'skipping DKMS config to use our MOK keys' "$f" || return 1

        exe "sudo install -m644 -C '$f' '$conf_dir'" || { err "installing [$f] to [$conf_dir] failed w/ $?"; return 1; }
    }

    _instruct_dkms_to_use_keys
}


setup() {
    setup_homesick || fail "homesick setup failed; as homesick is necessary, script will exit"
    verify_ssh_key
    source_shell_conf  # so we get our env vars after dotfiles are pulled in

    setup_install_log_file

    setup_dirs  # has to come after $SHELL_ENVS sourcing so the env vars are in place
    [[ "$MODE" -eq 1 ]] && install_flatpak
    setup_config_files
    setup_additional_apt_keys_and_sources

    [[ "$PROFILE" == work && -s ~/.npmrc ]] && mv -- ~/.npmrc "$NPMRC_BAK"  # work npmrc might define private registry
    # following npm hack is superseded by temporarily getting rid of ~/.npmrc above:
    #if [[ "$MODE" -eq 1 && "$PROFILE" == work && -z "$NODE_EXTRA_CA_CERTS" ]]; then
        #NPM_PRFX+=' NODE_TLS_REJECT_UNAUTHORIZED=0'  # certs might've not been init'd yet; NODE_TLS_REJECT_UNAUTHORIZED not working, so far only '$npm config set strict-ssl' false has had any effect
        #local _cert="$TMP_DIR/wh_${RANDOM}.crt"
        #curl -s --fail --connect-timeout 2 --max-time 4 --insecure --output "$_cert" \
                #https://git.nonprod.williamhill.plc/profiles/profile_wh_sslcerts/raw/master/files/wh_chain_sc1wnpresc03.crt \
                #&& export NODE_EXTRA_CA_CERTS=$_cert
    #fi
}


# logic to pull current time from a pre-configured site, and set it as our system
# clock time if ours deviates from it by some margin.
# This is needed on vbox systems during install-time, the time can deviate quite a bit.
update_clock() {
    local src remote_time diff

    src='http://1.1.1.1'  # external source whose http headers to extract time from
    #src='http://www.google.com'  # external source whose http headers to extract time from

    if [[ "$CONNECTED" -eq 0 ]]; then
        report "we're not connected to net, skipping $FUNCNAME()..."
        return 0
    fi

    remote_time="$(curl --connect-timeout 5 --max-time 5 --fail --insecure --silent --head "$src" 2>&1 \
            | grep -ioP '^date:\s*\K.*' | { read -r t; [[ -z "$t" ]] && return 1; date +%s -d "$t"; })"

    is_digit "$remote_time" || { err "resolved remote [$src] time was not digit: [$remote_time]"; return 1; }
    diff="$(( $(date +%s) - remote_time ))"

    if [[ "${diff#-}" -gt 30 ]]; then
        report "system time diff to remote source is [${diff}s] - updating clock..."
        # IIRC, input format to date -s here is important:
        exe "sudo date -s '$(date -d @${remote_time} '+%Y-%m-%d %H:%M:%S')'" || { err "setting system time w/ date failed w/ $?"; return 1; }
    fi

    return 0
}


create_apt_source() {
    local name key_url uris suites components keyfile keyfiles
    local f target_src k i c grp_ptrn arch opt OPTIND

    while getopts 'gak:' opt; do
        case "$opt" in
            # TODO: deprecate -g opt:
            g) grp_ptrn='-----BEGIN PGP PUBLIC KEY BLOCK-----.*END PGP PUBLIC KEY BLOCK-----' ;;  # PGP is embedded in a file at $key_url and needs to be grepped out from it
            a) arch=amd64 ;;
            k) k="$OPTARG" ;;  # means $key_url is a keyserver
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    name="$1"
    key_url="$2"  # either keyfile or keyserver, depending on whether -k is used; with -g flag it's a file that contains the PGP key, together with other content (likely an installer script)
                  # spearate by comma for multiple keys
    uris="$3"  # 3-5 are already for the source file definition
    suites="$4"
    components="$5"

    if [[ "$suites" == */ ]]; then
        [[ -n "$components" ]] && { err "if [Suites:] is a path (i.e. ends w/ a slash), then [Components:] must be empty"; return 1; }
    else
        [[ -z "$components" ]] && { err "if [Suites:] is not a path (i.e. doesn't end w/ a slash), then [Components:] must be included"; return 1; }
    fi

    # create (arbitrary) dir for our apt keys:
    ensure_d -s "$APT_KEY_DIR" || return 1

    c=0
    IFS=, read -ra key_url <<< "$key_url"
    for i in "${key_url[@]}"; do
        if [[ "$c" -eq 0 ]]; then
            keyfile="$APT_KEY_DIR/${name}.gpg"
            keyfiles="$keyfile"
        else
            keyfile="$APT_KEY_DIR/${name}-${c}.gpg"
            keyfiles+=",$keyfile"  # TODO: does it allow comma-separation?
        fi

        f="$TMP_DIR/.apt-key_${name}-${RANDOM}.gpg"
        if [[ -n "$k" ]]; then
            exe "sudo gpg --no-default-keyring --keyring $f --keyserver $i --recv-keys $k" || return 1
        elif [[ -n "$grp_ptrn" ]]; then
            exe "wget --user-agent='$USER_AGENT' -q -O - '$i' | grep -Pzo -- '(?s)$grp_ptrn' | gpg --no-tty --batch --dearmor | sudo tee $f > /dev/null" || return 1
        else
            # either single-conversion command, if it works...:
            exe "wget --user-agent='$USER_AGENT' -q -O - '$i' | gpg --no-tty --batch --dearmor | sudo tee $f > /dev/null" || return 1

            # ...or lengthier (but safer?) multi-step conversion:
            #local tmp_ring
            #tmp_ring="$TMP_DIR/temp-keyring-${RANDOM}.gpg"
            #exe "curl -fsL -o '$f' '$i'" || return 1

            #exe "gpg --no-default-keyring --keyring $tmp_ring --import $f" || return 1
            #rm -- "$f"  # unsure if this is needed or not for the following gpg --output command
            #exe "gpg --no-default-keyring --keyring $tmp_ring --export --output $f" || return 1
            #rm -- "$tmp_ring"
        fi

        [[ -s "$f" ]] || { err "imported keyfile [$f] does not exist"; return 1; }
        exe "sudo install -m644 -CT '$f' '$keyfile'" || { err "installing [$f] to [$keyfile] failed w/ $?"; return 1; }
        (( c++ ))
    done

    # finally write the source file itself:
    target_src="/etc/apt/sources.list.d/${name}.sources"
    f="$TMP_DIR/.apt-src_${name}-$RANDOM"
    cat <<EOF > "$f"
Types: deb
URIs: $uris
Suites: $suites
Signed-By: $keyfiles
EOF
    [[ -n "$components" ]] && echo "Components: $components" >> "$f"
    [[ -n "$arch" ]] && echo "Architectures: $arch" >> "$f"
    exe "sudo install -m644 -CT '$f' '$target_src'" || { err "installing [$f] to [$target_src] failed w/ $?"; return 1; }
}


# apt-key is deprecated! instead we follow instructions from https://askubuntu.com/a/1307181
#  (https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=968148)
#
# note if you need to grep embedded key from a (maybe an installer?) file, then do
#   $ grep -Pzo -- '(?s)-----BEGIN PGP PUBLIC KEY BLOCK-----.*END PGP PUBLIC KEY BLOCK-----'  file
setup_additional_apt_keys_and_sources() {

    # mopidy: (from https://docs.mopidy.com/en/latest/installation/debian/):
    # deb-line is from https://apt.mopidy.com/bookworm.sources:
    #create_apt_source  mopidy  https://apt.mopidy.com/mopidy-archive-keyring.gpg  https://apt.mopidy.com/ $DEB_STABLE 'main contrib non-free'

    # spotify: (from https://www.spotify.com/download/linux/):
    # consider also https://github.com/SpotX-Official/SpotX-Bash to patch the client
    create_apt_source  spotify  https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg  https://repository.spotify.com/ stable non-free

    # !!! "Since 9.0.7 version, we only provide official packages in AppImage format" !!!
    # seafile-client: (from https://help.seafile.com/syncing_client/install_linux_client/):
    #     seafile-drive instructions would be @ https://help.seafile.com/drive_client/drive_client_for_linux/
    #create_apt_source -a  seafile  https://linux-clients.seafile.com/seafile.asc  https://linux-clients.seafile.com/seafile-deb/$DEB_OLDSTABLE/ stable main

    # charles: (from https://www.charlesproxy.com/documentation/installation/apt-repository/):
    create_apt_source  charles  https://www.charlesproxy.com/packages/apt/charles-repo.asc  https://www.charlesproxy.com/packages/apt/ charles-proxy main

    # opentofu:  (from https://opentofu.org/docs/intro/install/deb/#set-up-the-opentofu-repository):
    # (open source terraform)
    create_apt_source -a  opentofu  https://get.opentofu.org/opentofu.gpg,https://packages.opentofu.org/opentofu/tofu/gpgkey  https://packages.opentofu.org/opentofu/tofu/any/ any main

    # openvpn3:  (from https://openvpn.net/cloud-docs/openvpn-3-client-for-linux/):
    #create_apt_source -a  openvpn  https://packages.openvpn.net/packages-repo.gpg  https://packages.openvpn.net/openvpn3/debian $STABLE main

    # signal: (from https://signal.org/en/download/):
    create_apt_source -a  signal  https://updates.signal.org/desktop/apt/keys.asc  https://updates.signal.org/desktop/apt/ xenial main

    # signald: (from https://signald.org/articles/install/debian/):
    # TODO: using http instead of https as per note in https://signald.org/articles/install/debian/ (apt-update gives error otherwise)
    # TODO 2: believe this was to be used by hoehermann/libpurple-signald, which is deprecated?
    #create_apt_source -a  signald  https://signald.org/signald.gpg  http://updates.signald.org/ unstable main

    # estonian open eid: (from https://installer.id.ee/media/install-scripts/install-open-eid.sh):
    # latest/current key can be found from https://installer.id.ee/media/install-scripts/
    #
    # note you'll likely want to use the latest ubuntu LTS or latest, period, codename for repo.
    #create_apt_source -g  estonian-eid  https://raw.githubusercontent.com/open-eid/linux-installer/master/install-open-eid.sh  https://installer.id.ee/media/ubuntu/ plucky main
    create_apt_source  estonian-eid  https://installer.id.ee/media/install-scripts/C6C83D68.pub  https://installer.id.ee/media/ubuntu/ plucky main

    # mozilla/firefox:  https://support.mozilla.org/en-US/kb/install-firefox-linux#w_install-firefox-deb-package-for-debian-based-distributions
    create_apt_source  mozilla  https://packages.mozilla.org/apt/repo-signing-key.gpg  https://packages.mozilla.org/apt/ mozilla main

    # gh: (from https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt):
    create_apt_source -a  gh  https://cli.github.com/packages/githubcli-archive-keyring.gpg  https://cli.github.com/packages/ stable main

    # wezterm: (from https://wezterm.org/install/linux.html):
    create_apt_source  wezterm  https://apt.fury.io/wez/gpg.key  https://apt.fury.io/wez/ '*' '*'

    # nushell: https://www.nushell.sh/book/installation.html#package-managers
    create_apt_source  nushell  https://apt.fury.io/nushell/gpg.key  https://apt.fury.io/nushell/  /

    # tailscale: https://tailscale.com/download/linux/debian-bookworm
    #create_apt_source  tailscale  https://pkgs.tailscale.com/stable/debian/$DEB_STABLE.noarmor.gpg  https://pkgs.tailscale.com/stable/debian $DEB_STABLE main

    exe 'sudo apt-get --yes update'
}


# to add additional locales, uncomment wanted locale in /etc/locale.gen and run $ locale-gen as root;
#
# - to display current active locale settings, run  $ locale
override_locale_time() {
    local conf_file loc_file locales i modified

    readonly conf_file='/etc/default/locale'
    readonly loc_file='/etc/locale.gen'

    is_f "$conf_file" || return 1

    # change our LC_TIME, so first day of week is Mon (from https://wiki.debian.org/Locale#First_day_of_week):
    if ! grep -qE 'LC_TIME=.en_GB.UTF-8.' "$conf_file"; then
        # just in case delete all same definitions, regardless of its value:
        exe "sudo sed -i --follow-symlinks '/^LC_TIME\s*=/d' '$conf_file'" || return 1
        exe "echo 'LC_TIME=\"en_GB.UTF-8\"' | sudo tee --append $conf_file > /dev/null"  # en-gb gives us 24h clock & Monday as first day of the week
    fi

    # generate missing locales: {{{
    [[ -s "$loc_file" ]] || { err "cannot add locales: [$loc_file] does not exist; abort;"; return 1; }
                #'et_EE.UTF-8' \
    for i in \
                'en_GB.UTF-8' \
                'en_US.UTF-8' \
            ; do
        if ! grep -qE "^$i" "$loc_file"; then
            exe "sudo sed -i --follow-symlinks 's|^# $i|$i|' '$loc_file'" || return 1
            modified=Y
        fi
    done
    [[ -n "$modified" ]] && exe 'sudo locale-gen'
    # }}}

    return 0
}


# can also exec 'setxkbmap -option' caps:escape or use dconf-editor; also could use $loadkeys
# or switch it via XKB options (see https://wiki.archlinux.org/index.php/Keyboard_configuration_in_Xorg)
#
# see also https://gist.github.com/tanyuan/55bca522bf50363ae4573d4bdcf06e2e
#
# to see current active keyboard setting:    setxkbmap -print -verbose 10
#################
# TODO: do not call; looks like changing pc file makes xcape not work for the remapped caps key;
#       regular ctrl key worked fine, but caps key only worked as esc -- ctrl functionality was broken for it.
#       we're calling alternative logic from .xinitrc instead.
# TODO: deprecated
swap_caps_lock_and_esc() {
    local conf_file

    readonly conf_file='/usr/share/X11/xkb/symbols/pc'

    is_f "$conf_file" || return 1

    # map esc to caps:
    if ! grep -Eq 'key <ESC>.*Caps_Lock' "$conf_file"; then
        # hasn't been replaced yet
        if ! exe "sudo sed -i --follow-symlinks 's/.*key.*ESC.*Escape.*/    key <ESC>  \{    \[ Caps_Lock     \]   \};/g' $conf_file"; then
            err "mapping esc->caps @ [$conf_file] failed"
            return 2
        fi
    fi

    # map caps to control:
    if ! grep -Eq 'key <CAPS>.*Control_L' "$conf_file"; then
        # hasn't been replaced yet
        if ! exe "sudo sed -i --follow-symlinks 's/.*key.*CAPS.*Caps_Lock.*/    key <CAPS> \{    \[ Control_L        \]   \};/g' $conf_file"; then
            err "mapping caps->esc @ [$conf_file] failed"
            return 2
        fi
    fi

    # make short-pressed Ctrl behave like Escape:
    exe "xcape -e 'Control_L=Escape'" || return 2   # note this command needs to be ran also at every startup!

    return 0
}


install_progs() {

    exe "sudo apt-get --yes update"

    install_webdev
    install_from_repo
    install_from_flatpak
    install_own_builds  # has to be after install_from_repo()

    is_native && install_nvidia
    is_native && install_amd_gpu
    is_native && install_cpu_microcode_pkg
    #is_native && install_games

    post_install_progs_setup
}


install_xonotic() {
    local url

    # note we're selecting a mirror URL here:
    url="$(curl -Lsf --retry 2 'https://xonotic.org/download/' \
        | grep -Po '<a href="\Khttps://dl\.xonotic.org/xonotic-[0-9.]+\.zip(?="><i class=".*"></i>\s*xonotic.org</a>.*DE)')"

    [[ -z "$url" ]] && { err "couldn't resolve xonotic version"; return 1; }
    install_from_url -D -d "$BASE_PROGS_DIR" xonotic "$url" || return 1

    # TODO: use glx or sdl script? best try both and benchmark w/ included 'the-big-benchmark'
    create_link "$BASE_PROGS_DIR/xonotic/xonotic-linux-glx.sh" "$HOME/bin/xonotic"

    ######################################
    # TODO: this doesn't work atm, as it fetches also older versions' urls:
    #install_from_any -D -d "$BASE_PROGS_DIR" xonotic 'https://xonotic.org/download/' 'https://dl\.xonotic.org/xonotic-[0-9.]+\.zip'
    #create_link "$BASE_PROGS_DIR/xonotic/xonotic-linux-glx.sh" "$HOME/bin/xonotic"
}


install_games() {
    #install_xonotic
    #install_block openttd  # openttd = transport tycoon deluxe
    true
}


# https://github.com/fwupd/fwupd
# depends on the fwupd package
#
# note this is only manually executed, not during automatic install/upgrades
upgrade_firmware() {
    local c

    # display all devices detected by fwupd:
    exe -c 0,2 'fwupdmgr get-devices' || return 1

    # download latest metadata from LVFS:
    exe -c 0,2 'fwupdmgr refresh' || return 1  # note it can exit w/ 2, and saying it was refreshed X time ago; not the case if passing '--force' flag to it

    # if updates are available, they'll be displayed:
    exe -c 0,2 -r 'fwupdmgr get-updates'
    c=$?
    if [[ $c -eq 2 ]]; then
        report "no updates avail"
        return 0
    elif [[ $c -ne 0 ]]; then
        return $c
    fi

    # downlaod and apply all updates (will be prompted first)
    exe 'fwupdmgr update'
}


# TODO: /etc/modules is still supported by debian, but is an older system/mechanic; perhaps
# start using /etc/modules-load.d/ instead? as of '25 debian appears to symlink
# /etc/modules-load.d/modules.conf -> /etc/modules, so who knows...
#
# Note: dashes & underscores are interchangeable in module names.
install_kernel_modules() {
    local conf modules i

    conf='/etc/modules'

    is_f -m 'skipping kernel module installation' "$conf" || return 1

    # note as per https://wiki.archlinux.org/title/Backlight :
    #   > Using ddcci and i2c-dev simultaneously may result in resource conflicts such as a Device or resource busy error.
    #
    # list of modules to be added to $conf for auto-loading at boot:
    modules=(
        ddcci
    )

    # from https://www.ddcutil.com/kernel_module/ : only load
    # i2c on demand if it's not already loaded into kernel:
    i="/lib/modules/$(uname -r)/modules.builtin"
    [[ -s "$i" ]] || err "modules.builtin not a file, fix the logic!"  # sanity
    grep -q  i2c-dev.ko  "$i" || modules+=(i2c-dev)

    # ddcci-dkms gives us DDC support so we can control also external monitor brightness (via brillo et al; not related to i2c-dev/ddcutil)
    # note project is @ https://gitlab.com/ddcci-driver-linux/ddcci-driver-linux
    install_block  ddcci-dkms || return 1

    for i in "${modules[@]}"; do
        grep -Fxq "$i" "$conf" || exe "echo $i | sudo tee --append $conf > /dev/null"
    done
}


# to force ver: apt-get install linux-image-amd64:version
# check avail vers: apt-cache showpkg linux-image-amd64
upgrade_kernel() {
    local kernels_list arch

    # install kernel meta-packages:
    # NOTE: these meta-packages only required, if using non-stable debian;
    # they keep the kernel and headers in sync; also note 'linux-image-amd64'
    # always pulls in latest kernel by default.
    if is_64_bit; then
        report "first installing kernel meta-packages..."
        install_block '
            linux-image-amd64
            linux-headers-amd64
        '
        readonly arch='amd64'  # or instead of magic string, do  $ dpkg --print-architecture
    else
        err "verified we're not running 64bit system. make sure it's correct. skipping kernel meta-package installation..."
        sleep 10
    fi

    if is_noninteractive || [[ "$MODE" -ne 0 ]]; then return 0; fi  # only ask for custom kernel ver when we're in manual mode (single task), or we're in noninteractive node

    # search for available kernel images:
    readarray -t kernels_list < <(apt-cache search --names-only "^linux-image-[-.0-9]+.*$arch\$" | cut -d' ' -f1 | sort -r --version-sort)

    [[ -z "${kernels_list[*]}" ]] && { err "apt-cache search didn't find any kernel images. skipping kernel upgrade"; sleep 5; return 1; }

    while true; do
       echo
       #report "note kernel was just updated, but you can select different ver:"
       report "select kernel to install: (select none to skip kernel change)\n"
       select_items -s "${kernels_list[@]}"

       if [[ -n "$__SELECTED_ITEMS" ]]; then
          report "installing ${__SELECTED_ITEMS}..."
          exe "sudo apt-get --yes install $__SELECTED_ITEMS"
          break
       else
          confirm "no items were selected; skip kernel change?" && break
       fi
    done

    unset __SELECTED_ITEMS
}


# note this should still be common for both work & non-work
install_devstuff() {
    #install_rebar
    install_lazygit
    install_lazydocker
    install_dive
    #install_gitkraken

    #install_saml2aws
    #install_aia
    install_kustomize
    install_k9s
    install_krew
    install_popeye
    #install_kops
    install_kubectx
    install_kube_ps1
    install_sops
    is_native && install_grpcui
    #install_postman
    install_bruno
    #install_terragrunt
    install_minikube
    #install_coursier

    install_kubectl
}


# 'own build' as in everything from not the debian repository; either build from
# source, or fetch from the interwebs and install/configure manually.
#
# note single-task counterpart would be __choose_prog_to_build()
install_own_builds() {

    #prepare_build_container

    install_fzf
    install_neovide
    #install_keepassxc
    #install_keybase
    #build_goforit
    #build_copyq
    install_lesspipe
    install_lessfilter
    is_native && install_uhk_agent
    #is_native && build_ddcutil  # currently installing from repo
    install_seafile_cli
    # TODO: why are ferdium&discord behind is_native?
    is_native && install_ferdium
    #install_xournalpp
    #install_zoxide
    install_ripgrep
    install_rga
    #install_browsh
    #install_treesitter
    install_vnote
    #install_obsidian
    install_delta
    install_dust
    #install_bandwhich
    is_btrfs && install_btdu
    install_peco
    install_fd
    install_jd
    install_bat
    install_sad
    install_glow
    install_btop
    install_procs
    #install_alacritty
    install_wezterm
    install_atuin
    install_lnav
    install_croc
    install_kanata
    install_eza
    install_i3
    #build_polybar  # currently installing from repo
    install_gruvbox_gtk_theme
    #install_weeslack
    install_gomuks
    #is_native && install_slack_term
    #install_slack
    install_veracrypt
    install_ueberzugpp
    #install_hblock
    install_open_eid
    #install_binance
    install_electrum_wallet
    install_revanced
    install_apkeditor

    is_native && build_i3lock
    #is_native && build_i3lock_fancy
    #is_native && install_betterlockscreen
    #is_native && install_acpilight
    is_native && install_brillo
    is_native && install_display_switch

    [[ "$PROFILE" == work ]] && install_work_builds
    install_devstuff
}


install_work_builds() {
    true
}


# build container exec
bc_exe() {
    local cmds="$*"
    exe "docker exec -it $(docker ps -qf "name=$BUILD_DOCK") bash -c '$cmds'"
}


# build container install
bc_install() {
    local progs

    declare -ra progs=("$@")
    bc_exe "DEBIAN_FRONTEND=noninteractive  NEEDRESTART_MODE=l  apt-get --yes install ${progs[*]}" || return $?
}


prepare_build_container() {  # TODO container build env not used atm
    if [[ -z "$(docker ps -qa -f name="$BUILD_DOCK")" ]]; then  # container hasn't been created
        #exe "docker create -t --name '$BUILD_DOCK' debian:testing-slim" || return 1  # alternative to docker run
        exe "docker run -dit --name '$BUILD_DOCK' -v '$BASE_BUILDS_DIR:/out' debian:testing-slim" || return 1
        bc_exe "apt-get --yes update" || return 1
        bc_install git checkinstall build-essential devscripts equivs cmake || return 1
    fi

    if [[ -z "$(docker ps -qa -f status=running -f name="$BUILD_DOCK")" ]]; then
        exe "docker start '$BUILD_DOCK'" || return 1
    fi

    bc_exe "apt-get --yes update"
}


# note this function optimistically handles the version tracking, although
# installation happens by the caller and might fail.
#
# -T      - instead of grepping via asset rgx, go with the latest tarball
# -Z      - instead of grepping via asset rgx, go with the latest zipball
# -v ver  - specify tag to install; this is to pin a version
#
# $1 - git user/repo
# $2 - asset regex to be used (for jq's test()) to parse correct item from git /releases page. note jq requires most likely double-backslashes!
# $3 - what to rename resulting file as; optional, but recommended
#
# see also:
#  - https://github.com/OhMyMndy/bin-get
#  - https://github.com/wimpysworld/deb-get
fetch_release_from_git() {
    local opt loc id OPTIND dl_url opts selector ver token

    declare -a opts
    ver=latest  # default
    while getopts 'UDsf:n:TZv:' opt; do
        case "$opt" in
            U|D|s) opts+=("-$opt") ;;
            f|n) opts+=("-$opt" "$OPTARG") ;;
            T) selector='.tarball_url' ;;
            Z) selector='.zipball_url' ;;
            v) ver="tags/$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ -n "$selector" && -n "$2" ]] && { err "if -T or -Z options provided, then asset regex should not be given as it won't be used"; return 1; }
    [[ -z "$selector" ]] && selector=".assets[] | select(.name|test(\"$2\$\")) | .browser_download_url"

    readonly loc="https://api.github.com/repos/$1/releases/$ver"
    token="$(getnetrc curl@ghapi.com)" && token="-u $token" || err "couldn't resolve gh api token"
    # note including api version is recommended: https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api#not-a-supported-version
    dl_url="$(curl -fsSL -A "$USER_AGENT" -H 'X-GitHub-Api-Version:2022-11-28' $token -- "$loc" \
        | jq -er "$selector")" || { err "asset url resolution from [$loc] via selector [$selector] failed w/ $?"; return 1; }
    readonly id="github-${1//\//-}${3:+-$3}"  # note we append name to the id when defined (same repo might contain multiple binaries we're installing)

    is_valid_url "$dl_url" || { err "resolved url for ${id} is improper: [$dl_url]; aborting"; return 1; }
    _fetch_release_common "${opts[@]}" "$id" "$dl_url" "$dl_url" "$3"
}


# common logic for both fetch_release_from_{git,any}()
# TODO: as of '25 only user is fetch_release_from_git()
#
# TODO: try to add install logic/flow path in here??
#       the pass-through of flags to install_file() is messy tho, so unsure
#
_fetch_release_common() {
    local opt extract_opts noextract skipadd id ver dl_url name tmpdir file OPTIND

    declare -a extract_opts
    while getopts 'UsDf:n:' opt; do
        case "$opt" in
            U) noextract=TRUE ;;
            s) skipadd=TRUE ;;
            D) extract_opts+=("-$opt") ;;
            f|n) extract_opts+=("-$opt" "$OPTARG") ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    id="$1"
    ver="$2"
    dl_url="$3"
    name="$4"  # optional, but recommended

    [[ "$name" == */* ]] && { err "name arg can't be a path, but was [$name]"; return 1; }
    [[ -z "$skipadd" ]] && is_installed "$ver" "$id" && return 2
    tmpdir="$(mkt "release-from-${id}")" || return 1

    report "fetching [$dl_url]..."
    exe "wget --user-agent='$USER_AGENT' --content-disposition -q --directory-prefix=$tmpdir '$dl_url'" || { err "wgetting [$dl_url] failed with $?"; return 1; }
    file="$(find "$tmpdir" -type f)"
    [[ -s "$file" ]] || { err "couldn't find single downloaded file in [$tmpdir]"; return 1; }

    if [[ -z "$noextract" ]] && is_archive "$file"; then
        file="$(extract_tarball "${extract_opts[@]}" "$file")" || return 1
    fi

    # TODO: should we invoke install_file() from this function instead of this reused logic? unsure..better read TODO at the top of this fun
    if [[ -n "$name" && "$(basename -- "$file")" != "$name" ]]; then
        exe "mv -- '$file' '$tmpdir/$name'" || { err "renaming [$file] to [$tmpdir/$name] failed"; return 1; }
        file="$tmpdir/$name"
    fi

    if [[ -z "$skipadd" ]]; then
        # we're assuming here that installation succeeded from here on.
        # it is optimistic, but removes repetitive calls.
        add_to_dl_log "$id" "$ver"
    fi

    #sanitize_apt "$tmpdir"  # think this is not really needed...
    echo "$file"  # note returned should be indeed path, even if only relative (ie './xyz'), not cleaned basename
    return 0
}


resolve_dl_urls() {
    local opt OPTIND multi zort excluded loc grep_tail page dl_url urls domain u

    while getopts 'MSE:' opt; do
        case "$opt" in
            M) multi=1 ;;  # ie multiple newline-separated urls/results are allowed (but not required!)
            S) zort=1 ;;  # if multiple urls, sort it down to single largest one. mnemonic: sort/single
            #E) excluded="(?=^((?!$OPTARG).)*$)" ;;  # pattern to blacklist from url matching; see https://superuser.com/a/537631/179401
                                                    # !! note this will exclude fail
                                                    # to match if pattern is anywhere
                                                    # on the page!!
                                                    #readonly dl_url="$(grep -Po "$excluded"'.* href="\K'"$grep_tail"'(?=")' <<< "$page" | sort --unique)"
            E) excluded="$OPTARG" ;;  # pattern to blacklist from matched url
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly loc="$1"
    readonly grep_tail="$2"

    domain="$(grep -Po '^https?://([^/]+)(?=)' <<< "$loc")"
    page="$(wget "$loc" --user-agent="$USER_AGENT" -q -O -)" || { err "wgetting [$loc] failed with $?"; return 1; }
    readonly dl_url="$(grep -Po ' href="\K'"$grep_tail"'(?=")' <<< "$page" | sort --unique)"

    if [[ -z "$dl_url" ]]; then
        err "no urls found from [$loc] for pattern [$grep_tail]"
        return 1
    fi

    while IFS= read -r u; do
        [[ -n "$excluded" ]] && grep -Eq "$excluded" <<< "$u" && continue
        [[ "$u" == /* ]] && u="${domain}$u"  # convert to fully qualified url

        u="$(html2text -width 1000000 <<< "$u")" || err "html2text processing for [$u] failed w/ [$?]"
        is_valid_url "$u" || { err "[$u] is not a valid download link"; return 1; }
        urls+="$u"$'\n'
    done <<< "$dl_url"

    # note we strip trailing newline in sort input:
    urls="$(sort --version-sort <<< "${urls:0:$(( ${#urls} - 1 ))}")"

    # debug:
    #report "   urls #:  $(wc -l <<< "$urls")"
    #report "   urls:  $(echo -e "$urls")"
    #report "   urls2:  [$(echo "$urls")]"

    if [[ -z "$urls" ]]; then
        err "all urls got filtered out after processing [$dl_url]?"  # TODO: this would never happen right?
        return 1
    elif [[ "$zort" == 1 ]] && ! is_single "$urls"; then
        urls="$(tail -n1 <<< "$urls")"
    elif [[ "$multi" != 1 ]] && ! is_single "$urls"; then
        err "multiple urls found from [$loc] for pattern [$grep_tail], but expecting a single result:"
        err "$urls"
        return 1
    fi

    echo "$urls"
}


# Fetch a file from a given page and install it.
#
# Note we will automaticaly extract the asset (and expect to locate a single file
# in the extracted result) if it's archived/compressed; pass -U to skip that step.
#
# -U     - skip extracting if archive and pass compressed/tarred ball as-is.
# -s     - skip adding fetched asset in $GIT_RLS_LOG
# -n     - filename pattern to be used by find; works together w/ -f;
# -f     - $file output pattern to grep for in order to filter for specific
#          single file from unpacked tarball (meaning it's pointless when -U is given);
#          as it stands, the _first_ file matching given filetype is returned, even
#          if there were more. works together w/ -n
# -r     - if href grep should be relative, ie start with / (note user should not prefix w/ '/' themselves)
# -d /target/dir    - dir to install pulled binary in, optional. (see install_file())
#                     note if installing whole dirs (-D), it should be the root dir;
#                     /$name will be created/appended by install_file()
# -D                - see install_file()
# -A                - install file as-is, do not derive method from mime;
#                     implies -U
# -I     - entity identifier (for logging/version tracking et al);
#          optional, if missing then use $name
#
# $1 - name of the binary/resource; also used in installed ver tracking.
# $2 - url to extract the asset url from;
# $3 - build/file regex to be used (for grep -Po) to parse correct item from git /releases page src;
#      note it matches 'til the very end of url (ie you should only provide the latter bit);
#
# see also: install_from_url()
install_from_any() {
    local install_file_args skipadd opt relative
    local name loc url_ptrn dl_url ver f OPTIND tmpdir id

    declare -a install_file_args
    while getopts 'sf:n:d:O:P:rUDAI:' opt; do
        case "$opt" in
            s) skipadd=TRUE ;;
            f|n|d|O|P) install_file_args+=("-$opt" "$OPTARG") ;;
            r) relative=TRUE ;;
            U|D|A) install_file_args+=("-$opt") ;;
            I) id="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly name="$1"
    readonly loc="$2"
    readonly url_ptrn="$3"

    id="${id:-$name}"

    dl_url="$(resolve_dl_urls "$loc" "${relative:+/}.*$url_ptrn")" || return 1  # note we might be looking for a relative url
    ver="$(resolve_ver "$dl_url")" || return 1
    [[ -z "$skipadd" ]] && is_installed "$ver" "$id" && return 2

    # instead of _fetch_release_common(), fetch ourselves (just like we do in install_from_url()):
    tmpdir="$(mkt "install-from-any-${id}")" || return 1
    exe "wget --content-disposition --user-agent='$USER_AGENT' -q --directory-prefix=$tmpdir '$dl_url'" || { err "wgetting [$dl_url] failed with $?"; return 1; }
    f="$(find "$tmpdir" -type f)"
    [[ -s "$f" ]] || { err "couldn't find single downloaded file in [$tmpdir]"; return 1; }

    install_file "${install_file_args[@]}" "$f" "$name" || return 1

    [[ -z "$skipadd" ]] && add_to_dl_log "$id" "$ver"
    return 0
}


# Fetch and extract a tarball from given github /releases page.
# Whether extraction is done into $PWD or a new tmpdir, is controlled via -S option.
#
# Also note the operation is successful only if a single directory gets extracted out.
#
#   -T|Z     see doc on fetch_release_from_git()
#
# $1 - git user/repo
# $2 - build/file regex to be used (for grep -P) to parse correct item from git /releases page src.
#
# @returns {string} path to root dir of extraction result, IF we found a
#                   _single_ dir in the result.
# @returns {bool} true, if we found a _single_ dir in result
fetch_extract_tarball_from_git() {
    local fetch_rls_opts opt OPTIND

    fetch_rls_opts=(-D)

    while getopts 'TZ' opt; do
        case "$opt" in
            T|Z) fetch_rls_opts+=("-$opt") ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    fetch_release_from_git "${fetch_rls_opts[@]}" "$1" "$2" || return $?
}


# Extract given tarball file. Optionally also first downloads the tarball.
# Note it'll be extracted into newly-created tempdir; if -S opt is provided, it
# gets extracted into current $pwd instead.
# Also note the operation is successful only if a single file gets extracted out,
# unless -D option is provided, in which case extracted root dir is returned.
#
# Note input $file is removed upon successful extraction
#
# -S     - flag to extract into current $PWD, ie won't create a new tempdir.
# -D     - we want extracted root dir, not a single file;
# -n     - filename pattern to be used by find; works together w/ -f;
# -f     - $file output pattern to grep for in order to filter for specific
#          single file from unpacked tarball;
#          as it stands, the _first_ file matching given filetype is returned, even
#          if there were more. works together w/ -n opt;
#
# $1 - tarball file to be extracted, or a URL where to fetch file from first
#      TODO: remove url support? as we're not tracking the version this way.
#            I guess it could be left for the caller to track.
#
# @returns {string} path to root dir of extraction result, IF we found a
#                   _single_ dir in the result.
# @returns {bool} true, if we found a _single_ file (or dir, if -D option is provided)
#                 in result; also the full path to dir/file is returned.
extract_tarball() {
    local opt standalone dir_only file_filter name_filter file dir OPTIND tmpdir

    dir_only=0  # default to seeking for a single file
    while getopts 'SDf:n:' opt; do
        case "$opt" in
            S) readonly standalone=1 ;;
            D) dir_only=1 ;;
            f) readonly file_filter="$OPTARG"
               dir_only=0 ;;
            n) readonly name_filter="$OPTARG"
               dir_only=0 ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    file="$1"

    if is_valid_url "$file"; then
        tmpdir="$(mkt "tarball-download-extract")" || return 1
        exe "wget --content-disposition --user-agent='$USER_AGENT' -q --directory-prefix=$tmpdir '$file'" || { err "wgetting [$file] failed with $?"; return 1; }
        file="$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type f)"
    fi

    is_f "$file" || return 1
    [[ -n "$file_filter" || -n "$name_filter" ]] && [[ "$dir_only" == 1 ]] && { err "[fnD] options are mutually exclusive"; return 1; }
    is_archive "$file" || { err "[$file] is not an archive, cannot decompress"; return 1; }

    if [[ "$standalone" != 1 ]]; then
        tmpdir="$(mkt "tarball-extract")" || return 1
        exe "pushd -- $tmpdir" || return 1
    fi

    if [[ "$file" == *.tbz ]]; then  # TODO: aunpack can't unpack tbz
        exe "tar -xjf '$file'" > /dev/null || { err "extracting [$file] failed w/ $?"; [[ "$standalone" != 1 ]] && popd; return 1; }
    else
        exe "aunpack --extract --quiet '$file'" > /dev/null || { err "extracting [$file] failed w/ $?"; [[ "$standalone" != 1 ]] && popd; return 1; }
    fi

    exe "rm -f -- '$file'" || { [[ "$standalone" != 1 ]] && popd; return 1; }

    dir="$(find "$(pwd -P)" -mindepth 1 -maxdepth 1 -type d)"  # do not verify -d $dir _yet_ - ok to fail if $dir_only != 1
    [[ "$standalone" != 1 ]] && exe popd

    if [[ "$dir_only" == 1 ]]; then
        [[ -d "$dir" ]] || { err "couldn't find single extracted dir in extracted tarball"; return 1; }
        echo "$dir"
    else  # we're looking for a specific file (not a dir!) under extracted tarball
        unset file
        [[ "$standalone" != 1 ]] && dir="$tmpdir" || dir='.'

        # TODO: support recursive extraction?
        if [[ -n "$file_filter" ]]; then
            while IFS= read -r -d $'\0' file; do
                file -iLb "$file" | grep -Eq "$file_filter" && break || unset file
            done < <(find "$dir" -name "${name_filter:-*}" -type f -print0)
        else
            file="$(find "$dir" -name "${name_filter:-*}" -type f)"
        fi

        [[ -f "$file" ]] || { err "couldn't locate single extracted/uncompressed file in [$(realpath "$dir")]; resulting/found asset is [$file]"; return 1; }
        echo "$file"
    fi

    return 0
    # do NOT remove $tmpdir! caller can clean up if they want
}


# Fetch a file from given github /releases page, and install the executable binary.
# Convenience function.
install_bin_from_git() {
    # as to why we include 'sharedlib', see https://gitlab.freedesktop.org/xdg/shared-mime-info/-/issues/11 (e.g. some rust binaries are like that)
    install_from_git -f 'application/x-(pie-)?(sharedlib|executable)' "$@"
}


# common gh installer
#
# TODO: see https://github.com/houseabsolute/ubi
#       and https://github.com/aquaproj/aqua
#
# -U                 - do not upack the compressed/archived asset
# -A                 - install file as-is, do not derive method from mime;
#                      implies -U
# -O, -P             - see install_file()
# -d /target/dir     - dir to install pulled binary in, optional
# -N name            - what to name pulled file/dir to, optional, but recommended
# -n, -f, -v, -T, -Z, -D - see fetch_release_from_git()
# $1 - git user/repo
# $2 - build/file regex to be used (for grep -P) to parse correct item from git /releases page src.
install_from_git() {
    local opt f name OPTIND fetch_git_args install_file_args

    declare -a install_file_args fetch_git_args

    while getopts 'UDAN:O:P:d:n:f:v:TZ' opt; do
        case "$opt" in
            U|D) install_file_args+=("-$opt")
                 fetch_git_args+=("-$opt") ;;
            A) install_file_args+=("-$opt")
               fetch_git_args+=(-U) ;;
            N) name="$OPTARG" ;;
            O|P|d) install_file_args+=("-$opt" "$OPTARG") ;;
            n|f|v) fetch_git_args+=("-$opt" "$OPTARG") ;;
            T|Z) fetch_git_args+=("-$opt") ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    f="$(fetch_release_from_git "${fetch_git_args[@]}" "$1" "$2" "$name")" || return 1
    install_file "${install_file_args[@]}" "$f" "$name" || return 1
}


# terminal-based presentation/slideshow tool
#
# alternative: https://github.com/visit1985/mdp
# another, more rich alternative: https://github.com/slidevjs/slidev
install_slides() {  # https://github.com/maaslalani/slides
    install_bin_from_git -N slides maaslalani/slides '_linux_amd64.tar.gz'
}


# Franz nag-less fork.
# might also consider free rambox: https://rambox.app/download-linux/
# another alternative: https://github.com/getstation/desktop-app
#                      https://github.com/beeper <- selfhostable built on matrix?
install_ferdium() {  # https://github.com/ferdium/ferdium-app
    #install_from_git ferdium/ferdium-app '-amd64.deb'
    install_bin_from_git -N ferdium ferdium/ferdium-app 'x86_64.AppImage'
}


# also avail as flatpak
install_freetube() {  # https://github.com/FreeTubeApp/FreeTube
    install_bin_from_git -N freetube FreeTubeApp/FreeTube 'amd64.AppImage'
}


# https://help.seafile.com/syncing_client/install_linux_client/
# !!! "Since 9.0.7 version, we only provide official packages in AppImage format" !!!
#
# note url is like https://s3.eu-central-1.amazonaws.com/download.seadrive.org/Seafile-cli-x86_64-9.0.8.AppImage
install_seafile_cli() {
    install_from_any  seaf-cli 'https://www.seafile.com/en/download/' 'Seafile-cli-x86_64-[0-9.]+AppImage'
}


# https://help.seafile.com/syncing_client/install_linux_client/
# !!! "Since 9.0.7 version, we only provide official packages in AppImage format" !!!
#
# note url is like  https://s3.eu-central-1.amazonaws.com/download.seadrive.org/Seafile-x86_64-9.0.8.AppImage
install_seafile_gui() {
    install_from_any  seafile-gui 'https://www.seafile.com/en/download/' 'Seafile-x86_64-[0-9.]+AppImage'
}


# Xournalpp is a handwriting notetaking app; I'm using it for PDF document annotation
# (ie providing that fake handwritten signature).
#
# how to sign pdf: https://viktorsmari.github.io/linux/pdf/2018/08/23/annotate-pdf-linux.html
#
# also avail in apt, and as appimage
install_xournalpp() {  # https://github.com/xournalpp/xournalpp
    install_from_git xournalpp/xournalpp 'Debian-.*x86_64.deb'
    #install_bin_from_git -N xournalpp xournalpp/xournalpp '-x86_64.AppImage'
}


# ueberzug drop-in replacement written in c++
# also avail via brew
install_ueberzugpp() {  # https://github.com/jstkdng/ueberzugpp
    install_from_any  ueberzugpp  'https://software.opensuse.org/download.html?project=home%3Ajustkidding&package=ueberzugpp#directDebian' \
        'Debian_Testing.*[-0-9.]+_amd64\.deb'
}


resolve_ver() {
    local url ver hdrs

    readonly url="$1"

    # verify the passed string includes (likely) a version
    _verif_ver() {
        local v n i j o
        v="$1"
        [[ "$v" == http* ]] && v="$(grep -Po '^https?://([^/]+)\K.*' <<< "$v")"  # remove the domain, we only care for the path part
        n=3  # we want to see at least 3 digits in url to make it more likely we have version in it

        # increase $n by the number of digits in $v that are not part of ver:
        for i in 'x86\S64' 'linux\S{,2}64' 'amd\S{,2}64'; do
            readarray o < <(grep -Eio "$i" <<< "$v")  # occurrences of $i in $v
            for j in "${o[@]}"; do
                i="${j//[!0-9]/}"  # leave only digits
                let n+=${#i}
            done
        done
        v="${v//[!0-9]/}"  # leave only digits
        [[ "${#v}" -ge "$n" ]]
    }

    hdrs="$(curl -Ls --fail --retry 1 -A "$USER_AGENT" --head -o /dev/stdout "$url")"
    ver="$(grep -iPo '^etag:\s*"*\K\S+(?=")' <<< "$hdrs" | tail -1)"  # extract the very last redirect; resolving it is needed for is_installed() check
    if [[ "${#ver}" -le 5 ]]; then
        ver="$(grep -iPo '^location:\s*\K\S+' <<< "$hdrs" | tail -1)"  # extract the very last redirect; resolving it is needed for is_installed() check
        if [[ "${#ver}" -le 5 ]]; then
            # TODO: is grepping for content-disposition hdr a good idea?
            #       example case of this being used is Postman
            ver="$(grep -iPo '^content-disposition:.*filename="*\K.+' <<< "$hdrs" | tail -1)"  # extract the very last redirect; resolving it is needed for is_installed() check
            _verif_ver "$ver" || ver="$url"  # TODO: is this okay assumption for version tracking? maybe just not store ver and always install?
        fi

        _verif_ver "$ver" || err "ver resolve from url [$url] resource dubious, as resolved ver [$ver] doesn't have enough digits"
    fi

    unset _verif_ver
    echo "$ver"
}


# Fetch a file from given url, and install the binary. If url redirects to final
# file asset, we follow the redirects.
#
# -s                - skip adding fetched asset in $GIT_RLS_LOG
# -D, -A            - see install_file()
# -O owner:group    - see install_file()
# -P perms          - see install_file()
# -d /target/dir    - see install_file()
#                     dir to install pulled binary in, optional.
#                     note if installing whole dirs (-D), it should be the root dir;
#                     /$name will be created/appended by install_file()
# $1 - name of the binary/resource
# $2 - resource url
install_from_url() {
    local opt skipadd OPTIND opts name loc file ver tmpdir

    declare -a opts
    while getopts 'sDAO:P:d:' opt; do
        case "$opt" in
            s) skipadd=TRUE ;;
            D|A) opts+=("-$opt") ;;
            O|P|d) opts+=("-$opt" "$OPTARG") ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly name="$1"
    readonly loc="$2"

    [[ -z "$name" ]] && { err "[name] param required"; return 1; }

    ver="$(resolve_ver "$loc")" || return 1

    if ! is_valid_url "$loc"; then
        err "passed url for $name is improper: [$loc]; aborting"
        return 1
    elif [[ -z "$skipadd" ]] && is_installed "$ver" "$name"; then
        return 2
    fi

    tmpdir="$(mkt "install-from-url-${name}")" || return 1
    exe "wget --content-disposition --user-agent='$USER_AGENT' -q --directory-prefix=$tmpdir '$loc'" || { err "wgetting [$loc] failed with $?"; return 1; }
    file="$(find "$tmpdir" -type f)"
    [[ -s "$file" ]] || { err "couldn't find single downloaded file in [$tmpdir]"; return 1; }

    install_file "${opts[@]}" "$file" "$name" || return 1

    [[ -z "$skipadd" ]] && add_to_dl_log "$name" "$ver"
    return 0
}


# curl given $loc and pipe it to a $shell for installation
install_from_url_shell() {
    local opt OPTIND shell name loc ver

    shell=bash  # default
    while getopts 's' opt; do
        case "$opt" in
            s) shell='sh' ;;  # TODO: rename opt to d) for dash?
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly name="$1"
    readonly loc="$2"

    [[ -z "$name" ]] && { err "[name] param required"; return 1; }

    ver="$(resolve_ver "$loc")" || return 1

    if ! is_valid_url "$loc"; then
        err "passed url for $name is improper: [$loc]; aborting"
        return 1
    elif is_installed "$ver" "$name"; then
        return 2
    fi

    exe "curl -fsSL -A "$USER_AGENT" '$loc' | $shell" || return 1
    add_to_dl_log "$name" "$ver"
}


install_file() {
    local opt OPTIND ftype target extract_opts noextract owner perms file name asis

    target='/usr/local/bin'  # default

    declare -a extract_opts
    while getopts 'd:DUf:n:O:P:A' opt; do
        case "$opt" in
            d) target="$OPTARG" ;;
            D) extract_opts+=("-$opt") ;;  # mnemonic: directory; ie we want the "whole directory" in case $file is tarball
            U) noextract=TRUE ;;  # if, for whatever the reason, an archive/tarball should not be unpacked
            f|n) extract_opts+=("-$opt" "$OPTARG") ;;  # no use if -D or -U is used
            O) owner="$OPTARG" ;;  # chown
            P) perms="$OPTARG" ;;  # chmod
            A) asis=TRUE       # install file as-is, do not derive method from mimetype;
               noextract=TRUE ;;  # note -U is implied
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    file="$1"
    name="$2"  # OPTIONAL, unless installing whole uncompressed dir (-D opt)

    [[ -f "$file" || -d "$file" ]] || { err "node [$file] not a regular file nor a dir"; return 1; }
    is_d -m "can't install [${name:+$name///}$file]" "$target" || return 1
    if list_contains '-f' "${extract_opts[@]}" || list_contains '-n' "${extract_opts[@]}"; then
        if list_contains '-D' "${extract_opts[@]}" || list_contains '-U' "${extract_opts[@]}"; then
            err '[fn|DU] options are mutually exclusive'
            return 1
        fi
    fi

    if [[ -z "$noextract" ]] && is_archive "$file"; then
        file="$(extract_tarball "${extract_opts[@]}" "$file")" || return 1
    fi

    _process() {
        if [[ -n "$name" && "$(basename -- "$file")" != "$name" ]]; then  # check if rename is needed
            local tmpdir
            tmpdir="$(mkt "install-file-${name}")" || return 1
            exe "mv -- '$file' '$tmpdir/$name'" || { err "renaming [$file] to [$tmpdir/$name] failed"; return 1; }
            file="$tmpdir/$name"
        fi

        _owner_perms "$file"
    }

    _owner_perms() {
        local f="$1"

        if [[ -n "$owner" ]]; then
            exe "sudo chown -R -- '$owner' '$f'" || return 1
        fi
        if [[ -n "$perms" ]]; then
            exe "sudo chmod -R -- '$perms' '$f'" || return 1
        fi
    }

    [[ -n "$asis" ]] && ftype='text/plain; charset=' || ftype="$(file -iLb -- "$file")"  # mock as-is filetype to enable simple file move logic

    if [[ "$ftype" == 'text/plain; charset='* ]]; then  # same as executable/binary above, but do not set executable flag
        _process || return 1
        exe "sudo install -m644 -C --group=$USER '$file' '$target'" || return 1
        _owner_perms "$target/$(basename -- "$file")"
    elif [[ "$ftype" == *'inode/directory; charset=binary' ]]; then
        [[ -z "$name" ]] && { err "[name] arg needs to be provided when installing a directory"; return 1; }
        _process || return 1
        target+="/$name"
        [[ -d "$target" ]] && { exe "rm -rf -- '$target'" || return 1; }  # rm previous installation
        exe "mv -- '$file' '$target'" || return 1
    elif [[ "$ftype" == *'executable; charset=binary' || "$ftype" == 'text/x-shellscript; charset='* || "$ftype" == 'text/x-perl; charset='* ]]; then
        exe "chmod +x '$file'" || return 1
        _process || return 1
        exe "sudo install -m754 -C --group=$USER '$file' '$target'" || return 1
        _owner_perms "$target/$(basename -- "$file")"
    elif [[ "$ftype" == *'debian.binary-package; charset=binary' ]]; then
        exe "sudo DEBIAN_FRONTEND=noninteractive  NEEDRESTART_MODE=l  apt-get --yes install '$file'" || { err "apt-get installing [$file] failed"; return 1; }
        exe "rm -f -- '$file'"
    else
        err "dunno how to install file [$file] - unknown type [$ftype]"
        exe "rm -f -- '$file'"
        return 1
    fi
    unset _process _owner_perms
}


install_zoom() {  # https://zoom.us/download
    install_from_url  zoom 'https://zoom.us/client/latest/zoom_amd64.deb'
}


# fasd-alike alternative
# also avail in apt
install_zoxide() {  # https://github.com/ajeetdsouza/zoxide
    #install_bin_from_git -N zoxide ajeetdsouza/zoxide '-x86_64-unknown-linux-musl.tar.gz'
    install_from_git ajeetdsouza/zoxide '_amd64.deb'
}


# fuzzy file finder/command completer etc
# https://github.com/junegunn/fzf
install_fzf() {
    install_bin_from_git -N fzf junegunn/fzf 'linux_amd64.tar.gz'
}


# currently installing via apt
#install_nushell() {
    #install_bin_from_git -N nu nushell/nushell  'x86_64-unknown-linux-gnu.tar.gz'
#}


# TODO: looks like after initial installation apt keeps updating it automatically?!
install_slack() {  # https://slack.com/help/articles/212924728-Download-Slack-for-Linux--beta-
    install_from_any  slack 'https://slack.com/downloads/instructions/linux?build=deb' '-amd64\.deb'
}


# also avail in apt repo
install_rebar() {  # https://github.com/erlang/rebar3
    install_bin_from_git -N rebar3 erlang/rebar3 rebar3
}


install_treesitter() {  # https://github.com/tree-sitter/tree-sitter
    install_bin_from_git -N tree-sitter tree-sitter/tree-sitter linux-x64.gz
}


# note: clojure also available through asdf
install_clojure() {  # https://clojure.org/guides/install_clojure#_linux_instructions
    local name install_target ver f

    readonly name=clojure
    readonly install_target="$BASE_PROGS_DIR/clojure"
    readonly f="$TMP_DIR/clojure-linux-install-${RANDOM}.sh"

    ver="$(get_git_tag "https://github.com/$name/brew-install.git")" || return 1
    is_installed "$ver" "$name" && return 2

    report "installing $name dependencies..."
    install_block 'rlwrap' || { err 'failed to install deps. abort.'; return 1; }

    exe "curl -fsSL -A "$USER_AGENT" 'https://github.com/clojure/brew-install/releases/latest/download/linux-install.sh' -o '$f'" || return 1
    exe "chmod +x '$f'" || return 1

    exe "$f --prefix $install_target" || return 1
    add_manpath "$install_target/bin" "$install_target/share/man"

    add_to_dl_log  "$name" "$ver"
    return 0
}


# beautifully format Clojure and Clojurescript source code and s-expressions;
# basically pretty printing capabilities for both Clojure code and Clojure/EDN structures.
install_zprint() {  # https://github.com/kkinnear/zprint/blob/main/doc/getting/linux.md
    install_bin_from_git -N zprint  kkinnear/zprint 'zprintl-[-.0-9]+'
}


# Lisp Flavoured Erlang (LFE)
install_lfe() {  # https://github.com/lfe/lfe
    true
}


# clojure static analyzer/linter
# https://github.com/clj-kondo/clj-kondo
install_clj_kondo() {
    install_bin_from_git -N clj-kondo  clj-kondo/clj-kondo 'clj-kondo-.*-linux-amd64.zip'
}

# scala application & artifact manager
# provides us with cs command
install_coursier() {  # https://github.com/coursier/coursier
    install_bin_from_git -N cs  coursier/coursier  cs-x86_64-pc-linux.gz
}

# also avail in apt
install_ripgrep() {  # https://github.com/BurntSushi/ripgrep
    install_from_git BurntSushi/ripgrep _amd64.deb
}


# rga: ripgrep, but also search in PDFs, E-Books, Office documents, zip, tar.gz, etc.
install_rga() {  # https://github.com/phiresky/ripgrep-all#debian-based
    install_block 'pandoc poppler-utils ffmpeg' || return 1
    install_bin_from_git -N rga -n rga phiresky/ripgrep-all 'x86_64-unknown-linux-musl.tar.gz'
}


# headless firefox in a terminal
install_browsh() {  # https://github.com/browsh-org/browsh
    install_from_git browsh-org/browsh _linux_amd64.deb
}


install_saml2aws() {  # https://github.com/Versent/saml2aws
    install_bin_from_git -N saml2aws Versent/saml2aws 'saml2aws_[0-9.]+_linux_amd64.tar.gz'
}

# kubernetes aws-iam-authenticator (k8s)
# tag: aws, k8s, kubernetes, auth
                          # https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
install_aia() {  # https://github.com/kubernetes-sigs/aws-iam-authenticator
    install_bin_from_git -N aws-iam-authenticator kubernetes-sigs/aws-iam-authenticator _linux_amd64
}

# kubernetes configuration customizer
# tag: aws, k8s, kubernetes, kubernetes-config, k8s-config
#
# alternatively use the curl-install hack from https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/
install_kustomize() {  # https://github.com/kubernetes-sigs/kustomize
    install_bin_from_git -N kustomize kubernetes-sigs/kustomize _linux_amd64.tar.gz
}

# kubernetes (k8s) cli management
# tag: aws, k8s, kubernetes
install_k9s() {  # https://github.com/derailed/k9s
    install_bin_from_git -N k9s derailed/k9s  _Linux_amd64.tar.gz
}

# krew (kubectl plugins package manager)
# tag: aws, k8s, kubernetes, kubectl
# installation instructions: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
install_krew() {  # https://github.com/kubernetes-sigs/krew
    local dir
    dir="$(fetch_extract_tarball_from_git  kubernetes-sigs/krew 'linux_amd64.tar.gz')" || return 1
    exe "$dir/krew-linux_amd64  install krew"
    #"$KREW" update || err "[krew update] failed w/ [$?]"
}

# kubernetes (k8s) config/resource sanitizer
#   "Popeye scans your Kubernetes clusters and reports potential resource issues."
#
# tag: aws, k8s, kubernetes
install_popeye() {  # https://github.com/derailed/popeye
    install_bin_from_git -N popeye derailed/popeye  _linux_amd64.tar.gz
}

# kubernetes cluster analyzer for better comprehension (introspective tooling, cluster
# navigation, object management)
# tag: aws, k8s, kubernetes
#
# see also https://github.com/spekt8/spekt8 - visualize your Kubernetes cluster in real time
#
# TODO: octant development halted, it's deprecated
install_octant() {  # https://github.com/vmware-tanzu/octant
    install_from_git  vmware-tanzu/octant  _Linux-64bit.deb
}

# kubernetes (k8s) operations - Production Grade K8s Installation, Upgrades, and Management
# tag: aws, k8s, kubernetes
# see also: kubebox,k9s,https://github.com/hjacobs/kube-ops-view
#
# for usecase, see https://medium.com/bench-engineering/deploying-kubernetes-clusters-with-kops-and-terraform-832b89250e8e
install_kops() {  # https://github.com/kubernetes/kops/
    install_bin_from_git -N kops kubernetes/kops  kops-linux-amd64
}

# kubectl:  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
install_kubectl() {
    install_from_url  kubectl  "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    # shell completion: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#bash
    command -v kubectl >/dev/null && exe "kubectl completion bash | tee $BASH_COMPLETIONS/kubectl > /dev/null"
}

# kubectx - kubernetes contex swithcher
# tag: aws, k8s, kubernetes
#
# TODO: consider replacing installation by using krew? note that likely won't install shell completion though;
# https://github.com/ahmetb/kubectx?tab=readme-ov-file#manual-installation-macos-and-linux
install_kubectx() {  # https://github.com/ahmetb/kubectx
    install_bin_from_git -N kubectx ahmetb/kubectx  'kubectx_.*_linux_x86_64.tar.gz'
    install_bin_from_git -N kubens  ahmetb/kubectx  'kubens_.*_linux_x86_64.tar.gz'

    # kubectx/kubens completion scripts:
    clone_or_pull_repo "ahmetb" "kubectx" "$BASE_PROGS_DIR" || return 1

    #local COMPDIR=$(pkg-config --variable=completionsdir bash-completion)
    #[[ -d "$COMPDIR" ]] || { err "[$COMPDIR] not a dir, cannot install kube{ctx,ns} shell completion"; return 1; }
    #create_link -s "${BASE_PROGS_DIR}/kubectx/completion/kubens.bash" "$COMPDIR/kubens"
    #create_link -s "${BASE_PROGS_DIR}/kubectx/completion/kubectx.bash" "$COMPDIR/kubectx"

    create_link "$BASE_PROGS_DIR/kubectx/completion/kubens.bash" "$BASH_COMPLETIONS/kubens"
    create_link "$BASE_PROGS_DIR/kubectx/completion/kubectx.bash" "$BASH_COMPLETIONS/kubectx"
}

# kube-ps1 - kubernets shell prompt
# tag: aws, k8s, kubernetes
install_kube_ps1() {  # https://github.com/jonmosco/kube-ps1
    clone_or_pull_repo "jonmosco" "kube-ps1" "$BASE_PROGS_DIR"
    # note there's corresponding entry in ~/.bashrc
}

# tool for managing secrets (SOPS: Secrets OPerationS)
# tag: aws
# note also installable via mise
install_sops() {  # https://github.com/getsops/sops
    install_from_git  getsops/sops _amd64.deb
}


# another GUI client for grpc: https://github.com/getezy/ezy
install_grpcui() {  # https://github.com/fullstorydev/grpcui
    install_bin_from_git -N grpcui fullstorydev/grpcui '_linux_x86_64.tar.gz'
}

# if build fails, you might be able to salvage something by doing:
#   sed -i 's/-Werror//g' Makefile
install_grpc_cli() {  # https://github.com/grpc/grpc/blob/master/doc/command_line_tool.md
    local repo ver tmpdir f

    readonly repo='https://github.com/grpc/grpc'
    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" grpc-cli && return 2

    tmpdir="$(mkt 'grpc-cli-tempdir')" || return 1
    exe "pushd -- '$tmpdir'" || return 1
    exe "git clone $repo" || return 1
    exe 'pushd -- grpc' || return 1
    exe 'git submodule update --init' || return 1
    exe 'mkdir -p cmake/build' || return 1
    exe 'pushd -- cmake/build' || return 1
    exe 'cmake -DgRPC_BUILD_TESTS=ON -DCMAKE_CXX_STANDARD=17 ../..' || return 1
    exe 'make -j8 grpc_cli' || return 1

    #install_block 'libgflags-dev' || return 1
    f="$(find . -mindepth 1 -type f -name 'grpc_cli')"
    [[ -f "$f" ]] || { err "couldn't find grpc_cli"; return 1; }
    exe "mv -- '$f' '$HOME/bin/'" || return 1

    add_to_dl_log "grpc-cli" "$ver"

    exe "popd; popd; popd" || return 1
    exe "rm -rf -- '$tmpdir'"
}


install_buku_related() {
    true  # TODO
    # https://gitlab.com/lbcnz/buku-rofi
    # https://github.com/AndreiUlmeyda/oil
}


# db/database visualisation tool (for mysql/mariadb)
# remember intellij idea also has a built-in db tool!
#
# https://github.com/dbeaver/dbeaver/wiki/Installation#debian-package
install_dbeaver() {  # https://dbeaver.io/download/
    #install_from_url  dbeaver 'https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb'
    #install_from_git  dbeaver/dbeaver '_amd64.deb'

    # alternatively, unrar the tarball:
    install_from_git -D -d "$BASE_PROGS_DIR" -N dbeaver  dbeaver/dbeaver 'linux.gtk.x86_64-nojdk.tar.gz' || return 1
    create_link "$BASE_PROGS_DIR/dbeaver/dbeaver" "$HOME/bin/dbeaver"
}


# https://www.gitkraken.com/download
install_gitkraken() {
    # deb url    :  https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.deb
    # tarball url:  https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.tar.gz
    install_from_url  gitkraken 'https://release.gitkraken.com/linux/gitkraken-amd64.deb'
}


# perforce git mergetool, alternative to meld;
#
# TODO: does not work in '25 - requires registration and whatnot
install_p4merge() {  # https://www.perforce.com/downloads/visual-merge-tool
    local ver loc

    ver="$(curl -Ls --fail --retry 1 -X POST -d 'family=722&form_id=pfs_inline_download_10_1_1&_triggering_element_name=family' \
        'https://www.perforce.com/downloads/visual-merge-tool?ajax_form=1&_wrapper_format=drupal_ajax' \
        | jq 'last.data' | grep -Po 'selected=\\"selected\\">\d{2}\K\d{2}\.\d(?=/)')"

    [[ -z "$ver" ]] && { err "couldn't resolve p4merge version"; return 1; }
    loc="https://www.perforce.com/downloads/perforce/r${ver}/bin.linux26x86_64/p4v.tgz"
    install_from_url -D -d "$BASE_PROGS_DIR" p4merge "$loc" || return 1
    create_link "${BASE_PROGS_DIR}/p4merge/bin/p4merge" "$HOME/bin/"
}


# steam-installer
install_steam() {  # https://store.steampowered.com/about/
    # either from deb fetched directly from steam...
    #install_from_url  steam 'https://cdn.akamai.steamstatic.com/client/installer/steam.deb'

    # ...or from apt repos:  # as per https://wiki.debian.org/Steam#Installing_Steam
    exe 'sudo dpkg --add-architecture i386'
    exe 'sudo apt-get update'
    install_block -f  steam-installer
}


install_chrome() {  # https://www.google.com/chrome/?platform=linux
    install_from_url  chrome 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
}


# alternatives:
# - https://github.com/joeferner/redis-commander
# - https://github.com/patrikx3/redis-ui
install_redis_desktop_manager() {
    install_bin_from_git -N redis-desktop-manager  qishibo/AnotherRedisDesktopManager 'x86_64.AppImage'
}


# other noting alternatives:
#   https://github.com/pbek/QOwnNotes  (also c++, qt-based like vnotes)
#   https://github.com/laurent22/joplin/ (still actively developed as of '25)
#   https://github.com/notable/notable/ (dead? last commit early '23)
#   https://github.com/BoostIO/BoostNote-App (last commit '22)
#   https://github.com/zadam/trilium  (also hostable as a server)
#   https://github.com/zk-org/zk  plain-text CLI too to maintain a plain text Zettelkasten or personal wiki.
#   https://github.com/TiddlyWiki/TiddlyWiki5
#   https://github.com/jakewvincent/mkdnflow.nvim - navigate markdown wikis
#   https://github.com/lervag/wiki.vim
#   # obsidian
install_vnote() {  # https://github.com/vnotex/vnote/releases
    install_bin_from_git -N vnote -n '*.AppImage' vnotex/vnote 'linux-x64.AppImage.zip'
}


# note there's this for vim: https://github.com/epwalsh/obsidian.nvim
install_obsidian() {  # https://github.com/obsidianmd/obsidian-releases/releases
    #install_from_git  obsidianmd/obsidian-releases '_amd64.deb'
    install_bin_from_git -N Obsidian obsidianmd/obsidian-releases '-[0-9.]{6,}AppImage'  # make sure to dodge the arm64 appimage
}


# https://www.postman.com/downloads/canary/
install_postman() {  # https://learning.postman.com/docs/getting-started/installation/installation-and-updates/#install-postman-on-linux
    local target dsk

    install_from_url -D -d "$BASE_PROGS_DIR" Postman "https://dl.pstmn.io/download/channel/canary/linux_64" || return 1
    target="$BASE_PROGS_DIR/Postman"

    # install .desktop:
    dsk="$HOME/.local/share/applications"
    is_d -m 'cannot install postman .desktop entry' "$dsk" || return 1
    echo "[Desktop Entry]
Encoding=UTF-8
Name=PostmanCanary
Exec=$target/PostmanCanary %U
Icon=$target/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
" > "$dsk/PostmanCanary.desktop" || { err "unable to create Postman .desktop in [$dsk]"; return 1; }
}


# https://github.com/advanced-rest-client/arc-electron/releases/latest
install_arc() {
    #install_from_git  advanced-rest-client/arc-electron '-amd64.deb'
    install_bin_from_git -N arc advanced-rest-client/arc-electron 'x86_64.AppImage'
}


# https://github.com/usebruno/bruno
#
# TODO: consider ARC (advanced rest client) instead: https://install.advancedrestclient.com/install
# TODO: or maybe httpie that apparently now has a GUI as well!
# TODO also recipeUI: https://github.com/RecipeUI/RecipeUI
# TODO also hoppscotch: https://hoppscotch.io/ (note it's possible to self-host as well)
# TODO not verified, but there's also https://kreya.app/ - note it's _not_ FOSS; note it's also not using electron, but 'native webview of the OS': read @ https://kreya.app/blog/how-we-built-kreya/ - note it also does grpc
# TODO !!!!!!!!!!!!!!!!!!!!: list of alternatives: https://github.com/stepci/awesome-api-clients
# for automated testing see https://github.com/stepci/stepci
# TODO also https://github.com/firecamp-dev/firecamp (relatively new as of Nov '23)
# haven't checked, but also https://github.com/manatlan/reqman
# there's also CLI client wrapping curl that uses toml-like config: https://github.com/jonaslu/ain
install_bruno() {
    install_bin_from_git -N bruno usebruno/bruno  _x86_64_linux.AppImage
    # or deb:
    #install_from_git  usebruno/bruno '_amd64_linux.deb'
}


install_alacritty() {
    local dir

    # first install deps: (https://github.com/alacritty/alacritty/blob/master/INSTALL.md#debianubuntu)
    report "installing alacritty build dependencies..."
    install_block 'cmake pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev' || return 1

    # quick, binary-only installation...:
    #exe 'cargo install alacritty'
    #return

    # ...or follow the full build logic if you want to install extras like manpages:
    dir="$(fetch_extract_tarball_from_git alacritty/alacritty 'v\\d+\\.\\d+.*\\.tar\\.gz')" || return 1

    exe "pushd $dir" || return 1

    # build: https://github.com/alacritty/alacritty/blob/master/INSTALL.md#building
    # Force support for only X11:
    exe 'cargo build --release --no-default-features --features=x11' || return 1  # should produce binary at target/release/alacritty

    # post-build setup: https://github.com/alacritty/alacritty/blob/master/INSTALL.md#post-build
    if ! infocmp alacritty; then
        exe 'sudo tic -xe alacritty,alacritty-direct extra/alacritty.info' || err
    fi

    # install man-pages:
    ensure_d -s "/usr/local/share/man/man1" || return 1
    exe 'gzip -c extra/alacritty.man | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null' || err
    exe 'gzip -c extra/alacritty-msg.man | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz > /dev/null' || err

    # install bash completion:
    exe "cp extra/completions/alacritty.bash $BASH_COMPLETIONS/alacritty" || err

    exe 'sudo mv -- target/release/alacritty  /usr/local/bin/' || err

    # cleanup:
    exe 'popd'
    exe "sudo rm -rf -- '$dir'"
    return 0
}


# https://wezterm.org/install/linux.html
#
# other terms to consider: kitty
# avail as flatpak but not recommended: https://flathub.org/apps/org.wezfurlong.wezterm
install_wezterm() {
    install_block  wezterm
}


# available also in apt
#
# alternatives:
# - https://github.com/ddworken/hishtory
# - https://github.com/cantino/mcfly
install_atuin() {  # https://github.com/atuinsh/atuin
    install_bin_from_git -N atuin atuinsh/atuin 'atuin-x86_64-unknown-linux-gnu.tar.gz'
}



# log file navigator
install_lnav() {  # https://github.com/tstack/lnav
    install_bin_from_git -N lnav tstack/lnav 'linux-musl-x86_64.zip'
}


# TODO last commit '20 - deprecated?
install_slack_term() {  # https://github.com/jpbruinsslot/slack-term
    install_bin_from_git -N slack-term jpbruinsslot/slack-term  slack-term-linux-amd64
}


# potentially useful tutorial: http://www.futurile.net/2020/11/30/weechat-for-slack/
#
# follow instruction at https://github.com/wee-slack/wee-slack#get-a-session-token
install_weeslack() {  # https://github.com/wee-slack/wee-slack
    local d
    d="$HOME/.local/share/weechat/python"
    install_block 'weechat-python python3-websocket' || return 1

    ensure_d "$d/autoload" || return 1
    #exe "pushd $d" || return 1

    #exe 'curl -O https://raw.githubusercontent.com/wee-slack/wee-slack/master/wee_slack.py' || { popd; return 1; }
    install_from_url -A -d "$d" wee_slack.py  'https://raw.githubusercontent.com/wee-slack/wee-slack/master/wee_slack.py'
    #exe 'ln -s ../wee_slack.py autoload'
    create_link "$d/wee_slack.py" "$d/autoload/"  # in order to start wee-slack automatically when weechat starts

    #exe 'popd' || return 1
}


# https://github.com/poljar/weechat-matrix#other-platforms ignore step 3, instead follow the next link...:
# https://github.com/poljar/weechat-matrix#run-from-git-directly
#
# superseded by https://github.com/poljar/weechat-matrix-rs
install_weechat_matrix() {  # https://github.com/poljar/weechat-matrix
    local d deps
    d="$HOME/.local/share/weechat/python"
    deps="${BASE_PROGS_DIR}/weechat-matrix"

    install_block 'libolm-dev' || return 1
    ensure_d "$d/autoload" || return 1

    clone_or_pull_repo "poljar" "weechat-matrix" "$deps/"

    exe "pip3 install --user -r $deps/requirements.txt"
    create_link "$deps/main.py" "$d/matrix.py"
    create_link "$deps/matrix" "$d/"
    create_link "$d/matrix.py" "$d/autoload/"
}


install_weechat_matrix_rs() {  # https://github.com/poljar/weechat-matrix-rs
    true  # as of '25 project is still in active dev, gotta wait...
}


# go-based matrix client
install_gomuks() {  # https://github.com/gomuks/gomuks
    #install_from_git gomuks/gomuks _amd64.deb
    install_bin_from_git -N gomuks gomuks/gomuks  gomuks-linux-amd64
}


# IRC to other chat networks gateway - https://www.bitlbee.org
# wiki: https://wiki.bitlbee.org/
#
install_bitlbee() {  # https://github.com/bitlbee/bitlbee

    # slack support: https://github.com/dylex/slack-libpurple
    # from https://github.com/dylex/slack-libpurple#linuxmacos
    _install_slack_support() {
        local name tmpdir repo ver

        readonly name=slack-libpurple
        readonly repo="https://github.com/dylex/slack-libpurple.git"

        ver="$(get_git_sha "$repo")" || return 1
        is_installed "$ver" "$name" && return 2

        tmpdir="$TMP_DIR/$name-build-${RANDOM}/build"
        exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
        exe "pushd $tmpdir" || return 1

        report "building $name..."

        # old checkinstall way: {
        #report "installing $name build dependencies..."
        #install_block 'libpurple-dev' || { err 'failed to install build deps. abort.'; return 1; }

        #exe "make" || { err; popd; return 1; }
        # note this project also supports  $ make install-user
        #create_deb_install_and_store  "$name" || { popd; return 1; }
        # } new sbuild: {
        # note as of '25 this fails w/ [dpkg-source: error: can't build with source format '3.0 (quilt)']
        # as included debian/source/format defines that format; removing the file fixed the issue.
        #exe 'dpkg-buildpackage -b'  # fyi this instead of build_deb() also works
        build_deb  "$name" libpurple-dev || { err "build_deb() for $name failed"; popd; return 1; }
        exe 'sudo dpkg -i ../purple-slack_*.deb' || { err "installing $name failed"; popd; return 1; }
        # }

        # put package on hold so they don't get overridden by apt-upgrade:
        exe "sudo apt-mark hold  $name"

        exe 'popd'
        exe "sudo rm -rf -- $tmpdir"

        add_to_dl_log  "$name" "$ver"

        return 0
    }

    # discord support (installed via 'purple-discord' pkg (https://github.com/EionRobb/purple-discord))
    # purple-discord package is in the main list

    # signal support
    # https://github.com/hoehermann/purple-presage  # very much WIP as of '25
    install_block 'qrencode'

    # slack:
    _install_slack_support

}

install_terragrunt() {  # https://github.com/gruntwork-io/terragrunt/
    install_bin_from_git -N terragrunt gruntwork-io/terragrunt  terragrunt_linux_amd64
}


install_eclipse_mem_analyzer() {
    local target loc page dl_url dir mirror ver

    target="$BASE_PROGS_DIR/mat"
    loc='https://eclipse.dev/mat/download'
    mirror=1208  # 1208 = france, 1301,1190,1045 = germany, 1099 = czech

    page="$(wget "$loc" -q --user-agent="$USER_AGENT" -O -)" || { err "wgetting [$loc] failed with $?"; return 1; }
    loc="$(grep -Po '.*a href="\K.*/\d+\.\d+\.\d+.*linux.gtk.x86_64.zip(?=")' <<< "$page")" || { err "parsing download link from [$loc] content failed"; return 1; }
    is_valid_url "$loc" || { err "[$loc] is not a valid link"; return 1; }

    readonly ver="$loc"
    is_installed "$ver" eclipse-mem-analyzer && return 2

    loc+="&mirror_id=$mirror"
    # now need to parse link again from the download page...
    page="$(wget "$loc" -q --user-agent="$USER_AGENT" -O -)" || { err "wgetting [$loc] failed with $?"; return 1; }
    dl_url="$(grep -Poi 'If the download doesn.t start.*a href="\K.*(?=")' <<< "$page")" || { err "parsing final download link from [$loc] content failed"; return 1; }
    is_valid_url "$dl_url" || { err "[$dl_url] is not a valid download link"; return 1; }

    dir="$(extract_tarball -D "$dl_url")" || return 1
    [[ -d "$target" ]] && { exe "rm -rf -- '$target'" || return 1; }  # rm previous installation
    exe "mv -- '$dir' '$target'" || return 1
    create_link "$target/MemoryAnalyzer" "$HOME/bin/MemoryAnalyzer"

    add_to_dl_log  eclipse-mem-analyzer "$ver"
}


# lightweight profiling, both for dev & production. see https://visualvm.github.io/
install_visualvm() {  # https://github.com/oracle/visualvm
    install_from_git -D -d "$BASE_PROGS_DIR" -N visualvm  oracle/visualvm 'visualvm_[-0-9.]+\\.zip' || return 1
    create_link "$BASE_PROGS_DIR/visualvm/bin/visualvm" "$HOME/bin/visualvm"
}


# https://minikube.sigs.k8s.io/docs/reference/drivers/none/
_setup_minikube() {  # TODO: unfinished
    true
    #exe 'sudo minikube config set vm-driver none'  # make 'none' the default driver:
    #exe 'minikube config set memory 4096'  # set default allocated memory (default is 2g i believe, see https://minikube.sigs.k8s.io/docs/start/linux/)
}


# https://github.com/kubernetes/minikube
# - alternatives:
#  - [podman kube play] takes k8s yml mainfest and runs it on podman w/o needing k8s; merely k8s emulation, but good for local testing
install_minikube() {  # https://minikube.sigs.k8s.io/docs/start/
    # from github releases...:
    #install_from_git  kubernetes/minikube  'minikube_[-0-9.]+.*_amd64.deb'
    install_bin_from_git -N minikube kubernetes/minikube  'minikube-linux-amd64'

    # ...or from k8s page:  (https://minikube.sigs.k8s.io/docs/start/):
    #install_from_url  minikube  "https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb"

    command -v minikube >/dev/null && _setup_minikube
}


# found as apt fd-find package, but executable is named fdfind not fd!
install_fd() {  # https://github.com/sharkdp/fd
    #install_from_git sharkdp/fd 'fd_[-0-9.]+_amd64.deb'
    install_bin_from_git -N fd sharkdp/fd  'x86_64-unknown-linux-gnu.tar.gz'
}


# json diff
install_jd() {  # https://github.com/josephburnett/jd
    install_bin_from_git -N jd josephburnett/jd  amd64-linux
}


# see also https://github.com/eth-p/bat-extras/blob/master/README.md#installation
# TODO: look into bat extras (like manpages)
install_bat() {  # https://github.com/sharkdp/bat
    #install_from_git sharkdp/bat 'bat_[-0-9.]+_amd64.deb'
    install_bin_from_git -N bat sharkdp/bat 'x86_64-unknown-linux-gnu.tar.gz'
}


# CLI search and replace
install_sad() {  # https://github.com/ms-jpq/sad
    #install_from_git ms-jpq/sad 'x86_64-unknown-linux-gnu.deb'
    install_bin_from_git -N sad ms-jpq/sad 'x86_64-unknown-linux-gnu.zip'
}


# terminal image viewer
install_viu() {  # https://github.com/atanunq/viu
    install_bin_from_git -N viu atanunq/viu 'x86_64-unknown-linux-musl'
}


# render markdown in CLI
install_glow() { # https://github.com/charmbracelet/glow
    #install_from_git  charmbracelet/glow '_amd64.deb'
    install_bin_from_git -N glow charmbracelet/glow '_Linux_x86_64.tar.gz'
}


install_btop() {  # https://github.com/aristocratos/btop
    install_bin_from_git -N btop aristocratos/btop  'btop-x86_64-linux-musl.tbz'
}


# alterantives:
#  - plandex
#  - https://github.com/block/goose
#  - https://github.com/cline/cline
#  - https://github.com/All-Hands-AI/OpenHands
#  - https://github.com/zed-industries/zed ?
#       - comes w/ its own editor
#
# chat-based pair-programming. as opposed to plandex which has git-like CLI with various stateful commands.
# plandex itself is more stateful - it accumulates changes to its own git repo you
# have to explicitly 'apply' to your code.
#
# https://aider.chat/docs/install.html#install-with-pipx
#   - !! take note of supported py version !!
# post-install steps: https://aider.chat/docs/install/optional.html
#   - e.g. nvim plugin: https://github.com/joshuavial/aider.nvim
install_aider() {
    py_install aider-chat --python python3.12

    # install zsh completion:
    install_from_url -A -d "$ZSH_COMPLETIONS" -O root:root -P 644 \
        _aider 'https://raw.githubusercontent.com/hmgle/aider-zsh-complete/refs/heads/main/_aider'
}


# desktop GUI for aider
install_aider_desk() {  # https://github.com/hotovo/aider-desk
    #install_from_git  hotovo/aider-desk '_amd64.deb'
    install_bin_from_git -N aider-desk hotovo/aider-desk .AppImage
}


# plandex CLI
# installation logic from https://raw.githubusercontent.com/plandex-ai/plandex/main/app/cli/install.sh
install_plandex() {
    local VERSION RELEASES_URL ENCODED_TAG url

    VERSION="$(curl -sLf -A "$USER_AGENT" -- https://plandex.ai/v2/cli-version.txt)" || return 1

    RELEASES_URL="https://github.com/plandex-ai/plandex/releases/download"
    ENCODED_TAG="cli%2Fv${VERSION}"
    url="${RELEASES_URL}/${ENCODED_TAG}/plandex_${VERSION}_linux_amd64.tar.gz"

    install_from_url plandex "$url" || return 1
}


# execute commands on PC - i.e. natural language interface for computers
# https://github.com/OpenInterpreter/open-interpreter
# https://docs.openinterpreter.com/getting-started/setup
#
# TODO: install fails
#
# alternative:
# - https://github.com/gptme/gptme
install_open_interpreter() {
    py_install open-interpreter
}


# see also:
# - https://github.com/simonw/llm
# - https://github.com/charmbracelet/mods
# - https://github.com/TheR1D/shell_gpt
install_aichat() {  # https://github.com/sigoden/aichat
    local shell="$BASE_PROGS_DIR/aichat-shell-scripts/"  # trailing slash is important; note this path is also referenced in bash/zsh rc!

    install_bin_from_git -N aichat sigoden/aichat 'x86_64-unknown-linux-musl.tar.gz'

    # install shell completions:
    clone_repo_subdir  sigoden aichat "scripts" "$shell"
    #exe "sudo cp -- '${shell}completions/aichat.zsh' $ZSH_COMPLETIONS/_aichat"
    create_link -s "${shell}completions/aichat.zsh" "$ZSH_COMPLETIONS/_aichat"
    create_link "${shell}completions/aichat.bash" "$BASH_COMPLETIONS/aichat"

    # alternatively, if we didn't need also the integration components, we
    # could directly install the completion files:
    #install_from_url -A -d "$ZSH_COMPLETIONS" -O root:root -P 644 \
        #_aichat 'https://raw.githubusercontent.com/sigoden/aichat/refs/heads/main/scripts/completions/aichat.zsh'
    #install_from_url -A -d "$BASH_COMPLETIONS" aichat \
        #'https://raw.githubusercontent.com/sigoden/aichat/refs/heads/main/scripts/completions/aichat.bash'
}


# rust replacement for ps
# also avail in apt
# read https://github.com/dalance/procs#usage
#
# examples:
# $ procs --watch --sortd cpu
install_procs() {  # https://github.com/dalance/procs
    install_bin_from_git -N procs dalance/procs  'x86_64-linux.zip'
}


# modern ls replacement written in rust
# https://github.com/eza-community/eza/blob/main/INSTALL.md#debian-and-ubuntu
#
# alternatives:
# - https://github.com/lsd-rs/lsd
install_eza() {  # https://github.com/eza-community/eza
    install_bin_from_git -N eza eza-community/eza 'eza_x86_64-unknown-linux-gnu.tar.gz'
}


# TODO: consider https://github.com/gitui-org/gitui  instead; seems to be faster?
install_lazygit() {  # https://github.com/jesseduffield/lazygit
    install_bin_from_git -N lazygit jesseduffield/lazygit '_linux_x86_64.tar.gz'
}


install_lazydocker() {  # https://github.com/jesseduffield/lazydocker
    install_bin_from_git -N lazydocker jesseduffield/lazydocker '_Linux_x86_64.tar.gz'
}


# docker image layer analyzer tool
install_dive() {  # https://github.com/wagoodman/dive
    #install_from_git  wagoodman/dive '_linux_amd64.deb'
    install_bin_from_git -N dive wagoodman/dive '_linux_amd64.tar.gz'
}


# similar to nvim's telescope; comes w/ shell binding; e.g. ctrl+t can complete
# being context-aware, e.g. completing for dirs/files/git repos etc
install_television() {  # https://github.com/alexpasmantier/television
    #install_from_git  alexpasmantier/television 'x86_64-unknown-linux-gnu.deb'
    install_bin_from_git -N tv  alexpasmantier/television 'x86_64-unknown-linux-gnu.tar.gz'
}


# alternatives:
# - https://github.com/GuillaumeGomez/systemd-manager
install_systemd_manager_tui() {  # https://github.com/matheus-git/systemd-manager-tui
    #install_from_git  matheus-git/systemd-manager-tui '_amd64.deb'
    install_bin_from_git -N systemd-manager-tui  matheus-git/systemd-manager-tui 'systemd-manager-tui'
}


# fzf-alternative, some tools use it as a dep
# last commit sept '23
install_peco() {  # https://github.com/peco/peco#installation
    install_bin_from_git -N peco peco/peco '_linux_amd64.tar.gz'
}


# pretty git diff pager, similar to diff-so-fancy
# note: alternative would be diff-so-fancy (dsf)
#
# https://dandavison.github.io/delta/installation.html
install_delta() {  # https://github.com/dandavison/delta
    #install_from_git  dandavison/delta  'git-delta_.*_amd64.deb'
    install_bin_from_git -N delta dandavison/delta  'x86_64-unknown-linux-gnu.tar.gz'
}


# ncdu-like FS usage viewer, in rust (name is 'du + rust')
install_dust() {  # https://github.com/bootandy/dust
    #install_from_git  bootandy/dust  '_amd64.deb'
    install_bin_from_git -N dust  bootandy/dust 'x86_64-unknown-linux-gnu.tar.gz'
}


# CLI bandwidth utilization tool
install_bandwhich() {  # https://github.com/imsnif/bandwhich
    install_bin_from_git -N bandwhich  imsnif/bandwhich 'x86_64-unknown-linux-gnu.tar.gz'
}


# sampling disk usage profiler for btrfs, ie ncdu for btrfs
# see also:
# - https://github.com/kimono-koans/httm
#   - can be used to take snapshots of given data using inotifywait: https://kimono-koans.github.io/inotifywait/
#   - for continuous snapshots however zfs/btrfs are still the wrong tool, you'd need something like NILFS
install_btdu() {  # https://github.com/CyberShadow/btdu
    install_bin_from_git -N btdu  CyberShadow/btdu 'btdu-static-x86_64'
}


# https://asdf-vm.com/guide/getting-started.html
# node (and others) version manager
# alternatives:
#   - https://github.com/Schniz/fnm (nodejs)
#   - https://github.com/jdx/mise
install_asdf() {
    ensure_d "$ASDF_DIR" || return 1
    install_bin_from_git -N asdf asdf-vm/asdf '-linux-amd64.tar.gz'

    command -v asdf >/dev/null 2>&1 || { err 'asdf not on PATH??'; return 1; }  # sanity

    # asdf plugins:
    if ! [[ -d "$ASDF_DATA_DIR/plugins/nodejs" ]]; then
        asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git || err "asdf [nodejs] plugin addition failed w/ $?"
    fi

    asdf plugin update --all
}


# https://github.com/jdx/mise
# https://mise.jdx.dev/installing-mise.html#github-releases
#
# plugins org: https://github.com/mise-plugins
# available tools: https://mise.jdx.dev/registry.html
install_mise() {
    install_bin_from_git -N mise jdx/mise '-linux-x64' || return
    command -v mise >/dev/null 2>&1 || { err '[mise] not on PATH?'; return 1; }  # sanity

    [[ "$MODE" -eq 1 ]] && eval "$(mise activate bash --shims)"  # use shims to load dev tools

    # set up shell autocompletion: https://mise.jdx.dev/installing-mise.html#autocompletion
    exe 'mise use --global usage'
    exe "mise completion bash --include-bash-completion-lib | tee $BASH_COMPLETIONS/mise > /dev/null"
    exe "mise completion zsh | sudo tee $ZSH_COMPLETIONS/_mise > /dev/null"
}


install_webdev() {
    is_server && { report "we're server, skipping webdev env installation."; return; }

    install_mise
    exe 'mise install'  # install the globally-defined tools (and local, if pwd has mise.toml)

    # make sure the constant link to latest node exec ($NODE_LOC) is set up (normally managed by .bashrc, but might not have been created, as this is install_sys).
    # eg some nvim plugin(s) might reference $NODE_LOC
    #   - (commented out as mise provides constant tool shim)
    #if [[ -n "$NODE_LOC" && ! -x "$NODE_LOC" ]]; then
        #local _latest_node_ver
        #_latest_node_ver="$(find "$ASDF_DATA_DIR/installs/nodejs/" -maxdepth 1 -mindepth 1 -type d | sort -n | tail -n 1)/bin/node"
        #[[ -x "$_latest_node_ver" ]] && exe "ln -sf -- '$_latest_node_ver' '$NODE_LOC'"
    #fi

    # update npm:
    if command -v npm >/dev/null 2>&1; then
        exe "$NPM_PRFX npm install npm@latest -g" && sleep 0.1
        # NPM tab-completion; instruction from https://docs.npmjs.com/cli-commands/completion.html
        exe "npm completion | tee $BASH_COMPLETIONS/npm > /dev/null"

        # install npm modules:  # TODO review what we want to install
        # note nwb (zero-config development setup) is dead - use vite instead: https://github.com/vitejs/vite
        #exe "$NPM_PRFX npm install -g \
            #typescript \
        #"
    fi

    # install ruby modules:          # sass: http://sass-lang.com/install
    # TODO sass deprecated, use https://github.com/sass/dart-sass instead; note there's also sassc (also avail in apk)
    #rb_install sass

    # install yarn:  https://yarnpkg.com/getting-started/install
    exe "corepack enable"  # note corepack is included w/ node, but is currently opt-in, hence 'enable'
    exe "corepack prepare yarn@stable --activate"
}

build_and_install_synergy_TODO_container_edition() {

    prepare_build_container || { err "preparation of build container [$BUILD_DOCK] failed"; return 1; }
    bc_install \
        build-essential \
        qtcreator \
        qtbase5-dev \
        qttools5-dev
        cmake \
        xorg-dev \
        libssl-dev \
        libx11-dev \
        libsodium-dev \
        libgl1-mesa-glx \
        libegl1-mesa \
        libcurl4-openssl-dev \
        libavahi-compat-libdnssd-dev \
        qtdeclarative5-dev \
        libqt5svg5-dev \
        libsystemd-dev || return 1

    bc_exe 'git clone -j8 https://github.com/symless/synergy-core.git /tmp/syn || exit 1
            pushd /tmp/syn || exit 1
            git checkout v2-dev || exit 1
            export BOOST_ROOT="/home/$USER/boost"

            mkdir build || exit 1
            pushd build || exit 1
            cmake .. || exit 1
            make -j8 || exit 1
            #checkinstall -D --default --fstrans=yes --pkgname=keepassxc --pkgversion=0.0.1 --install=no --pakdir=/out || exit 1

            #popd
            #rm -rf /tmp/syn || exit 1'
}


# building instructions from https://copyq.readthedocs.io/en/latest/build-source-code.html
build_copyq() {
    local tmpdir repo ver

    repo='https://github.com/hluk/CopyQ.git'
    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" copyq && return 2

    report "installing copyq build dependencies..."
    install_block '
        cmake
        extra-cmake-modules
        libkf5notifications-dev
        libqt5svg5
        libqt5svg5-dev
        libqt5waylandclient5-dev
        libqt5x11extras5-dev
        libwayland-dev
        libxfixes-dev
        libxtst-dev
        qtbase5-private-dev
        qtdeclarative5-dev
        qttools5-dev
        qttools5-dev-tools
        qtwayland5
        qtwayland5-dev-tools
    ' || { err 'failed to install build deps. abort.'; return 1; }

    tmpdir="$TMP_DIR/copyq-build-${RANDOM}"
    exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
    report "building copyq"
    exe "pushd $tmpdir" || return 1
    exe 'cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .' || { err; popd; return 1; }
    exe "make" || { err; popd; return 1; }

    create_deb_install_and_store copyq || { popd; return 1; }

    # put package on hold so they don't get overridden by apt-upgrade:
    exe 'sudo apt-mark hold  copyq'

    exe "popd"
    exe "sudo rm -rf -- $tmpdir"

    add_to_dl_log  copyq "$ver"

    return 0
}


# custom logic used by lesspipe(.sh) to extend its logic
install_lessfilter() {
    install_from_url -d "$HOME" .lessfilter 'https://raw.githubusercontent.com/Freed-Wu/Freed-Wu/refs/heads/main/.lessfilter'
}


# https://github.com/wofr06/lesspipe/blob/lesspipe/INSTALL
install_lesspipe() {
    local tmpdir repo ver

    repo='https://github.com/wofr06/lesspipe.git'
    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" lesspipe && return 2

    tmpdir="$TMP_DIR/lesspipe-build-${RANDOM}"
    exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
    exe "sudo install -C -m754 --group=$USER --target-directory=/usr/local/bin ${tmpdir}/{archive_color,lesspipe.sh}" || return 1

    exe "sudo rm -rf -- $tmpdir"
    add_to_dl_log  lesspipe "$ver"

    return 0
}


# https://github.com/wofr06/lesspipe/blob/lesspipe/INSTALL
build_lesspipe() {
    local tmpdir repo ver

    repo='https://github.com/wofr06/lesspipe.git'
    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" lesspipe && return 2

    tmpdir="$TMP_DIR/lesspipe-build-${RANDOM}/build"
    exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
    exe "pushd $tmpdir" || return 1

    report "building lesspipe..."
    exe './configure' || { err; popd; return 1; }
    exe make || { err; popd; return 1; }
    create_deb_install_and_store lesspipe || { popd; return 1; }

    # in '25 doesn't work, configure step doesn't recognize any of the opts, e.g. [Unknown option: build] {
    #build_deb  lesspipe  || { err "build_deb() for lesspipe failed"; popd; return 1; }
    #exe 'sudo dpkg -i ../lesspipe_*.deb' || { err "installing lesspipe failed"; popd; return 1; }
    # }

    exe popd
    exe "sudo rm -rf -- $tmpdir"

    add_to_dl_log  lesspipe "$ver"

    return 0
}


# https://github.com/UltimateHackingKeyboard/agent
install_uhk_agent() {
    install_bin_from_git -N agent UltimateHackingKeyboard/agent linux-x86_64.AppImage
}


# https://github.com/rvaiya/keyd
# https://github.com/rvaiya/keyd#from-source
#
# alternatives:
#  - https://github.com/jtroo/kanata
#    - its readme lists bunch of other alternatives
#  - https://github.com/kmonad/kmonad
#
#  For both keyd & kanata config examples, see https://github.com/argenkiwi/kenkyo/
setup_keyd() {
    local conf_src conf_target xcomp

    conf_src="$COMMON_DOTFILES/backups/keyd.conf"
    conf_target='/etc/keyd/default.conf'
    xcomp='/usr/share/keyd/keyd.compose'

    if [[ -s "$conf_src" ]]; then
        create_link    "$xcomp" "$HOME/.XCompose"
        create_link -s "$xcomp" '/root/.XCompose'
    fi

    if [[ -s "$xcomp" ]]; then
        exe "sudo install -m644 -CT '$conf_src' '$conf_target'" || { err "installing [$conf_src] failed w/ $?"; return 1; }
    fi

    return 0
}


# https://github.com/jtroo/kanata
#    - its readme lists bunch of other alternatives
#
# for quick debug, run as  $ sudo -u kanata kanata --cfg /path/to/conf.kbd
install_kanata() {
    local conf_src conf_target

    conf_src="$COMMON_DOTFILES/backups/kanata.kbd"
    conf_target='/etc/kanata'  # note this path is referenced in relevant systemd service file

    # note group & user are also referenced in relevant systemd & udev files
    add_group uinput
    add_user  kanata  'input,uinput'

    if [[ -s "$conf_src" ]]; then
        exe "sudo install -m644 -CD '$conf_src' '$conf_target'" || { err "installing [$conf_src] failed w/ $?"; return 1; }
    fi

    install_bin_from_git -N kanata -O root:kanata -P 754  jtroo/kanata 'kanata'
}


# https://github.com/rockowitz/ddcutil
# https://www.ddcutil.com/building/
#
# pre-built binaries avail @ https://www.ddcutil.com/install/#prebuilt-packages-maintained-by-the-ddcutil-project
# also avail in apk
build_ddcutil() {
    local dir group deps

    dir="$(fetch_extract_tarball_from_git -T  rockowitz/ddcutil)" || return 1
    exe "pushd $dir" || return 1

    #report "installing ddcutil build dependencies..."
    #install_block '
        #i2c-tools
        #libglib2.0-0
        #libgudev-1.0-0
        #libusb-1.0-0
        #libudev1
        #libdrm2
        #libjansson4
        #libxrandr2
        #hwdata
        #libc6-dev
        #libglib2.0-dev
        #libusb-1.0-0-dev
        #libudev-dev
        #libxrandr-dev
        #libdrm-dev
        #libjansson-dev
    #' || { err 'failed to install build deps. abort.'; return 1; }
    #exe 'autoreconf --force --install' || { err; popd; return 1; }
    #exe './configure' || { err; popd; return 1; }
    #exe make || { err; popd; return 1; }
    #create_deb_install_and_store  ddcutil  # TODO: note still using checkinstall

    deps=(
        i2c-tools
        libglib2.0-0
        libgudev-1.0-0
        libusb-1.0-0
        libudev1
        libdrm2
        libjansson4
        libxrandr2
        hwdata
        libc6-dev
        libglib2.0-dev
        libusb-1.0-0-dev
        libudev-dev
        libxrandr-dev
        libdrm-dev
        libjansson-dev
    )
    build_deb  ddcutil "${deps[@]}" || { err "build_deb() for ddcutil failed"; popd; return 1; }
    exe 'sudo dpkg -i ../ddcutil_*.deb' || { err "installing ddcutil failed"; popd; return 1; }

    # put package on hold so they don't get overridden by apt-upgrade:
    exe 'sudo apt-mark hold  ddcutil'

    exe "popd"
    exe "sudo rm -rf -- '$dir'"
}


# trying out checkinstall replacement, based on fpm (https://fpm.readthedocs.io)
# TODO wip
create_deb_install_and_store2() {
    exe 'sudo gem install fpm'
#######################
    local opt cmd ver pkg_name exit_sig OPTIND

    while getopts 'C:' opt; do
        case "$opt" in
            C) readonly cmd="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    pkg_name="$1"
    ver="${2:-0.0.1}"  # OPTIONAL

    check_progs_installed fpm || return 1
    report "creating [$pkg_name] .deb and installing with fpm..."

    fpm -s dir -t deb -n name -a amd64 -v 2.0.0 .
}

# runs checkinstall in current working dir, and copies the created
# .deb file to $BASE_BUILDS_DIR/
create_deb_install_and_store() {
    local opt cmd ver pkg_name exit_sig OPTIND

    while getopts 'C:' opt; do
        case "$opt" in
            C) readonly cmd="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    pkg_name="$1"
    ver="${2:-0.0.1}"  # OPTIONAL

    check_progs_installed checkinstall || return 1
    report "creating [$pkg_name] .deb and installing with checkinstall..."

    # note --fstrans=no is because of checkinstall bug; see  https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=717778
    exe "sudo checkinstall \
        -D --default --fstrans=no \
        --pkgname=$pkg_name --pkgversion=$ver \
        --pakdir=$BASE_BUILDS_DIR $cmd"
    exit_sig="$?"

    if [[ "$exit_sig" -ne 0 ]]; then
        err "checkinstall run for [$pkg_name] failed w/ [$exit_sig]. abort."
        return 1
    fi

    return 0
}


# https://github.com/JMoerman/Go-For-It
build_goforit() {
    # https://flathub.org/apps/de.manuel_kehl.go-for-it
    fp_install -n goforit  'de.manuel_kehl.go-for-it'
    return

    # build logic:
    local repo tmpdir ver

    repo='https://github.com/JMoerman/Go-For-It'

    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" goforit && return 2

    report "installing goforit build dependencies..."
    install_block '
        valac
        cmake
        gettext
        libgtk-3-dev
        libglib2.0-dev
        libcanberra-dev
        libpeas-dev
        libayatana-appindicator3-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    tmpdir="$TMP_DIR/goforit-build-${RANDOM}"
    exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
    report "building goforit..."
    exe "mkdir $tmpdir/build"
    exe "pushd $tmpdir/build" || return 1
    exe 'cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..' || { err; popd; return 1; }
    exe make || { err; popd; return 1; }

    create_deb_install_and_store  goforit || { popd; return 1; }

    exe "popd"
    exe "sudo rm -rf -- '$tmpdir'"

    add_to_dl_log  goforit "$ver"

    return 0
}


# TODO: not used atm; still not sure what runtime deps are required on the host
# instructions from  https://github.com/keepassxreboot/keepassxc/wiki/Set-up-Build-Environment-on-Linux
#                    https://github.com/keepassxreboot/keepassxc/wiki/Building-KeePassXC
# runtime dependencies from https://keepassxc.org/project
build_and_install_keepassxc_TODO_container_edition() {

    bc_install libxi-dev libxtst-dev qtbase5-dev \
            libqt5x11extras5-dev qttools5-dev qttools5-dev-tools \
            libgcrypt20-dev zlib1g-dev libyubikey-dev libykpers-1-dev || return 1

    bc_exe 'git clone -j8 https://github.com/keepassxreboot/keepassxc.git /tmp/kxc || exit 1
            pushd /tmp/kxc || exit 1

            mkdir build
            cd build
            cmake -DWITH_XC_AUTOTYPE=ON -DWITH_XC_HTTP=ON -DWITH_XC_YUBIKEY=ON' \
            '    -DCMAKE_BUILD_TYPE=Release .. || exit 1
            make -j8 || exit 1
            checkinstall -D --default --fstrans=yes --pkgname=keepassxc --pkgversion=0.0.1 --install=no --pakdir=/out || exit 1

            popd
            rm -rf /tmp/kxc || exit 1'
}


# downloads official AppImage and installs it.
#                    https://github.com/keepassxreboot/keepassxc/wiki/Set-up-Build-Environment-on-Linux
#                    https://github.com/keepassxreboot/keepassxc/wiki/Building-KeePassXC
#                    https://keepassxc.org/download
# to programmatically interface w/ keepass using the browser interface/protocol, see
#   - https://github.com/hargoniX/keepassxc-proxy-client
#   - https://github.com/hrehfeld/python-keepassxc-browser
install_keepassxc() {
    install_bin_from_git -N keepassxc keepassxreboot/keepassxc 'x86_64.AppImage'
}


# https://keybase.io/docs/the_app/install_linux
install_keybase() {
    exe 'sudo touch /etc/default/keybase' || return 1  # this disables keybase adding pkg repository
    install_from_url keybase 'https://prerelease.keybase.io/keybase_amd64.deb'
}


# https://github.com/Raymo111/i3lock-color
# this is a depency for i3lock-fancy.
#
# for build hints, see https://github.com/Raymo111/i3lock-color/blob/master/build.sh
build_i3lock() {
    local tmpdir repo ver deps

    repo='https://github.com/Raymo111/i3lock-color'
    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" i3lock-color && return 2

    deps=(autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev libgif-dev)

    # clone the repository
    tmpdir="$TMP_DIR/i3lock-build-${RANDOM}"
    exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
    # create tag so a non-debug version is built:
    exe "git -C '$tmpdir' tag -f 'git-$(git -C '$tmpdir' rev-parse --short HEAD)'" || return 1

    report 'building i3lock...'
    mkpushd "$tmpdir/build" || return 1  # as per project's build.sh, build needs to be done from a subdir
    build_deb  i3lock-color "${deps[@]}" || { err "build_deb() for i3lock-color failed"; popd; return 1; }
    exe 'sudo dpkg -i ../i3lock-color_*.deb' || { err "installing i3lock-color failed"; popd; return 1; }

    # old, checkinstall-compliant logic:
    ## compile & install:
    #exe 'autoreconf --install' || return 1
    #exe './configure' || return 1
    #exe 'make' || return 1
    #create_deb_install_and_store i3lock

    exe popd
    exe "sudo rm -rf -- '$tmpdir'"

    add_to_dl_log  i3lock-color "$ver"

    return 0
}


# TODO: available on apt, at least for sid
build_i3lock_fancy() {
    local repo tmpdir ver

    repo='https://github.com/meskarune/i3lock-fancy'

    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" i3lock-fancy && return 2

    # clone the repository
    tmpdir="$TMP_DIR/i3lock-fancy-build-${RANDOM}/build"
    exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
    exe "pushd $tmpdir" || return 1


    #build_deb -D '--parallel' i3lock-fancy || err "build_deb() for i3lock-fancy failed"
    #echo "got these: $(ls -lat ../*.deb)"
    #exit
    #exe 'sudo dpkg -i ../i3lock-fancy_*.deb'

    # old, checkinstall-compliant logic:
    ## compile & install:
    #exe 'autoreconf --install' || return 1
    #exe './configure' || return 1
    #exe 'make' || return 1

    # TODO: note this guy will already install it! the makefile of fancy is odd...
    report "building i3lock-fancy..."

    # note this fails as-is, see https://github.com/meskarune/i3lock-fancy/issues/199
    # as a workaround add line [override_dh_auto_build:] to debian/rules
    build_deb  i3lock-fancy || { err "build_deb() for i3lock-fancy failed"; popd; return 1; }
    exe 'sudo dpkg -i ../i3lock-fancy_*.deb' || { err "installing i3lock-fancy failed"; popd; return 1; }

    #create_deb_install_and_store i3lock-fancy || { popd; return 1; }

    # put package on hold so they don't get overridden by apt-upgrade:
    exe 'sudo apt-mark hold  i3lock-fancy'

    exe "popd"
    exe "sudo rm -rf -- '$tmpdir'"

    add_to_dl_log  i3lock-fancy "$ver"

    return 0
}


# TODO: review, needed?
install_betterlockscreen() {  # https://github.com/betterlockscreen/betterlockscreen
    # note 'main' or 'next' branch:
    install_from_url  betterlockscreen 'https://raw.githubusercontent.com/betterlockscreen/betterlockscreen/next/betterlockscreen'
}


# provides drop-in replacement for xbacklight
# https://gitlab.com/wavexx/acpilight
#
# alternatives:
# - https://gitlab.com/cameronnemo/brillo  - untested, but looks to be working on multiple devices at same time!
# - https://github.com/haikarainen/light  - project is EOL
# - https://github.com/Hummer12007/brightnessctl
#
# TODO need to install  ddcci-dkms  pkg and load ddcci module to get external display evices listed under /sys
# TODO: last commit Oct '20
install_acpilight() {
    true # TODO WIP
}


# https://gitlab.com/cameronnemo/brillo
#
# note ddcci-dkms is required to change external monitor brightness; never managed
# to get it to work, still using ddcutil for externals.
install_brillo() {
    local repo tmpdir ver

    repo="https://gitlab.com/cameronnemo/brillo.git"

    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" brillo && return 2

    # clone the repository
    tmpdir="$TMP_DIR/brillo-build-${RANDOM}/build"
    exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
    exe "pushd $tmpdir" || return 1

    build_deb  brillo go-md2man || { err "build_deb for brillo failed"; popd; return 1; }
    exe 'sudo dpkg -i ../brillo_*.deb'

    exe "popd"
    exe "sudo rm -rf -- '$tmpdir'"
    add_to_dl_log  brillo "$ver"

    add_to_group  video
}


# https://github.com/haimgel/display-switch
# switches display output when USB device (eg kbd switch) is connected/disconnected
# similar solution without display_switch: https://www.reddit.com/r/linux/comments/102bwkc/automatically_switching_screen_input_when/
#
# Note needs to be installed into /usr/local/bin, as that's what its systemd unit references
install_display_switch() {
    local group

    _build_install() {
        local repo tmpdir ver
        repo='git@github.com:haimgel/display-switch.git'

        ver="$(get_git_sha "$repo")" || return 1
        is_installed "$ver" display-switch && return 2

        tmpdir="$TMP_DIR/display-switch-${RANDOM}"
        exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
        exe "pushd $tmpdir" || return 1

        exe 'cargo build --release' || return 1  # should produce binary at target/release/display_switch
        exe "sudo install -m754 -C --group=$USER 'target/release/display_switch' '/usr/local/bin'" || return 1

        exe popd
        exe "sudo rm -rf -- '$tmpdir'"
        add_to_dl_log  display-switch "$ver"
    }

    #_build_install
    install_bin_from_git -n display_switch  haimgel/display-switch '-linux-amd64.zip'

    # following from https://github.com/haimgel/display-switch#linux-2
    # note the associated udev rule is in one of castles' udev/ dir
    group=i2c
    add_group "$group"
    add_to_group "$group"
}


# https://i3wm.org/docs/hacking-howto.html
# see also https://github.com/maestrogerardo/i3-gaps-deb for debian pkg building logic
build_i3() {
    local tmpdir repo ver

    _apply_patches() {
        local f
        f="$TMP_DIR/i3-patch-${RANDOM}.patch"

        curl --fail -o "$f" 'https://raw.githubusercontent.com/laur89/i3-extras/master/i3-v-h-split-label-swap.patch' || { err "i3-v-h-split-label-swap-patch download failed"; return 1; }
        report "patching v-h split label..."
        patch -p1 < "$f" || { err "applying i3-v-h-split-label-swap-patch failed"; return 1; }

        curl --fail -o "$f" 'https://raw.githubusercontent.com/maestrogerardo/i3-gaps-deb/master/patches/0001-debian-Disable-sanitizers.patch' || { err "disable-sanitizers-patch download failed"; return 1; }
        report "patching removal of debian sanitizers..."
        patch --forward -r - -p1 < "$f" || { err "applying disable-sanitizers.patch failed"; return 1; }
    }

    # from https://github.com/maestrogerardo/i3-gaps-deb/blob/master/i3-gaps-deb
    _fix_rules() {
        report "Fix i3 debian/rules file..."
        cat <<EOF >>debian/rules
override_dh_install:
override_dh_installdocs:
override_dh_installman:
	dh_install -O--parallel
EOF
    }

    readonly repo='https://github.com/i3/i3'

    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" i3 && return 2

    # clone the repository
    tmpdir="$TMP_DIR/i3-build-${RANDOM}/build"
    exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
    exe "pushd $tmpdir" || return 1

    _apply_patches  # TODO: should we bail on error?
    _fix_rules

    #report "installing i3 build dependencies..."
    #install_block '
        #gcc
        #make
        #dh-autoreconf
        #libxcb-keysyms1-dev
        #libpango1.0-dev
        #libxcb-util0-dev
        #xcb
        #libxcb1-dev
        #libxcb-icccm4-dev
        #libyajl-dev
        #libev-dev
        #libxcb-xkb-dev
        #libxcb-cursor-dev
        #libxkbcommon-dev
        #libxcb-xinerama0-dev
        #libxkbcommon-x11-dev
        #libstartup-notification0-dev
        #libxcb-randr0-dev
        #libxcb-xrm0
        #libxcb-xrm-dev
        #libxcb-shape0-dev
    #' || { err 'failed to install build deps. abort.'; return 1; }

    # alternatively, install build-deps based on what's in debian/control; this
    # command packages up build deps listed under debian/; note -i flag installs it,
    # -r removes the built .deb.
    #
    # - note mk-build-deps needs equivs pkg; mk-build-deps itself is provided by devscripts pkg;
    # - alternative to mk-build-deps, could also do $ sudo apt-get -y build-dep i3-wm
    #sudo mk-build-deps \
            #-t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -qqy' \
            #-i -r debian/control || { err "automatic build-dep resolver for i3 failed w/ [$?]"; popd; return 1; }

    report 'building i3...'

    build_deb || { err 'build_deb() for i3 failed'; popd; return 1; }
    exe 'sudo dpkg -i ../i3-wm_*.deb'
    exe 'sudo dpkg -i ../i3_*.deb'

    # put package on hold so they don't get overridden by apt-upgrade:
    exe 'sudo apt-mark hold  i3 i3-wm'


    # TODO: deprecated, check-install based way:
    ## compile & install
    #exe 'autoreconf --force --install' || return 1
    #exe 'rm -rf build/' || return 1
    #exe 'mkdir -p build && pushd build/' || return 1

    ## Disabling sanitizers is important for release versions!
    ## The prefix and sysconfdir are, obviously, dependent on the distribution.
    #exe '../configure --prefix=/usr/local --sysconfdir=/etc --disable-sanitizers' || return 1
    #exe 'make'
    #create_deb_install_and_store i3
    #exe "popd"

    # --------------------------
    # install required perl modules (eg for i3-save-tree):
    #exe "pushd AnyEvent-I3" || return 1
    # TODO: libanyevent-i3-perl from repo?
    #build_deb i3-anyevent || err "build_deb() for i3-anyevent failed"
    install_block 'libanyevent-i3-perl' # alternative to building it ourselves

    # TODO: deprecated, check-install based way:
    #exe 'perl Makefile.PL'
    #exe 'make'
    #create_deb_install_and_store i3-anyevent
    #install_block "libjson-any-perl"
    #exe "popd"
    # --------------------------

    exe popd
    exe "sudo rm -rf -- '$tmpdir'"
    add_to_dl_log  i3 "$ver"

    return 0
}

install_i3() {
    #build_i3   # do not return, as it might return w/ 2 because of is_installed()
    install_block  i3
    install_i3_deps
    install_i3_conf
}


# pass -g opt to install from github; in that case the repo to be provided is [user/repo]
# and we can install one pkg at a time.
#
# good write-up on py dependency management as of '24: https://nielscautaerts.xyz/python-dependency-management-is-a-dumpster-fire.html
# tl;dr: use uv if pypi, or pixi if conda
#   - note uv has pipx analogue: uvx
#   - also supports PEP 723 to add dependencies to file hdr, so can run these
#     single scripts via uvx while also using deps; also supported by pipx! - https://peps.python.org/pep-0723/
py_install() {
    local opt opts OPTIND

    declare -a opts
    while getopts 'g:' opt; do
        case "$opt" in
            g) opts+=("git+ssh://git@github.com/${OPTARG}.git") ;;
            *) fail "unexpected arg passed to ${FUNCNAME}(): -$opt" ;;
        esac
    done
    shift "$((OPTIND-1))"

    opts+=("$@")
    exe "pipx install ${opts[*]}"
}


rb_install() {
    exe "gem install --user-install $*"
}


fp_install() {  # flatpak install
    local opt name ref bin remote OPTIND

    while getopts 'n:' opt; do
        case "$opt" in
            n) name="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    ref="$1"
    remote="${2:-flathub-verified}"

    name="${name:-$ref}"
    exe "flatpak install -y --noninteractive '$remote' '$ref'" || return 1

    bin="/var/lib/flatpak/exports/bin/$ref"
    [[ -s "$bin" ]] || { err "[$bin] does not exist, cannot create shortcut link for [$name]"; return 1; }  # sanity
    create_link "$bin" "$HOME/bin/$name"
}


install_i3_conf() {
    local conf
    conf="$HOME/.config/i3/config"  # conf file _to be_ generated;

    py_install update-conf.py || { err "update-conf.py install failed"; return 1; }
    update-conf.py -f "$conf" || { err "i3 config install failed w/ $?"; return 1; }
}


# TODO: also consider:
#  - https://gitlab.com/aquator/i3-scratchpad - docks/launches/toggles windows/apps at specific position on screen
#  - https://github.com/justahuman1/i3-grid
install_i3_deps() {
    local f
    f="$TMP_DIR/i3-dep-${RANDOM}"

    install_block 'python3-i3ipc' || return 1

    # i3ipc now installed as apt pkg
    #py_install i3ipc      # https://github.com/altdesktop/i3ipc-python

    # rofi-tmux (aka rft):
    py_install rofi-tmux-ng  # https://github.com/laur89/rofi-tmux-ng

    # install i3expo:
    py_install i3expo

    # install our i3 tools:
    #py_install i3-tools  # TODO: unreleased as of Jun '25 due to drone.ci's plugins/pypi image using outdated twine
    py_install -g laur89/i3-tools  # https://github.com/laur89/i3-tools

    # i3ass  # https://github.com/budlabs/i3ass/
    #clone_or_pull_repo budlabs i3ass "$BASE_PROGS_DIR"
    #create_link -c "${BASE_PROGS_DIR}/i3ass/src" "$HOME/bin/"  # <- broken, links project root dirs, not the executables said root dirs contain

    # install i3-quickterm   # https://github.com/laur89/i3-quickterm
    py_install i3-qt

    # install i3-cycle-windows   # https://github.com/DavsX/dotfiles/blob/master/bin/i3_cycle_windows
    # this script defines a 'next' window, so we could bind it to someting like super+mouse_wheel;
    #curl --fail --output "$f" 'https://raw.githubusercontent.com/DavsX/dotfiles/master/bin/i3_cycle_windows' \
            #&& exe "chmod +x -- '$f'" \
            #&& exe "mv -- '$f' $HOME/bin/i3-cycle-windows" || err "installing i3-cycle-windows failed /w $?"

    # install i3move, allowing easier floating-window movement   # https://github.com/dmbuce/i3b
    # TODO: x11!
    install_from_url  i3move 'https://raw.githubusercontent.com/DMBuce/i3b/master/bin/i3move'

    # install sway-overfocus, allowing easier window focus change/movement   # https://github.com/korreman/sway-overfocus
    install_bin_from_git -N sway-overfocus korreman/sway-overfocus '-x86_64.tar.gz'

    # TODO: consider https://github.com/infokiller/i3-workspace-groups
    # TODO: consider https://github.com/JonnyHaystack/i3-resurrect

    # create links of our own i3 scripts on $PATH:
    create_symlinks "$BASE_DATA_DIR/dev/scripts/i3" "$HOME/bin"

    exe "sudo rm -rf -- '$f'"
}


# the ./build.sh version
# https://github.com/polybar/polybar/wiki/Compiling
# https://github.com/polybar/polybar
#
# note testing might have new enough package these days: https://packages.debian.org/testing/polybar
build_polybar() {
    local dir deps

    #exe "git clone --recursive ${GIT_OPTS[*]} https://github.com/polybar/polybar.git '$dir'" || return 1
    dir="$(fetch_extract_tarball_from_git polybar/polybar 'polybar-\\d+\\.\\d+.*\\.tar\\.gz')" || return 1

    exe "pushd $dir" || return 1

    # note: clang is installed because of  https://github.com/polybar/polybar/issues/572
    # old build.sh & checkinstall method {
    #report "installing polybar build dependencies..."
    #install_block '
        #clang
        #cmake
        #cmake-data
        #pkg-config
        #python3-sphinx
        #python3-packaging
        #libuv1-dev
        #libcairo2-dev
        #libxcb1-dev
        #libxcb-util0-dev
        #libxcb-randr0-dev
        #libxcb-composite0-dev
        #python3-xcbgen
        #xcb-proto
        #libxcb-image0-dev
        #libxcb-ewmh-dev
        #libxcb-icccm4-dev

        #libxcb-xkb-dev
        #libxcb-xrm-dev
        #libxcb-cursor-dev
        #libasound2-dev
        #libpulse-dev
        #libjsoncpp-dev
        #libmpdclient-dev
        #libcurl4-openssl-dev
        #libnl-genl-3-dev
    #' || { err 'failed to install build deps. abort.'; return 1; }
    #exe "./build.sh --auto --all-features --no-install" || { popd; return 1; }
    #exe "pushd build/" || { popd; return 1; }
    #create_deb_install_and_store polybar  # TODO: note still using checkinstall
    #exe popd
    # } build_deb way: {
    # note requires removal of [override_dh_auto_configure:]  block in debian/rules:
    deps=(clang build-essential git cmake cmake-data pkg-config python3-sphinx python3-packaging libuv1-dev libcairo2-dev libxcb1-dev libxcb-util0-dev libxcb-randr0-dev libxcb-composite0-dev python3-xcbgen xcb-proto libxcb-image0-dev libxcb-ewmh-dev libxcb-icccm4-dev)
    report 'building i3lock...'
    build_deb  polybar "${deps[@]}" || { err "build_deb() for polybar failed"; popd; return 1; }
    exe 'sudo dpkg -i ../polybar_*.deb' || { err "installing polybar failed"; popd; return 1; }
    #}

    # put package on hold so they don't get overridden by apt-upgrade:
    exe 'sudo apt-mark hold  polybar'
    exe popd

    exe "sudo rm -rf -- '$dir'"
    return 0
}


# see https://wiki.debian.org/Packaging/Intro?action=show&redirect=IntroDebianPackaging
# and https://vincent.bernat.ch/en/blog/2019-pragmatic-debian-packaging
#
# https://github.com/phusion/debian-packaging-for-the-modern-developer/tree/master/tutorial-1
#
# see also pbuilder, https://wiki.debian.org/SystemBuildTools
# see also https://github.com/makedeb/makedeb
# see also https://github.com/FooBarWidget/debian-packaging-for-the-modern-developer
# see also https://github.com/aidan-gallagher/debpic
#   - short introduction @ https://www.reddit.com/r/debian/comments/1cy34sb/ive_created_a_tool_to_ease_building_debian/
build_deb() {
    local opt pkg_name configure_extra build_deps dh_extra deb OPTIND

    while getopts 'C:D:' opt; do
        case "$opt" in
            C) readonly configure_extra="$OPTARG" ;;
            #B) readonly build_deps="$OPTARG" ;;
            D) readonly dh_extra="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    pkg_name="$1"; shift
    build_deps="$(build_comma_separated_list "$@")"

    if ! [[ -d debian ]]; then
        report "no debian/ in pwd, generating scaffolding..."
        ensure_d "debian" || return 1

        # create changelog:
        echo "$pkg_name (0.0-0) UNRELEASED; urgency=medium

  * New upstream release

 -- la.packager.eu <la@packager.eu>  $(date --rfc-email)
" > debian/changelog || return 1
        # OR use dhc:  $ dch --create -v 0.0-0 --package $pkg_name

        # create control:
        echo "Source: $pkg_name
Maintainer: Laur Aliste <laur.aliste@packager.eu>
Build-Depends: ${build_deps:+$build_deps, }debhelper-compat (= 13)

Package: $pkg_name
Architecture: any
Description: custom-built $pkg_name package
" > debian/control || return 1

        # create rules:
        #printf '#!/usr/bin/make -f

#DISTRIBUTION = $(shell grep -Po "^PRETTY_NAME=.*Linux\s+\K.*(?=\")" /etc/os-release)
#VERSION = 0.0.1
#PACKAGEVERSION = $(VERSION)-0~$(DISTRIBUTION)0

#%%:
	#dh $@

#override_dh_auto_clean:
#override_dh_auto_test:
#override_dh_auto_build:
#override_dh_auto_install:
	#./configure --prefix=/usr
	#make
	#make install DESTDIR=debian/memcached

#override_dh_gencontrol:
	#dh_gencontrol -- -v$(PACKAGEVERSION)' > debian/rules || return 1
        printf '#!/usr/bin/make -f

#DISTRIBUTION = $(shell sed -n "s/^VERSION_CODENAME=//p" /etc/os-release)
#DISTRIBUTION = $(shell grep -Po "^PRETTY_NAME=.*Linux\s+\K.*(?=\\")" /etc/os-release)
DISTRIBUTION = testing
VERSION = 0.0.1
PACKAGEVERSION = $(VERSION)-0~$(DISTRIBUTION)0

%%:
	dh $@%s

override_dh_auto_test:
override_dh_auto_configure:
	dh_auto_configure -- %s --disable-sanitizers
override_dh_gencontrol:
	dh_gencontrol -- -v$(PACKAGEVERSION)' "${dh_extra:+ $dh_extra}" "$configure_extra" > debian/rules || return 1
    fi

    # - note built .deb will end up in a parent dir;
    # - the --no-clean opt is as without it the clean step will require build deps to be
    #   installed on host, see https://www.mail-archive.com/debian-bugs-dist@lists.debian.org/msg2002932.html
    exe 'sbuild --dist=testing --no-clean' || return $?

    # older, debuild way:
    # The options -uc -us will skip signing the resulting Debian source package and
    # other build artifacts. The -b option will skip creating a source package and
    # only build the (binary) *.deb packages:
    #exe 'debuild -us -uc -b' || return 1

    # install:  # can't install here, as we don't know which debs to select
    #deb="$(find ../ -mindepth 1 -maxdepth 1 -type f -name '*.deb')"
    #[[ -f "$deb" ]] || { err "couldn't find built [$pkg_name] .deb in parent dir"; return 1; }
    #exe "sudo dpkg -i '$deb'" || { err "installing built .deb [$deb] failed"; return 1; }
}


setup_nvim() {
    #nvim_post_install_configuration

    if [[ "$MODE" -eq 1 ]]; then
        exe "sudo apt-get --yes remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common"  # no vim pls
        nvim +PlugInstall +qall
    fi

    # YCM installation AFTER the first nvim launch (nvim launch pulls in ycm plugin, among others)!
    #install_YCM

    config_coc  # _instead_ of YCM

    # nvr stuff; you prolly want to install https://github.com/carlocab/tmux-nvr for tmux
    # TODO: is this still relevant? note nvim now supports --remote:  https://neovim.io/doc/user/remote.html
    py_install neovim-remote     # https://github.com/mhinz/neovim-remote

    #py_install pynvim            # https://github.com/neovim/pynvim  # ! now installed via system pkg python3-pynvim
}


# https://github.com/neovide/neovide
#
# !! note our $VISUAL env var is tied to it !!
install_neovide() {  # rust-based GUI front-end to neovim
    # alternative asset:   neovide.AppImage
    install_bin_from_git -N neovide -n neovide  neovide/neovide 'linux-x86_64.tar.gz'
}


# https://github.com/helix-editor/helix
# also available in apt repo
# see also:
# - kakoune - https://github.com/mawww/kakoune (avail on apt)
install_helix() {
    #install_bin_from_git -N hx helix-editor/helix 'x86_64.AppImage'
    #install_bin_from_git -N hx -n hx  helix-editor/helix '-x86_64-linux.tar.xz'
    install_from_git helix-editor/helix _amd64.deb
}


# NO plugin config should go here (as it's not guaranteed they've been installed by this time)
# TODO: is this fine? see https://vi.stackexchange.com/questions/46887
nvim_post_install_configuration() {
    local i nvim_confdir

    readonly nvim_confdir="$HOME/.config/nvim"

    ensure_d -s "/root/.config" || return 1
    create_link -s "$nvim_confdir" "/root/.config/"  # root should use same conf
}


# building instructions from https://github.com/Valloric/YouCompleteMe/wiki/Building-Vim-from-source
build_and_install_vim() {
    local tmpdir expected_runtimedir repo ver

    readonly expected_runtimedir='/usr/local/share/vim/vim91'  # path depends on the ./configure --prefix

    repo='https://github.com/vim/vim.git'
    ver="$(get_git_sha "$repo")" || return 1
    is_installed "$ver" vim-our-build && return 2

    # TODO: should this removal only happen in mode=1 (ie full) mode?
    report "removing already installed vim components..."
    exe "sudo apt-get --yes remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common vim-nox"

    report "installing vim build dependencies..."
    install_block '
        libncurses5-dev
        libgtk2.0-dev
        libatk1.0-dev
        libcairo2-dev
        libx11-dev
        libxpm-dev
        libxt-dev
        python3-dev
        ruby-dev
        lua5.2
        liblua5.2-dev
        libperl-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    tmpdir="$TMP_DIR/vim-build-${RANDOM}"
    exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || return 1
    exe "pushd $tmpdir" || return 1

    report "building vim..."

            # flags for py2 support (note python2 has been deprecated):
            #--enable-pythoninterp=yes \
            #--with-python-config-dir=$python_confdir \
    exe "./configure \
            --with-features=huge \
            --enable-multibyte \
            --enable-rubyinterp=yes \
            --enable-python3interp=yes \
            --with-python3-config-dir=$(python3-config --configdir) \
            --enable-perlinterp=yes \
            --enable-luainterp=yes \
            --enable-gui=gtk2 \
            --enable-cscope \
            --prefix=/usr/local \
    " || { err 'vim configure build phase failed.'; popd; return 1; }

    exe "make VIMRUNTIMEDIR=$expected_runtimedir" || { err 'vim make failed'; popd; return 1; }
    #!(make sure rutimedir is correct; at this moment 74 was)
    create_deb_install_and_store vim || { err; popd; return 1; }  # TODO: remove checkinstall

    exe "popd"
    exe "sudo rm -rf -- '$tmpdir'"
    if ! [[ -d "$expected_runtimedir" ]]; then
        err "[$expected_runtimedir] is not a dir; these match 'vim' under [$(dirname -- "$expected_runtimedir")]:"
        err "$(find "$(dirname -- "$expected_runtimedir")" -maxdepth 1 -mindepth 1 -type d -name 'vim*' -print)"
        return 1
    fi

    add_to_dl_log  vim-our-build "$ver"

    return 0
}

# note the installation bit could be replaced by nvim config:
#  let g:coc_global_extensions = ['coc-json', 'coc-git']
config_coc() {
    if [[ "$MODE" -eq 1 ]]; then
        # TODO: instead of this, maybe we should just track ~/.config/coc/extensions/package.json?; unsure if that will bring the plugins to fresh install, but possibly worth a try;
        #nvim +'CocInstall -sync  coc-snippets coc-tsserver coc-json coc-html coc-css coc-pyright coc-sh coc-clojure|qall'
        nvim +'CocInstall -sync  coc-snippets coc-tsserver coc-json coc-html coc-css coc-pyright coc-sh coc-clojure' +qall
    else
        nvim +CocUpdateSync +qall
    fi
}


# note: instructions & info here: https://github.com/ycm-core/YouCompleteMe#linux-64-bit
# note2: available in deb repo as 'ycmd'
install_YCM() {  # the quick-and-not-dirty install.py way
    local ycm_plugin_root ver

    readonly ycm_plugin_root="$HOME/.config/nvim/bundle/YouCompleteMe"

    # sanity
    if ! [[ -d "$ycm_plugin_root" ]]; then
        err "expected vim plugin YouCompleteMe to be already pulled"
        err "you're either missing (n)vim conf or haven't started vim yet (first start pulls all the plugins)"
        return 1
    fi

    exe "pushd -- $ycm_plugin_root" || return 1
    readonly ver="$(git rev-parse HEAD)"
    is_installed "$ver" YCM && { popd; return 2; }

    # install deps
    install_block '
        build-essential
        cmake
        vim-nox
        python3-dev
    '

    # install YCM
    exe -i "python3 ./install.py --all" || { popd; return 1; }
    exe "popd"

    add_to_dl_log  YCM "$ver"
}


# consider also https://github.com/whitelynx/artwiz-fonts-wl
# consider also https://github.com/slavfox/Cozette
#
# note pango 1.44+ drops FreeType support, thus losing support for traditional
# BDF/PCF bitmap fonts; eg Terminess Powerline from powerline fonts.
# consider patching yourself: https://www.reddit.com/r/archlinux/comments/f5ciqa/terminus_bitmap_font_with_powerline_symbols/fhyeuws/
#
# https://github.com/dse/bitmapfont2ttf/blob/master/bin/bitmapfont2ttf
# https://gitlab.freedesktop.org/xorg/app/fonttosfnt
#
# TODO: wayland likely doens't support the bitmap glyph notes: https://unix.stackexchange.com/questions/795108
install_fonts() {
    local dir

    report "installing fonts..."

    # TODO: many x11 fonts!
    install_block '
        fonts-noto
        fonts-noto-color-emoji
        ttf-mscorefonts-installer
        xfonts-75dpi
        xfonts-75dpi-transcoded
        xfonts-100dpi
        xfonts-100dpi-transcoded
        xfonts-mplus
        xfonts-base
        xbitmaps
        fonts-firacode
        fonts-font-awesome
    '

    # note alternative bitmap font tool to fontforge is bitsnpicas
    is_native && install_block 'fontforge gucharmap'

    # https://github.com/ryanoasis/nerd-fonts#option-7-install-script
    install_nerd_fonts() {
        local tmpdir fonts repo ver i opts

        fonts=(
            Hack
            SourceCodePro
            AnonymousPro
            Terminus:M
            Ubuntu
            UbuntuMono
            DejaVuSansMono
            DroidSansMono
            InconsolataGo
            Inconsolata
            Iosevka
        )

        repo='https://github.com/ryanoasis/nerd-fonts'
        ver="$(get_git_sha "$repo")" || return 1
        is_installed "$ver" nerd-fonts && return 2

        # clone the repository
        tmpdir="$TMP_DIR/nerd-fonts-${RANDOM}"
        exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
        exe "pushd $tmpdir" || return 1

        report "installing nerd-fonts..."
        for i in "${fonts[@]}"; do
            IFS=: read -r i opts <<< "$i"
            exe -i "./install.sh '$i'"
            [[ "$opts" == *M* ]] && exe -i "./install.sh --mono '$i'"  # mono variant needs explicit installation, see https://github.com/ryanoasis/nerd-fonts/discussions/1903#discussioncomment-13948180
        done

        exe "popd"
        exe "sudo rm -rf -- '$tmpdir'"

        add_to_dl_log  nerd-fonts "$ver"
        return 0
    }

    # https://github.com/powerline/fonts
    # note this is same as 'fonts-powerline' pkg, although at least in 2021 the package didn't work
    # TODO: unsure if it really is the same - suspect the deb pkg _only_ provides the symbols
    install_powerline_fonts() {
        local tmpdir repo ver

        repo='https://github.com/powerline/fonts'
        ver="$(get_git_sha "$repo")" || return 1
        is_installed "$ver" powerline-fonts && return 2

        tmpdir="$TMP_DIR/powerline-fonts-${RANDOM}"
        exe "git clone ${GIT_OPTS[*]} $repo '$tmpdir'" || return 1
        exe "pushd $tmpdir" || return 1
        report "installing powerline-fonts..."
        exe "./install.sh" || return 1

        exe "popd"
        exe "sudo rm -rf -- '$tmpdir'"

        add_to_dl_log  powerline-fonts "$ver"
        return 0
    }

    # https://github.com/stark/siji   (bitmap font icons)
    # TODO: x11! note pcf and bdf formats are ancient and not supported by wayland (https://www.reddit.com/r/swaywm/comments/e1r1r8/no_bitmap_font_support_ever/)
    install_siji() {
        local tmpdir repo ver

        readonly repo='https://github.com/stark/siji'

        ver="$(get_git_sha "$repo")" || return 1
        is_installed "$ver" siji-font && return 2

        tmpdir="$TMP_DIR/siji-font-$RANDOM"
        exe "git clone ${GIT_OPTS[*]} $repo $tmpdir" || { err 'err cloning siji font'; return 1; }
        exe "pushd $tmpdir" || return 1

        # by default installs into $HOME/.fonts
        exe "./install.sh" || { err "siji-font install.sh failed with $?"; return 1; }

        exe "popd"
        exe "sudo rm -rf -- '$tmpdir'"

        add_to_dl_log  siji-font "$ver"
        return 0
    }

    # see  https://wiki.archlinux.org/index.php/Font_configuration#Disable_bitmap_fonts
    #
    # to list font families, do [fc-list -f '%{family[0]}\n' | bat]
    # NOTE: should no longer be needed, as we're now enabling specific bitmap fonts
    #       explicitly in ~/.config/fontconfig/fonts.conf
    enable_bitmap_rendering() {
        local bitmap_no bitmap_yes

        readonly bitmap_no='/etc/fonts/conf.d/70-no-bitmaps-except-emoji.conf'
        readonly bitmap_yes='/usr/share/fontconfig/conf.avail/70-yes-bitmaps.conf'

        [[ ! -h "$bitmap_no" ]] || exe "sudo rm -- '$bitmap_no'" || return $?
        [[ ! -f "$bitmap_yes" ]] || create_link -s "$bitmap_yes" /etc/fonts/conf.d/
    }

    #enable_bitmap_rendering; unset enable_bitmap_rendering
    install_nerd_fonts; unset install_nerd_fonts

    install_block fonts-powerline
    #install_powerline_fonts; unset install_powerline_fonts

    install_siji; unset install_siji

    # TODO: guess we can't use xset when xserver is not yet running:
    #exe "xset +fp ~/.fonts"
    #exe "mkfontscale ~/.fonts"
    #exe "mkfontdir ~/.fonts"
    #exe "pushd ~/.fonts" || return 1

    ## also install fonts in sub-dirs:
    #for dir in ./* ; do
        #if [[ -d "$dir" ]]; then
            #exe "pushd $dir" || return 1
            #exe "xset +fp $PWD"
            #exe "mkfontscale"
            #exe "mkfontdir"
            #exe "popd"
        #fi
    #done

    #exe "xset fp rehash"
    #exe "fc-cache -fv"
    #exe "popd"
}


#magnus - magnifier app
# majority of packages get installed at this point;
install_from_repo() {
    local block blocks block1 block2 block3 block4 block5 extra_apt_params
    local block1_nonwin block2_nonwin block3_nonwin block4_nonwin

    declare -A extra_apt_params=(
    )

    declare -ar block1_nonwin=(
        # firmware-linux  # bunch of firmware, free & non-free
        smartmontools
        pm-utils  # utilities and scripts for power management
        ntfs-3g  # TODO: note ntfs3 is in kernel nowadays, unsure if and when we want to remove ntfs-3g pkg - they're not the same
        kdeconnect
        #erlang  # avail in mise
        cargo  # Rust package manager
        acpid  # Advanced Configuration and Power Interface event daemon
        lm-sensors  # utilities to read temperature/voltage/fan sensors; https://github.com/hramrach/lm-sensors
        #psensor  # GTK+ application for monitoring hardware sensors; unsure, but maybe x11?
        #xsensors  # xsensors reads data from the libsensors library regarding hardware health such as temperature, voltage and fan speed and displays the information in a digital read-out; https://github.com/Mystro256/xsensors
        hardinfo2  # !! good GUI !!; offers System Information and Benchmark for Linux Systems. https://github.com/hardinfo2/hardinfo2
        inxi  # full featured system information script (cli)
        macchanger  # utility for manipulating the MAC address of network interfaces; https://github.com/alobbs/macchanger
        #nftables  # debian default since Buster!
        firewalld  # nft wrapper
        fail2ban
        #udisks2  # D-Bus service to access and manipulate storage devices; https://www.freedesktop.org/wiki/Software/udisks/ ; commented out as it's already a dependency of udiskie we use
        udiskie  # a udisks2 front-end that allows to manage removable media ; https://github.com/coldfix/udiskie
        fwupd  # daemon to allow session software to update device firmware. https://github.com/fwupd/fwupd
        apparmor-utils  # provides tools such as aa-genprof, aa-enforce, aa-complain and aa-disable
        #apparmor-profiles  # experimental aa profiles
        apparmor-profiles-extra
        apparmor-notify  # utility to display AppArmor denial messages via desktop notifications
        auditd  # user space utilities for storing and searching the audit records generated by the audit subsystem
        systemd-container  # gives us systemd-nspawn command, see https://wiki.debian.org/nspawn
        systemd-zram-generator  # create zram device for swap space
        # haveged is a entropy daemon using jitter-entropy method to populate entropy pool;
        # some systems might start up slowly as entropy device is starved. see e.g. https://lwn.net/Articles/800509/, https://serverfault.com/a/986327
        # edit: should not be needed, as jitter entropy collecter was introduced
        # already in kernel 5.4: https://wiki.debian.org/BoottimeEntropyStarvation
        #haveged
        ddcutil
    )
    # old/deprecated block1_nonwin:
    #    ufw - simpler alternative to firewalld
    #    gufw
    #

    # TODO: xorg needs to be pulled into non-win (but still has to be installed for virt!) block:
    # TODO: replace compton w/ picom or ibhagwan/picom? compton seems unmaintained since 2017
    declare -ar block1=(
        dkms
        xorg
        #x11-apps  # already a dependecy of xorg
        #xinit  # xinit and startx are programs which facilitate starting an X server, and loading a base X session; already dependency of xorg
        psmisc  # miscellaneous utilities that use the proc FS, e.g. killall & pstree
        ssh-askpass  # under X, asks user for a passphrase for ssh-add; TODO: x11?
        alsa-utils  # Utilities for configuring and using ALSA, e.g. alsactl, alsamixer, amixer, aplay...
        pipewire
        pipewire-audio  # recommended set of PipeWire packages for a standard audio desktop use
        easyeffects  # Audio effects for PipeWire applications; https://github.com/wwmm/easyeffects; TODO: avail as flatpak
        pulsemixer  # https://github.com/GeorgeFilipkin/pulsemixer
        pasystray  # PulseAudio controller for the system tray; should work w/ pipewire
        qpwgraph  # visual representation of which audio devices are connected where; also allows point-and-click connections/configuration
        ca-certificates
        aptitude  # ncurses-based cli apt manager; https://wiki.debian.org/Aptitude
        #nala  # another cli-based apt frontend; https://gitlab.com/volian/nala
        #gdebi  # GUI local deb file viewer/installer for gnome
        synaptic
        apt-file  # command line tool for searching files contained in packages for the APT packaging system. You can search in which package a file is included or list the contents of a package without installing or fetching it
                  # TODO: do we need to schedule 'apt-file update'?
        command-not-found  # automatically search repos when entering unrecognized command, needs apt-file; installs hook for bash, to use w/ zsh see https://github.com/Freed-Wu/zsh-command-not-found
        apt-show-versions
        unattended-upgrades  # automatic installation of security upgrades
        apt-listchanges  # compare a new version of a package with the one currently installed and show what has been changed; TODO: we haven't provided configuration for it!
        sudo  # https://github.com/sudo-project/sudo
        libnotify-bin  # sends desktop notifications to a notification daemon; provides notify-send
        dunst  # notification-daemon; https://dunst-project.org/
        rofi  # TODO: x11!
        picom  # picom is a compositor for X11; https://github.com/yshui/picom ; for wayland consider https://github.com/WayfireWM/wayfire
        dosfstools  # utilities for making and checking MS-DOS FAT filesystems; https://github.com/dosfstools/dosfstools
        #alien  # convert LSB, Red Hat, Stampede and Slackware Packages into Debian packages
        #checkinstall
        #build-essential  # If you do not plan to build Debian packages, you don't need this package
        #scdoc  # man page generator
        #devscripts  # scripts to make the life of a Debian Package maintainer easier
        #equivs  # tool to create trivial Debian packages. Typically these packages contain only dependency information, but they can also include normal installed files like other packages do
        #cmake
        #ruby
        ipython3  # https://github.com/ipython/ipython
        python3
        python3-dev
        python3-venv  # venv module for python3
        python3-pip
        python-is-python3  # creates /usr/bin/python -> python3 symlink
        pipx  # https://github.com/pypa/pipx
        curl
        httpie  # CLI, cURL-like tool for humans; https://httpie.io/
        lshw  # list hardware; https://github.com/lyonel/lshw
        fuse3  # simple interface for userspace programs to export a virtual filesystem to the Linux kernel; https://github.com/libfuse/libfuse/
        #fuseiso  # FUSE module to mount ISO filesystem images
        parallel
        progress  # Coreutils Progress Viewer; Linux-and-OSX-Only C command that looks for coreutils basic commands (cp, mv, dd, tar, gzip/gunzip, cat, etc.); https://github.com/Xfennec/progress
        hashdeep
        dconf-cli  # low-level key/value database designed for storing gnome desktop environment settings; https://wiki.gnome.org/Projects/dconf
        dconf-editor  # GUI frontend for dconf
    )

    # for .NET dev, consider also nuget pkg;
    declare -ar block2_nonwin=(
        wireshark
        iptraf-ng  # ncurses-based IP LAN monitor that generates various network statistics, including bandwidth; https://github.com/iptraf-ng/iptraf-ng
        rsync
        wireguard
        #tailscale  # note depends on custom apt entry
        #openvpn3
        #network-manager-openvpn-gnome  # OpenVPN plugin GNOME GUI
        gparted  # GNOME partition editor; https://gparted.org/
        gnome-disk-utility  # manage and configure disk drives and media
        gnome-usage  # simple system monitor app for GNOME (cpu, mem, disk space...)
        aircrack-ng  # wireless WEP/WPA cracking utilities
        hashcat  # fastest and most advanced password recovery utility
        reaver  # brute force attack tool against Wi-Fi Protected Setup PIN number (WPS); https://github.com/t6x/reaver-wps-fork-t6x
    )
    # removed from above block:
    # -    netdata

    declare -ar block2=(
        strace  # system call tracer, i.e. a debugging tool which prints out a trace of all the system calls made by another process/program
        net-tools  # includes the important tools for controlling the network subsystem of the Linux kernel. This includes arp, ifconfig, netstat, rarp, nameif and route
        bind9-dnsutils  # provides dig, nslookup, nsupdate
        dnstracer  # determines where a given Domain Name Server (DNS) gets its information from for a given hostname, and follows the chain of DNS servers back to the authoritative answer
        mtr  # mtr combines the functionality of the 'traceroute' and 'ping' programs in a single network diagnostic tool; GUI
        whois  # whois client
        systemd-timesyncd
        #systemd-resolved  # !! be careful, it's buggy; e.g. see https://github.com/systemd/systemd/issues/21123 https://github.com/systemd/systemd/issues/13432 as pointed out in https://www.reddit.com/r/linux/comments/18kh1r5/im_shocked_that_almost_no_one_is_talking_about/
                           # NOTE: installation requires networking stack restart, see https://forums.debian.net/viewtopic.php?t=163267
                           #       that's why its installation has been moved to preseed
        network-manager
        network-manager-gnome
        jq  # https://jqlang.github.io/jq
        crudini  # .ini file manipulation tool
        htop  # https://htop.dev/
        glances  # Curses-based monitoring tool; https://github.com/nicolargo/glances
        #bpytop  # btop command; https://github.com/aristocratos/bpytop
        iotop  # top-like I/O monitor; handy for answering the question "Why is the disk churning so much?"
        ncdu  # ncurses disk usage viewer
        pydf  # fully colourised df(1)-clone written in Python; https://github.com/garabik/pydf - or perhaps https://salsa.debian.org/salvage-team/pydf/ - see https://github.com/garabik/pydf/issues/9 ??
        nethogs  # small 'net top' tool. Instead of breaking the traffic down per protocol or per subnet, like most tools do, it groups bandwidth by process; https://github.com/raboof/nethogs
        #vnstat  # console-based network traffic monitor; keeps a log of daily network traffic for the selected interface
        #nload  # monitors network traffic and bandwidth usage in real time.
        #iftop  # displays bandwidth usage information on an network interface
        #arp-scan  # uses the ARP protocol to discover and fingerprint IP hosts on the local network; https://github.com/royhills/arp-scan
        etherape  # graphical network monitor modeled after etherman. it displays network activity graphically
        tcpdump  # dump the traffic on a network; dump the traffic on a network
        tcpflow  # A program like 'tcpdump' shows a summary of packets seen on the wire, but usually doesn't store the data that's actually being transmitted. In contrast, tcpflow reconstructs the actual data streams and stores each flow in a separate file for later analysis; https://github.com/simsong/tcpflow
        #ngrep  # grep for network traffic; https://github.com/jpr5/ngrep
        #ncat  # reimplementation of Netcat by the NMAP project; https://nmap.org/
        nmap  # list listening ports on given address
        gping  # ping, but with a graph; https://github.com/orf/gping
        remind
        tkremind
        wyrd  # ncurses-based frontend for remind; https://gitlab.com/wyrd-calendar/wyrd
        taskwarrior  # https://taskwarrior.org/ ; executable is 'task'
        tree
        hyperfine  # cli benchmarking tool
        #debian-goodies
        #subversion  # might be used as a dependency, e.g. by zinit plugin (no more - github no longer supports svn)
        git
        tig  # https://github.com/jonas/tig
        git-cola
        git-extras  # https://github.com/tj/git-extras
        zenity
        #yad  # alternative to zenity
        gxmessage  # xmessage clone based on GTK+
        gnome-keyring
        seahorse
        libpam-gnome-keyring  # PAM module to unlock the GNOME keyring upon login
        lxpolkit           # provides a D-Bus session bus service that is used to bring up authentication dialogs used for obtaining privileges
                           # NOTE: used to use policykit-1-gnome, but it got removed/dropped from debian, as it's no longer maintained.
                           #
                           # - forum thread https://forums.bunsenlabs.org/viewtopic.php?id=8595&p=2 discusses it:
                           #     - consensus as of May seems to be: lxpolkit, or mate-polit (as latter is gtk3)
                           #         - also said "if xfce-polkit makes it to Trixie in time, might be worth considering."
                           #     - replace w/ lxqt-policykit or lxpolkit or polkit-kde-agent-1 or mate-polkit or ukui-polkit (last seems unmaintained as well)
                           #         - there's also xfce-polkit, but gh repo seen last update 3y ago
                           #         - think lxpolkit is the winner! other suggestion is mate-polkit (in https://forums.bunsenlabs.org/viewtopic.php?id=8595)
                           #           - doesn't mean much, but this upgrader also
                           #             decided on lxpolkit: https://www.reddit.com/r/debian/comments/1ktoa6m/debian_13_upgrade_report/
                           #         - what about polkitd - what does it provicde? text-based, not graphical?
        libsecret-tools  # can be used to store and retrieve passwords for desktop applications; provides us w/ 'secret-tool' cmd for interfacing w/ keyring
        gsimplecal
        khal  # https://github.com/pimutils/khal - CLI calendar program, able to sync w/ caldav servers through vdirsyncer
        vdirsyncer  # synchronizes your calendars and addressbooks between two storages. The most popular purpose is to synchronize a CalDAV/CardDAV server with a local folder or file
        #calcurse  # calendar and todo list for the console which allows you to keep track of your appointments and everyday tasks; https://calcurse.org/
        #galculator  # https://github.com/galculator/galculator
        speedcrunch  # https://heldercorreia.bitbucket.io/speedcrunch/  TODO: not avail in testing in aug '25
        calc  # for cli
        bcal  # another cli calcultor/storage conversion tool; https://github.com/jarun/bcal
        atool  # provides aunpack command. instead of atool, consider https://github.com/mholt/archives
        file-roller  # archive manager for gnome
        rar
        unrar
        zip
        7zip
        dos2unix  # convert text file line endings between CRLF and LF
        lxappearance  # TODO: x11
        qt5ct
        #qt5-style-plugins
        qt6ct
        gtk2-engines-murrine
        gtk2-engines-pixbuf
        gnome-themes-extra
        arc-theme
        numix-gtk-theme
        greybird-gtk-theme
        #materia-gtk-theme  # TODO: not avail for testing in aug '25
        numix-icon-theme
        faba-icon-theme
        meld
        at-spi2-core  # at-spi2-core is some gnome accessibility provider; without it some py apps (eg meld) complain; # TODO: x11 deps??
        pastebinit  # https://github.com/pastebinit/pastebinit
        keepassxc-full
        gnupg
        dirmngr  # server for managing and downloading OpenPGP and X.509 certificates, as well as updates and status signals related to those certificates;
                 # used for network access by gpg, gpgsm, and dirmngr-client, among other tools
        #direnv  # commented out as it might conflict w/ mise: https://mise.jdx.dev/direnv.html
        bash-completion
    )


    # fyi:
        #- [gnome-keyring???-installi vaid siis, kui mingi jama]
        #- !! gksu no moar recommended; pkexec advised; to use pkexec, you need to define its
        #     action in /usr/share/polkit-1/actions.

        # socat for mopidy+ncmpcpp visualisation;

    declare -ar block3_nonwin=(
        spotify-client
        #mopidy
        playerctl  # cli utility and library for controlling media players that implement the MPRIS D-Bus Interface Specification. Compatible players include audacious, cmus, mopidy, mpd, mpv, quod libet, rhythmbox, spotify, and vlc; https://github.com/altdesktop/playerctl
        socat
        yt-dlp  # dl vids from yt & other sites; https://github.com/yt-dlp/yt-dlp
        mpc  # cli tool to interface MPD; https://github.com/MusicPlayerDaemon/mpc
        ncmpc  # text-mode client for MPD; https://github.com/MusicPlayerDaemon/ncmpc
        ncmpcpp  # ncurses-based client for MPD; https://github.com/ncmpcpp/ncmpcpp
        #audacity  # TODO: there was a takeover by muse group, see https://hackaday.com/2021/07/13/muse-group-continues-tone-deaf-handling-of-audacity/
                   # was forked, see https://codeberg.org/tenacityteam/tenacity
        mpv  # video player based on MPlayer/mplayer2; https://mpv.io/
        kdenlive  # video editor; TODO: avail as flatpak
        frei0r-plugins  # https://github.com/dyne/frei0r ; collection of free and open source video effects plugins
        gimp  # TODO: avail as flatpak
        xss-lock  # TODO: x11!
        xsecurelock  # TODO: x11
        #filezilla
        #transmission
        #transmission-remote-cli
        #transmission-remote-gtk
        etckeeper
    )

    declare -ar block3=(
        firefox-esr  # TODO: avail as flatpak (does native messaging work tho?); also can pull binaries from mozilla. see https://wiki.debian.org/Firefox#From_Mozilla_binaries
        profile-sync-daemon  # pseudo-daemon designed to manage your browsers profile in tmpfs and periodically sync it back to disk
        buku  # CLI bookmark manager; https://github.com/jarun/Buku
        chromium
        chromium-sandbox  # TODO: doucment what's this about
        rxvt-unicode  # https://cvs.schmorp.de/rxvt-unicode/
        colortest-python  # https://github.com/eikenb/terminal-colors
        zathura  # https://github.com/pwmt/zathura
        pandoc  # Universal markup converter; used as dependency by some other services
        procyon-decompiler  # https://github.com/mstrobel/procyon - java decompiler; used as dependency, eg. by lessopen to view .class files
        #mupdf  # more featureful pdf viewer
        feh  # TODO x11; TODO: wallpaper_changer.sh dependency; https://github.com/derf/feh/ (mirror)
        nsxiv  # TODO: x11; # TODO: consider [imv] that supports both wayland & x11
        geeqie  # GTK-based image/gallery viewer
        gthumb  # gnome image viewer
        imagemagick
        inkscape  # vector-based drawing program  # TODO: avail as flatpak; alternatives: graphite (for raster AND vector)
        chafa  # image-to-text converter, i.e. images in terminals
        xsel  # TODO: x11
        wmctrl  # CLI tool to interact with an EWMH/NetWM compatible X Window Manager; TODO: x11; wayland alternative might be wlrctl
        polybar  # TODO: x11
        xdotool  # TODO: x11 - way not work w/ xwayland! !!! our screenshot.sh depends on it as of '25;  # https://github.com/jordansissel/xdotool/
        python3-xlib  # pure Python 3 implementation of the X11 protocol;  TODO: x11;  https://github.com/python-xlib/python-xlib
        exuberant-ctags  # parses source code and produces a sort of index mapping the names of significant entities (e.g. functions, classes, variables) to the location where that entity is defined
        nushell
        shellcheck
        #ranger  # CLI File Manager with VI Key Bindings;  https://ranger.github.io/
        vifm  # alternatives: yazi
        fastfetch  # takes screenshots of your desktop
        maim  # TODO: x11!  - screenshot.sh depends on it; one wayland alternative: grim: https://sr.ht/~emersion/grim/ ; see https://github.com/naelstrof/maim/issues/67#issuecomment-974622572 for usage
        flameshot  # https://github.com/flameshot-org/flameshot ; x11? looks like there's _some_ wayland support there
        ffmpeg
        ffmpegthumbnailer  # lightweight video thumbnailer that can be used by file managers to create thumbnails for your video files;  https://github.com/dirkvdb/ffmpegthumbnailer
        vokoscreen-ng  # https://github.com/vkohaupt/vokoscreenNG  # TODO: avail as flatpak
        peek  # simple screen recorder. It is optimized for generating animated GIFs; https://github.com/phw/peek; TODO: avail on flathub; TODO: x11! only runs in gnome shell wayland session via XWayland
        cheese  # webcam/camera tester; https://wiki.gnome.org/Apps/Cheese
        #screenkey  # displays used keys; TODO: x11
        mediainfo  # utility used for retrieving technical information and other metadata about audio or video files; https://mediaarea.net/en/MediaInfo
        #screenruler  # gnome; display a ruler on screen which allows you to measure the other objects that you've there
        lynx  # terminal web browser;
        elinks  # terminal web browser; has tabs! https://github.com/rkd77/elinks/
        #links2  # terminal+GUI web browser; TODO: x11?!
        #w3m  # another CLI web browser
        tmux
        neovim
        python3-pynvim  # Python3 library for scripting Neovim processes through its msgpack-rpc API; https://github.com/neovim/pynvim
        libxml2-utils  # provides xmllint, a tool for validating and reformatting XML documents, and xmlcatalog, a tool to parse and manipulate XML or SGML catalog files
        pidgin
        weechat  # like irssi but better; https://weechat.org/
        #bitlbee  # IRC to other chat networks gateway; http://www.bitlbee.org/
        #bitlbee-libpurple  # This package contains a version of BitlBee that uses the libpurple instant messaging library instead of built-in code, which adds support for more IM protocols (all protocols supported by Pidgin/Finch)
        purple-discord  # libpurple/Pidgin plugin for Discord
        nheko  # Qt-based chat client for Matrix  # TODO: avail as flatpak
        signal-desktop
        #signald  # note this doesn't come from debian repos
        #lxrandr  # GUI application for the Lightweight X11 Desktop Environment (LXDE); TODO: x11!
        arandr  # visual front end for XRandR; TODO: x11
        autorandr  # TODO: x11
        copyq  # TODO: avail as flatpak
        copyq-plugins
        #googler  # Google Site Search from the terminal; https://github.com/oksiquatzel/googler  # TODO: looks like it's broken: https://github.com/oksiquatzel/googler/issues/7
        msmtp  # msmtp is an SMTP client that can be used to send mails from Mutt and probably other MUAs (mail user agents)
        msmtp-mta  # This package is compiled with SASL and TLS/SSL support
        #thunderbird  # TODO: avail as flatpak
        neomutt
        notmuch
        abook  # ncurses address book application; to be used w/ mutt
        isync  # mbsync/isync is a command line application which synchronizes mailboxes; https://isync.sourceforge.io/
               # alternatives: getmail6
        urlview  # utility used to extract URL from text files, especially from mail messages in order to launch some browser to view them (eg mutt)
        translate-shell  # cli translator powered by Google Translate (and others); https://github.com/soimort/translate-shell # TODO: also avail via docker
    )
    # old/deprecated block3:
    #         spacefm-gtk3
    #         kazam (doesn't play well w/ i3)
    #

    declare -ar block4_nonwin=(
        adb
    )

    declare -ar block4=(
        colorized-logs
        highlight  # syntax highlighting; https://gitlab.com/saalen/highlight
        python3-pygments  # syntax highlighting in py
        silversearcher-ag
        ugrep  # Universal grep: ultra fast searcher of file systems, text and binary files, source code, archives, compressed files, documents, and more; https://github.com/Genivia/ugrep/
        gawk  # gnu awk
        plocate  # updatedb generates an index of files and directories. GNU locate can be used to quickly query this index
        fzy  # different fuzzy finder take than fzf (faster, possibly better results); https://github.com/jhawthorn/fzy
        cowsay
        #cowsay-off  # offensive
        toilet  # prints text using large characters made of smaller characters
        lolcat  # like cat, but colours it;  https://github.com/busyloop/lolcat
        figlet  # creates large ascii characters out of ordinary screen characters
        xplanet  # renders an image of a planet into an X window or a file; TODO: x11
        xplanet-images  # includes some map files that can be used with xplanet; TODO: x11
        #redshift  # TODO: x11!
        gammastep  # redshift alternative: https://gitlab.com/chinstrap/gammastep ; should support some wayland as well
        geoclue-2.0  # D-Bus geoinformation service; https://gitlab.freedesktop.org/geoclue/geoclue/
        podman
        podman-docker  # installs a Docker-compatible CLI interface
        uidmap  # needed to run podman containers as non-root; note it's also a recommended pkg for podman; see https://forum.openmediavault.org/index.php?thread/42841-podman-seams-to-miss-uidmap/
        passt   # needed for non-root podman container networking; note it's also a recommended pkg for podman;
        # slirp4netns   # fills similar needs to passt/pasta, but is older; also recommended pkg for podman
        criu  # utilities to checkpoint and restore processes in userspace; It can freeze a running container (or an individual application) and checkpoint its state to disk
        mitmproxy  # SSL-capable man-in-the-middle HTTP proxy; https://github.com/mitmproxy/mitmproxy
        #charles-proxy5  # note also avail as tarball @ https://www.charlesproxy.com/download/
        tofu
        gh  # github cli
    )
    # old/deprecated block4:


    # some odd libraries
    declare -ar block5=(
        libjson-perl  # module for manipulating JSON-formatted data
    )

    declare -a blocks
    is_native && blocks=(block1_nonwin block2_nonwin block3_nonwin block4_nonwin)
    blocks+=(block1 block2 block3 block4 block5)

    exe 'sudo apt-get --yes update'
    for block in "${blocks[@]}"; do
        if ! install_block "$(eval echo "\${$block[@]}")" "${extra_apt_params[$block]}"; then
            err "install block [$block] failed to install, see the logs"
            confirm -d Y "continue with setup? answering no will exit script" || exit 1
        fi
    done


    # TODO: replace virtualbox by KVM & https://virt-manager.org/ - https://wiki.debian.org/KVM
    #
    # Note alternatively could install vbox from oracle repos, see https://www.virtualbox.org/wiki/Linux_Downloads
    #
    # another alternatives:
    # - https://flathub.org/apps/org.gnome.Boxes
    # - https://github.com/firecracker-microvm/firecracker/
    if [[ "$PROFILE" == work ]]; then
        true
        #if is_native; then
            #install_block '
                #remmina
                #samba-common-bin
                #smbclient

                #virtualbox
                #virtualbox-dkms
                #virtualbox-qt
            #'
        #fi

        #install_block '
            #ruby-dev
        #'

        # remmina is remote desktop for windows; rdesktop, remote vnc; TODO: avail as flatpak
    fi

    if is_virtualbox; then
        install_vbox_guest
    fi
}


# https://wiki.debian.org/KVM
# - note libvirtd is the daemon process, separate from clients.
# - possible clients:
#   - virsh (cli)
#   - boxes (gnome app)
#   - virt-viewer (display client)
#   - virt-manager (gui manager)
#   - see all @ https://wiki.archlinux.org/title/Libvirt#Client
#
# commands:
# - list vms:
#   virsh list --all
#
# collection of relevant scripts: https://github.com/sej7278/virt-installs
# - to inject debian preseed file: https://github.com/sej7278/virt-installs/blob/master/preseed_deb10/debian10_preseed.sh
#
# TODO: at least the GUI virt-manager is buggy:
# - not able to read image files: https://unix.stackexchange.com/questions/796179/unable-to-create-libvirt-domain-persmission-denied-reading-os-iso
# - also deleting snapshots fail. and when we delete the whole domain/vm, then
#   they're gone in virt-manager, but files are still at /var/lib/libvirt/images/ !!!
# - if you get error [Requested operation is not valid: network 'default' is not active],
#   see https://blog.programster.org/kvm-missing-default-network
install_kvm() {
    # virt-install - cli utils to create & edit virt machines
    install_block -f '
        qemu-system
        libvirt-daemon-system
        virt-install
        virt-manager
        virt-viewer
    '

    add_to_group libvirt  # in order to manage virtual machines as a regular user
}


# commands:
# - flatpak info --show-permissions com.github.PintaProject.Pinta
# - flatpak permission-show com.github.PintaProject.Pinta
install_from_flatpak() {
    local i

    # https://flathub.org/apps/com.github.PintaProject.Pinta
    i='com.github.PintaProject.Pinta'
    if fp_install -n pinta  "$i"; then
        # enable pinta access to /tmp, as we need file IO in /tmp
        # due to our screenshooter: (see https://github.com/PintaProject/Pinta/issues/1357)
        exe "sudo flatpak override $i --filesystem=/tmp"  # causes file @ /var/lib/flatpak/overrides/com.github.PintaProject.Pinta  to be created/modified
    fi

    # https://flathub.org/apps/engineer.atlas.Nyxt
    # web browser written in LISP
    fp_install -n nyxt  'engineer.atlas.Nyxt'

    # https://github.com/saivert/pwvucontrol
    fp_install -n pwvucontrol  'com.saivert.pwvucontrol'

    # https://flathub.org/apps/com.discordapp.Discord
    fp_install -n discord  'com.discordapp.Discord'

    # https://flathub.org/apps/org.telegram.desktop
    fp_install -n telegram  'org.telegram.desktop'

    # https://flathub.org/apps/org.libreoffice.LibreOffice
    fp_install -n libreoffice  'org.libreoffice.LibreOffice'
}

# install/update the guest-utils/guest-additions.
#
# note it's preferrable to do it this way as opposed to installing
# {virtualbox-guest-utils virtualbox-guest-x11} packages from apt, as additions
# are rather related to vbox version, so better use the one that's shipped w/ it.
#
# !! make sure guest additions CD is inserted: @ host: Devices->Insert Guest Additions CD...
#
# see https://www.virtualbox.org/manual/ch04.html#additions-linux
install_vbox_guest() {
    local tmp_mount bin label

    tmp_mount="$TMP_DIR/cdrom-mount-tmp-$RANDOM"
    bin="$tmp_mount/VBoxLinuxAdditions.run"

    is_virtualbox || return 0
    install_block 'virtualbox-guest-dkms' || return 1

    ensure_d "$tmp_mount" || return 1
    exe "sudo mount /dev/cdrom $tmp_mount" || { err "mounting guest-utils from /dev/cdrom to [$tmp_mount] failed w/ $? - is image mounted in vbox and in expected (likely first) slot?"; return 1; }
    [[ -x "$bin" ]] || { err "[$bin] not an executable file"; return 1; }
    label="$(grep --text -Po '^label=.\K.*(?="$)' "$bin")"  # or grep for 'INSTALLATION_VER'?

    if ! is_single "$label"; then
        err "found vbox additions ver was unexpected: [$label]; will continue w/ installation"
    elif is_installed "$label" vbox-guest-additions; then
        return 2
    fi

    # append '--nox11' if installing in non-gui system:
    exe -c 2 "sudo sh $bin" || err "looks like [sh $bin] failed w/ $?"
    exe "sudo umount $tmp_mount" || err "unmounting cdrom from [$tmp_mount] failed w/ $?"

    is_single "$label" && add_to_dl_log "vbox-guest-additions" "$label"
}


# offers to install AMD drivers, if card is detected.
# note run radeontop to monitor AMD card usage
#
# https://wiki.debian.org/AtiHowTo
install_amd_gpu() {
    # TODO: consider  lspci -vnn | grep VGA | grep AMD
    if sudo lshw | grep -iA 5 'display' | grep -Eq 'vendor.*AMD'; then
        if confirm -d N "we seem to have AMD card; want to install AMD drivers?"; then  # TODO: should we default to _not_ installing in non-interactive mode?
            report "installing AMD drivers & firmware..."
            # TODO: x11!:
            install_block 'firmware-amd-graphics libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers xserver-xorg-video-amdgpu radeontop'
            return $?
        else
            report "we chose not to install AMD drivers..."
        fi
    else
        report "we don't have an AMD card; skipping installing their drivers..."
    fi
}


# install cpu microcode patches; mostly security-related implications
install_cpu_microcode_pkg() {
    if is_intel_cpu; then
        # see https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files
        install_block  intel-microcode
    elif is_amd_cpu; then
        install_block  amd64-microcode
    else
        err "!! could not detect our cpu vendor !!"
        return 1
    fi
}


# read https://wiki.debian.org/Btrfs, especially 'Recommendations'
# commands:
# - btrfs dev stats /btrfs_mountpoint
#   - overview of all devices in pool, statuses etc
# - btrfs su list /
# - btrfs filesystem usage /
#
# TODO:
# - if we use snapper, add it to PRUNEPATHS of configure_updatedb()
setup_btrfs() {
    if is_btrfs; then
        # TODO: do we need to set up btrfsmaintenance? think we need to manually schedule it, e.g. scrub
        install_block 'btrfsmaintenance btrfs-progs'

        _setup_snapper
    else
        true # TODO: verify we don't leave in some btrfs-specifics!
    fi
}


# rootless tutorial: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
# alternatives:
# - containerd + nerdctl
_setup_podman() {
    is_d -m 'is podman installed?' /etc/containers || return 1

    # touch file to avoid msg printed to stdout whenever we use 'docker' command:
    # msg being [Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg.]
    [[ -e /etc/containers/nodocker ]] || exe 'sudo touch /etc/containers/nodocker' || return 1

    return 0  # atm not using btrfs storage driver, as it's not really recommended by the devs

    local conf user_conf user_storage
    conf='/etc/containers/storage.conf'
    user_conf="$HOME/.config/containers/storage.conf"
    #user_storage="/var/lib/containers/user-storage/$USER"

    #[[ -f "$conf" ]] || { err "[$conf] is not a valid file. is podman installed?"; return 1; }  # doesn't exist by default

    # by default rootless storage is @ $XDG_DATA_HOME/containers/storage
    # change it, e.g. to benefit from a nocow dir:
    # from https://access.redhat.com/solutions/7007159
    #exe "sudo crudini --set '$conf' storage rootless_storage_path '\"/var/lib/containers/user-storage/\$USER'\"" || return 1  # <-- do not expand $USER!
    #ensure_d -s "$user_storage" || return 1
    #exe "sudo chown $USER:$USER '$user_storage'"  # TODO broken, as write permission should be given to entire /var/lib... dir path

    if is_btrfs; then
        if grep -qF btrfs "$conf"; then
            report "[btrfs] found in [$conf], assuming we're already set up..."
        else
            # podman-system-reset needs to be ran before changing certain conf items (e.g. storage.conf): https://docs.podman.io/en/latest/markdown/podman-system-reset.1.html
            exe 'podman system reset'  # for rootless
            exe 'sudo podman system reset'  # for root

            exe "sudo crudini --set '$conf' storage driver btrfs" || return 1
            ensure_d "$(dirname -- "$user_conf")" || return 1
            exe "crudini --set '$user_conf' storage driver btrfs"
        fi
    elif grep -qF btrfs "$conf" "$user_conf"; then
        err "[btrfs] in podman storage.conf but we're not using btrfs!"
    fi
}


# for guidance see https://github.com/archlinux/archinstall/blob/master/archinstall/lib/installer.py (function setup_btrfs_snapshot())
#
# - note snapper will always take pre- and post snapshots every time apt installs something;
#   configured via /etc/default/snapper and/or /etc/apt/apt.conf.d/80snapper.
# - NUMBER_CLEANUP enables/disables cleanup of installation&admin snapshot pairs
#
# - print config via $ snapper -c root get-config
# - list snaps: $ snapper -c root list
#
# NOTE: not idempotent! actually kind of is; create-config for existing subvolume exits w/ 1
# alternatives to snapper:
# - https://github.com/digint/btrbk - remote transfer of snapshots for backup
# - Timeshift
_setup_snapper() {
    [[ -e /etc/default/snapper ]] && return 0  # config file exists, assume we're already set up

    _enable() {
        local opt OPTIND custom name mountpoint mp

        while getopts 'c' opt; do
            case "$opt" in
                c) custom=TRUE ;;  # custom, pre-existing subvolume to use instead of snapper-created nested subvol
                *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
            esac
        done
        shift "$((OPTIND-1))"

        name="$1"
        mountpoint="$2"

        mp="${mountpoint%%+(/)}/"  # ${mountpoint%%+(/)} removes any number of trailing slashes

        if [[ -n "$custom" ]]; then
            # The default way that snapper works is to automatically create a new subvolume
            # “.snapshots” under the path of the subvolume that we are creating a snapshot.
            # Because we want to keep our snapshots separated from the backed up subvolume
            # itself we must remove the snapper created “.snapshot” subvolume and then
            # re-mount using the one that we created before in a separate subvolume at @snapshots
            exe "sudo umount ${mp}.snapshots" || return 1
            exe "sudo rm -r -- ${mp}.snapshots" || return 1
        fi

        # create new config(s):
        # this will likely create a new .snapshots/ dir as well a new btrfs subvol
        # of same name. we will rm this new subvol and link our own @snapshots
        # subvol to this path, so our snapshots are safely stored in different location.
        exe "sudo snapper -c $name create-config $mountpoint" || return 1  # note returns 1 if $mountpoint is already covered

        if [[ -n "$custom" ]]; then
            exe "sudo btrfs subvolume delete '${mp}.snapshots'" || return 1  # delete auto-created subvol
            ensure_d -s "${mp}.snapshots" || return 1
            exe "sudo mount -av" || return 1  # remount our @snapshots (or whatever is defined in fstab) to ${mp}.snapshots
        fi

        exe "sudo snapper -c $name set-config 'ALLOW_GROUPS=sudo'"
        exe "sudo snapper -c $name set-config 'SYNC_ACL=yes'"
        #exe "sudo snapper -c $name set-config 'TIMELINE_CREATE=no'"  # disable hourly snaps; think this is also controlled by snapper-timeline.timer ?
        # reduce number of snapshots kept to avoid slowdowns:
        exe "sudo snapper -c $name set-config 'TIMELINE_LIMIT_HOURLY=5'"
        exe "sudo snapper -c $name set-config 'TIMELINE_LIMIT_DAILY=7'"
        exe "sudo snapper -c $name set-config 'TIMELINE_LIMIT_WEEKLY=0'"
        exe "sudo snapper -c $name set-config 'TIMELINE_LIMIT_MONTHLY=0'"
        exe "sudo snapper -c $name set-config 'TIMELINE_LIMIT_YEARLY=0'"

        exe "sudo snapper -c $name set-config 'NUMBER_LIMIT=10'"
        exe "sudo snapper -c $name set-config 'NUMBER_LIMIT_IMPORTANT=10'"
        #exe "sudo snapper -c $name set-config 'NUMBER_MIN_AGE=600'"
    }

    install_block 'snapper snapper-gui' || return 1

    _enable -c root /
    _enable -c home /home

    ######################################################################
    exe "sudo systemctl disable snapper-boot.timer"  # disable taking snapshot of @root at boot
    exe "sudo systemctl enable snapper-timeline.timer"
    exe "sudo systemctl enable snapper-cleanup.timer"

    unset _enable
}


# offers to install nvidia drivers, if NVIDIA card is detected.
#
# in order to reinstall the dkms part, purge nvidia-driver and then reinstall.
#
# - Note if you see some flickering, it might be caused by compton and its settings.
#   eg based on info from https://github.com/chjj/compton/issues/152,
#    set glx-swap-method to 1;
# - also, you might want to select 'Force Full Composition Pipeline' from
#   nvidia-settings -> x server Disp Conf -> Advanced... -> tick the box
# - you might also consider enabling/disabling KMS: https://wiki.archlinux.org/index.php/kernel_mode_setting
#
# https://wiki.debian.org/NvidiaGraphicsDrivers
# TODO: add logic to detect & configure nvidia Optimus, also described in abovementioned link
install_nvidia() {
    # TODO: consider  lspci -vnn | grep VGA | grep -i nvidia
    if sudo lshw | grep -iA 5 'display' | grep -Eiq 'vendor.*NVIDIA'; then
        if confirm -d N "we seem to have NVIDIA card; want to install nvidia drivers?"; then  # TODO: should we default to _not_ installing in non-interactive mode?
            # TODO: also/instead install  nvidia-detect and install the driver it suggests?
            report "installing NVIDIA drivers..."
            install_block 'nvidia-driver'
            #exe "sudo nvidia-xconfig"  # not required as of Stretch
            return $?
        else
            report "we chose not to install nvidia drivers..."
        fi
    else
        report "we don't have an nvidia card; skipping installing their drivers..."
    fi
}


# provides the possibility to cherry-pick out packages.
# this might come in handy, if few of the packages cannot be found/installed.
#
# TODO: current implementation doesn't allow for [pkgname/unstable] usage
install_block() {
    local opt OPTIND noinstall list_to_install extra_apt_params
    local avail_pkgs missing_pkgs unavail_pkgs i cache_out

    declare -a avail_pkgs missing_pkgs unavail_pkgs
    noinstall='--no-install-recommends'  # default
    while getopts 'f' opt; do
        case "$opt" in
           f) unset noinstall ;;  # mnemonic: full
           *) return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    declare -ar list_to_install=($1)
    readonly extra_apt_params="$2"  # optional

    for i in "${list_to_install[@]}"; do
        # other commands to consider: - apt list -a
        if ! cache_out="$(apt-cache -qq show "$i/testing" 2>/dev/null)"; then
            unavail_pkgs+=("$i")
        else
            [[ -n "$cache_out" ]] && avail_pkgs+=("$i") || missing_pkgs+=("$i")
        fi
    done

    if [[ "${#unavail_pkgs[@]}" -ne 0 ]]; then
        err "${#unavail_pkgs[@]} packages were not available in APT"
        err "${unavail_pkgs[*]}"
    fi
    if [[ "${#missing_pkgs[@]}" -ne 0 ]]; then
        err "${#missing_pkgs[@]} packages were not available in APT for testing:"
        err "${missing_pkgs[*]}"
    fi

    report "installing these packages:\n${avail_pkgs[*]}\n"
    exe "sudo DEBIAN_FRONTEND=noninteractive  NEEDRESTART_MODE=l  apt-get --yes install ${noinstall:+$noinstall }$extra_apt_params ${avail_pkgs[*]}"
}


choose_step() {
    if [[ -z "$MODE" ]]; then
       select_items -s -h 'what do you want to do' single-task update fast-update full-install
       case "$__SELECTED_ITEMS" in
          'single-task'  ) MODE=0 ;;
          'update'       ) MODE=2 ;;
          'fast-update'  ) MODE=3 ;;
          'full-install' ) MODE=1 ;;
          ''             ) exit 0 ;;
          *) fail "unsupported choice [$__SELECTED_ITEMS]" ;;
       esac
    fi

    if [[ "$BOOTSTRAP_LAUNCHER_TAG" != Y ]] && [[ "$MODE" -eq 1 || "$LOGGING_LVL" -ge 20 ]] && command -v script >/dev/null; then
        script --flush --quiet --return --log-out "$SCRIPT_LOG" --command "BOOTSTRAP_LAUNCHER_TAG=Y MODE=$MODE $0 ${ORIG_OPTS[*]}"
        ERR=$?

        # ways to clean up $script output:
        # $ ansi2html <"$SCRIPT_LOG" > out.html
        # $ ansi2txt <file.log | col -bp >| 111
        # - note both ansi2* commands come from [colorized-logs] package
        if is_f -n "$SCRIPT_LOG"; then
            if command -v ansi2txt >/dev/null; then
                ansi2txt <"$SCRIPT_LOG" | col -bp > "${SCRIPT_LOG}.cleaned"
                echo -e "    cleaned up terminal log can be found at [${SCRIPT_LOG}.cleaned]"
            else
                echo -e "    terminal log can be found at [$SCRIPT_LOG]"
            fi
        fi
        exit $ERR
    fi

    trap 'cleanup; exit' EXIT HUP INT QUIT PIPE TERM;

    case "$MODE" in
        0) choose_single_task ;;
        1) full_install ;;
        2) quick_refresh ;;
        3) quicker_refresh ;;
        *) exit 1 ;;
    esac
}


# basically offers steps from setup() & install_progs():
choose_single_task() {
    local choices

    [[ "$LOGGING_LVL" -eq 0 ]] && LOGGING_LVL=1
    readonly MODE=0

    source_shell_conf
    setup_install_log_file
    setup_dirs  # has to come after $SHELL_ENVS sourcing so the env vars are in place


    # note choices need to be valid functions
    declare -a choices=(
        __choose_prog_to_build
        setup
        setup_homesick
        setup_seafile
        setup_apt
        setup_hosts
        setup_systemd

        generate_ssh_key
        install_nm_dispatchers
        install_acpi_events
        install_deps
        install_fonts
        upgrade_kernel
        install_kernel_modules
        upgrade_firmware
        install_cpu_microcode_pkg
        install_nvidia
        install_amd_gpu
        install_webdev
        install_from_repo
        install_ssh_server_or_client
        install_nfs_server_or_client
        install_games
        install_xonotic
        install_from_flatpak
        install_setup_printing_cups
    )

    if is_virtualbox; then
        choices+=(install_vbox_guest)
    fi

    select_items -s -h 'what do you want to do' "${choices[@]}"
    [[ -z "$__SELECTED_ITEMS" ]] && return

    $__SELECTED_ITEMS
}


# meta-function;
# offers steps from install_own_builds():
#
# note full-install counterpart would be install_own_builds()
__choose_prog_to_build() {
    local choices

    declare -ar choices=(
        install_YCM
        install_keepassxc
        install_keybase
        build_goforit
        build_copyq
        install_lesspipe
        install_lessfilter
        install_uhk_agent
        build_ddcutil
        install_slides
        install_seafile_cli
        install_seafile_gui
        install_ferdium
        install_freetube
        install_zoom
        install_xournalpp
        install_zoxide
        install_fzf
        install_ripgrep
        install_rga
        install_browsh
        install_rebar
        install_treesitter
        install_coursier
        install_clojure
        install_zprint
        install_clj_kondo
        install_lazygit
        install_lazydocker
        install_dive
        install_television
        install_systemd_manager_tui
        install_fd
        install_jd
        install_bat
        install_sad
        install_viu
        install_glow
        install_btop
        install_procs
        install_eza
        install_delta
        install_dust
        install_bandwhich
        install_btdu
        install_peco
        build_i3
        install_i3
        install_i3_deps
        build_i3lock
        build_i3lock_fancy
        install_betterlockscreen
        build_polybar
        install_saml2aws
        install_aia
        install_kustomize
        install_k9s
        install_krew
        install_popeye
        install_kops
        install_kubectx
        install_kubectl
        install_kube_ps1
        install_sops
        install_grpcui
        install_grpc_cli
        install_dbeaver
        install_gitkraken
        install_p4merge
        install_steam
        install_chrome
        install_redis_desktop_manager
        install_eclipse_mem_analyzer
        install_visualvm
        install_vnote
        install_obsidian
        install_postman
        install_arc
        install_bruno
        install_alacritty
        install_wezterm
        install_atuin
        install_lnav
        install_weeslack
        install_weechat_matrix_rs
        install_gomuks
        install_slack_term
        install_slack
        install_bitlbee
        install_terragrunt
        install_minikube
        install_gruvbox_gtk_theme
        install_gruvbox_material_gtk_theme
        install_veracrypt
        install_ueberzugpp
        install_hblock
        install_open_eid
        install_binance
        install_electrum_wallet
        install_revanced
        install_apkeditor
        install_vbox_guest
        install_kvm
        install_brillo
        install_display_switch
        install_neovide
        install_helix
        install_mise
        install_croc
        install_ventoy
        install_kanata
        install_plandex
        install_open_interpreter
        install_aichat
        install_aider
        install_aider_desk
        install_android_command_line_tools
    )

    report "what do you want to build/install?"

    select_items -s "${choices[@]}"
    [[ -z "$__SELECTED_ITEMS" ]] && return
    #prepare_build_container || { err "preparation of build container [$BUILD_DOCK] failed"; return 1; }

    $__SELECTED_ITEMS
}


full_install() {

    [[ "$LOGGING_LVL" -eq 0 ]] && LOGGING_LVL=10
    readonly MODE=1

    setup

    is_windows || upgrade_kernel  # keep this check is_windows(), not is_native();
    install_fonts
    install_progs
    install_deps
    is_interactive && is_native && install_ssh_server_or_client
    is_interactive && is_native && install_nfs_server_or_client
    [[ "$PROFILE" == work ]] && exe_work_funs
    setup_btrfs  # late, so snapper won't create bunch of snapshots due to apt operations
    is_pkg_installed podman && _setup_podman

    remind_manually_installed_progs
}


# quicker update than full_install() to be executed periodically
quick_refresh() {
    [[ "$LOGGING_LVL" -eq 0 ]] && LOGGING_LVL=1
    readonly MODE=2

    setup

    install_progs
    install_deps

    exe 'pipx  upgrade-all'
    exe 'flatpak -y --noninteractive update'
}


# even faster refresher without the install_from_repo() step that's included in install_progs()
quicker_refresh() {
    [[ "$LOGGING_LVL" -eq 0 ]] && LOGGING_LVL=1
    readonly MODE=3

    setup

    install_own_builds        # from install_progs()
    post_install_progs_setup  # from install_progs()
    install_deps  # TODO: do we want this with mode=3?

    exe 'pipx  upgrade-all'
    exe 'flatpak -y --noninteractive update'
}


# execute work-defined shell functions, likely in ~/.bash_funs_overrides/;
# note we seek functions by a pre-defined prefix;
exe_work_funs() {
    local f

    # version where we resolve & execute _all_ functions prefixed w/ 'w_':
    #while read -r f; do
        #is_function "$f" || continue
        #exe "$f"
    #done< <(declare -F | awk '{print $NF}' | grep '^w_')

    # another ver where we execute pre-defined set of funs, ie no resolving via prefix:
    for f in \
            palceholder_fun_doesnt_exist \
                ; do
        is_function "$f" || continue
        exe "$f"
    done
}


# programs that cannot be installed automatically should be reminded of
remind_manually_installed_progs() {
    local progs i

    declare -ar progs=(
        'GPG restore/import'
        'intelliJ toolbox'
        'install tmux plugins (prefix+I)'
        'ublock additional configs (EST, social media, ...)'
        'ublock whitelist, filters (should be saved somewhere)'
        'import keepass-xc browser plugin config'
        'install tridactyl native messenger/executable (:installnative)'
        'set the firefox config, see details @ setup_firefox()'
        'install/load chromium Surfingkeys plugin config from [https://github.com/laur89/surfingkeys-config/]'
        'setup default keyring via seahorse'
        'update system firmware'
        'download seafile libraries'
        'setup Signal backup - follow reddit thread & finally _manually_ create link to our seafile lib'
        'enroll secureboot MOK if using SB'
    )

    for i in "${progs[@]}"; do
        if ! command -v "$i" >/dev/null; then
            report "    don't forget [$i]"
        fi
    done
}


# as per    https://intellij-support.jetbrains.com/hc/en-us/articles/15268113529362-Inotify-Watches-Limit-Linux
increase_inotify_watches_limit() {
    _sysctl_conf '60-jetbrains.conf' 'fs.inotify.max_user_watches' 1048576
}


allow_user_run_dmesg() {
    _sysctl_conf '60-allow-dmesg.conf' 'kernel.dmesg_restrict' 0
}


## increase the max nr of open file in system. (for intance node might compline otherwise).
## see https://github.com/paulmillr/chokidar/issues/45
## and http://stackoverflow.com/a/21536041/1803648
# https://forums.debian.net/viewtopic.php?t=159383
increase_ulimit() {
    true
    # TODO: I think setting this is not needed, given $ cat /proc/sys/fs/file-max      already reports max value?:
    #_sysctl_conf '20-no-files.conf' 'fs.file-max' 65535
}


# as per    https://wiki.archlinux.org/index.php/Linux_Containers#Enable_support_to_run_unprivileged_containers_(optional)
# i _think_ this issue popped up w/ after 'Franz' or 'notable' started using electron v5+
#
# see also https://www.baeldung.com/linux/kernel-enable-user-namespaces
# TODO: this _should'nt_ be needed anymore as of Linux 5.10: https://www.debian.org/releases/bullseye/amd64/release-notes/ch-information.en.html#linux-user-namespaces
# TODO: deprecate
#
# this is needed eg for electron v5+ to enable sandboxing; eg see
#    https://github.com/electron/electron/issues/17972
#    https://github.com/notable/notable/issues/792
#    https://github.com/electron/electron/issues/16631
enable_unprivileged_containers_for_regular_users() {
    _sysctl_conf '70-enable-unprivileged-containers.conf' 'kernel.unprivileged_userns_clone' 1
}

_sysctl_conf() {
    local sysctl_dir sysctl_conf property value

    readonly sysctl_dir='/etc/sysctl.d'
    readonly sysctl_conf="${sysctl_dir}/$1"
    readonly property="$2"
    readonly value="$3"

    is_d -m "can't change our sysctl value for [$1]" "$sysctl_dir" || return 1

    if [[ -f "$sysctl_conf" ]]; then
        grep -Eq "^${property}\s*=\s*${value}\$" "$sysctl_conf" && return 0  # value already set, nothing to do
        # delete all same prop definitions, regardless of its value:
        exe "sudo sed -i --follow-symlinks '/^${property}\s*=/d' '$sysctl_conf'"
    fi

    exe "echo $property = $value | sudo tee --append $sysctl_conf > /dev/null"

    # mark our sysctl config has changed:
    SYSCTL_CHANGED=1
}

# add manpath mapping
add_manpath() {
    local path manpath man_db

    path="$1"
    manpath="$2"
    man_db='/etc/manpath.config'

    is_f -m "can't add [$path -> $manpath] mapping" "$man_db" || return 1
    is_d -m "can't add [$path -> $manpath] mapping" "$path" || return 1
    is_d -m "can't add [$path -> $manpath] mapping" "$manpath" || return 1

    grep -Eq "^MANPATH_MAP\s+${path}\s+${manpath}$" "$man_db" && return 0  # value already set, nothing to do
    exe "echo 'MANPATH_MAP $path  $manpath' | sudo tee --append $man_db > /dev/null"
}


# setup tcpdump so our regular user can exe it
# see https://www.stev.org/post/howtoruntcpdumpasroot
# see also https://unix.stackexchange.com/questions/628662
setup_tcpdump() {
    local tcpd

    tcpd='/usr/bin/tcpdump'

    [[ -x "$tcpd" ]] || { err "[$tcpd] exec does not exist"; return 1; }

    add_to_group  tcpdump
    exe "sudo chown root:tcpdump $tcpd" || return 1
    exe "sudo chmod 0750 $tcpd" || return 1
    exe "sudo setcap 'CAP_NET_RAW+eip' $tcpd" || return 1
    #exe "sudo setcap cap_net_raw,cap_net_admin=eip $tcpd" || return 1
}


# make sure resolvconf (or openresolv?) pkg is installed for seamless resolv config updates & dnsmasq usage (as per https://unix.stackexchange.com/a/406724/47501)
#
# note we no longer are using dnsmasq - unsing systemd-resolved instead
setup_dnsmasq() {
    local dnsmasq_conf dnsmasq_conf_dir i

    readonly dnsmasq_conf="$COMMON_DOTFILES/backups/dnsmasq.conf"
    readonly dnsmasq_conf_dir='/etc/dnsmasq.d'

    # update dnsmasq conf:
    # note: to check dnsmasq conf/performance, see
    #     dig +short chaos txt hits.bind
    #     dig +short chaos txt misses.bind
    #     dig +short chaos txt cachesize.bind
    is_d "$dnsmasq_conf_dir" || return 1
    is_f -nm 'cannot update config' "$dnsmasq_conf" || return 1
    exe "sudo install -m644 -C '$dnsmasq_conf' '$dnsmasq_conf_dir'" || { err "installing [$dnsmasq_conf] failed w/ $?"; return 1; }


    # old ver, directly updating /etc/dnsmasq.conf:
    #exe "sudo sed -i --follow-symlinks '/^cache-size=/d' '$dnsmasq_conf'"
    #exe "echo cache-size=10000 | sudo tee --append $dnsmasq_conf > /dev/null"

    #exe "sudo sed -i --follow-symlinks '/^local-ttl=/d' '$dnsmasq_conf'"
    #exe "echo local-ttl=10 | sudo tee --append $dnsmasq_conf > /dev/null"

    ## lock dnsmasq to be exposed only to localhost:
    #exe "sudo sed -i --follow-symlinks '/^listen-address=/d' '$dnsmasq_conf'"
    #exe "echo listen-address=::1,127.0.0.1 | sudo tee --append $dnsmasq_conf > /dev/null"


    # TODO: not sure about this bit:
    #if [[ "$PROFILE" != work ]]; then
        #exe "sudo sed -i --follow-symlinks '/^server=/d' '$dnsmasq_conf'"
        #for i in 1.1.1.1   8.8.8.8; do
            #exe "echo server=$i | sudo tee --append $dnsmasq_conf > /dev/null"
        #done

        ## no-resolv stops dnsmasq from reading /etc/resolv.conf, and makes it only rely on servers defined in $dnsmasq_conf
        #if ! grep -Fxq 'no-resolv' "$dnsmasq_conf"; then
            #exe "echo no-resolv | sudo tee --append $dnsmasq_conf > /dev/null"
        #fi
    #fi
}


# verify the hosts: line has the ordering we'd expect
#
# note https://manpages.debian.org/testing/libnss-myhostname/nss-myhostname.8.en.html states:
# > It is recommended to place "myhostname" after "files" and before "dns"
setup_nsswitch() {
    local conf target

    conf='/etc/nsswitch.conf'
    target='hosts:          files resolve [!UNAVAIL=return] myhostname dns'

    if ! grep -qFx "$target" "$conf"; then
        err "[$conf] hosts: line needs fixing!!!"
    fi
}

# https://wiki.debian.org/NetworkManager
#
# puts networkManager to manage our network interfaces;
# alternatively, you can remove your interface name from /etc/network/interfaces
# (bottom) line; eg from 'iface wlan0 inet dhcp' to 'iface inet dhcp'
#
# see also: systemd-networkd - possilby will replace NM in the future in Debian!
# see also: https://wiki.debian.org/Netplan - write declarative network config for
#                                             various backends such as NM or systemd-networkd
# jut fyi, now there's also $ nmtui  command for manual interaction
enable_network_manager() {
    local nm_conf nm_conf_dir

    readonly nm_conf="$COMMON_DOTFILES/backups/networkmanager.conf"
    readonly nm_conf_dir='/etc/NetworkManager/conf.d'

    # configure per-connection DNS:
    _configure_con_dns() {
        local network_names i

        network_names=(wifibox wifibox5g home-dock)  # networks to configure DNS for; for wifi this will likely be the SSID unless changed
        check_progs_installed  nmcli || return 1
        for i in "${network_names[@]}"; do
            if nmcli -f NAME connection show | grep -qFw "$i"; then  # verify connection has been set up/exists
                exe "nmcli con mod $i ipv4.dns '$SERVER_IP  1.1.1.1  8.8.8.8'" || err "dns addition for connection [$i] failed w/ $?"
                exe "nmcli con mod $i ipv4.ignore-auto-dns yes" || err "setting dns ignore-auto-dns for connection [$i] failed w/ $?"
            else
                err "NM connection [$i] does not exist; either create it or remove from install script"
            fi
            # TODO: look also into 'trust-ad' & 'rotate' options, eg
            #    nmcli connection modify ethernet-enp1s0 ipv4.dns-options trust-ad,rotate
            # also, one possilbe /etc/resolv.conf contents; especially those 'options' sound like something we want!:
            #    nameserver 127.0.0.1
            #    options timeout:1
            #    options single-request
            #
            # TODO2: look into modifying /etc/nsswitch.conf to make sure 'resolve' precedes 'dns' in the "hosts:" line;
            #        note for that setup we should sunset dnsmasq; also setting dnsstublistener=no makes no sense in that case!
            # TODO3: disable systemd-resolved stub listener via 'DNSStubListener=no', _if_ unsing dnsmasq.
            # TODO4: consider disabling ipv6 for faster queries:   $ sysctl -w net.ipv6.conf.all.disable_ipv6=1
        done

        # make resolv.conf immutable (see https://wiki.archlinux.org/title/Domain_name_resolution#Overwriting_of_/etc/resolv.conf)
        # chattr +i /etc/resolv.conf
    }

    is_d -m 'are you using NetworkManager? if not, this config logic should be removed' "$nm_conf_dir" || return 1
    is_f -nm 'cannot update config' "$nm_conf" || return 1
    exe "sudo install -m644 -C '$nm_conf' '$nm_conf_dir'" || { err "installing [$nm_conf] to [$nm_conf_dir] failed w/ $?"; return 1; }
    _configure_con_dns

    # old ver, directly updating /etc/NetworkManager/NetworkManager.conf:
    #sudo crudini --merge "$net_manager_conf_file" <<'EOF'
#[ifupdown]
#managed=true

#[main]
#dns=default
#rc-manager=resolvconf
#EOF
    #[[ $? -ne 0 ]] && { err "updating [$net_manager_conf_file] exited w/ failure"; return 1; }
}


# https://github.com/numixproject/numix-gtk-theme
#
# consider also numix-gtk-theme & numix-icon-theme straight from the repo
#
# another themes to consider: flatabolous (https://github.com/anmoljagetia/Flatabulous)  (hosts also flat icons);
#                             ultra-flat (https://www.gnome-look.org/content/show.php/Ultra-Flat?content=167473)
install_gtk_numix() {
    local theme_repo tmpdir ver

    readonly theme_repo='https://github.com/numixproject/numix-gtk-theme.git'

    ver="$(get_git_sha "$theme_repo")" || return 1
    is_installed "$ver" numix-gtk-theme && return 2

    check_progs_installed  glib-compile-schemas  gdk-pixbuf-pixdata || { err "those need to be on path for numix build to succeed."; return 1; }

    report "installing numix build dependencies..."
    rb_install sass || return 1

    tmpdir="$TMP_DIR/numix-theme-build-${RANDOM}"
    exe "git clone ${GIT_OPTS[*]} $theme_repo $tmpdir" || return 1
    exe "pushd $tmpdir" || return 1
    exe "make" || { err; popd; return 1; }

    create_deb_install_and_store numix || { popd; return 1; }

    exe "popd"
    exe "sudo rm -rf -- '$tmpdir'"

    add_to_dl_log  numix-gtk-theme "$ver"

    return 0
}


# https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme
install_gruvbox_gtk_theme() {
    install_block 'gtk2-engines-murrine gnome-themes-extra sassc'

    clone_or_pull_repo "Fausto-Korpsvart" "Gruvbox-GTK-Theme" "$BASE_PROGS_DIR"
    exe "$BASE_PROGS_DIR/Gruvbox-GTK-Theme/themes/install.sh" || err "gruvbox theme installation failed w/ $?"  # TODO: sandbox! needs write access only to ~/.themes
}


# https://github.com/TheGreatMcPain/gruvbox-material-gtk
install_gruvbox_material_gtk_theme() {
    err 'not implemented'
    true  # TODO
}


# https://veracrypt.io/en/Downloads.html
# also consider the generic installer instead of .deb, eg https://launchpad.net/veracrypt/trunk/1.24-update7/+download/veracrypt-1.24-Update7-setup.tar.bz2
# see also:
# - https://github.com/FiloSottile/age
install_veracrypt() {
    local url

    # we want GUI version, not console:
    url="$(resolve_dl_urls -SE 'console' 'https://veracrypt.fr/en/Downloads.html' '.*Debian-\d+-amd64.deb')" || return 1
    install_from_url veracrypt "$url"
}


# https://github.com/hectorm/hblock
install_hblock() {
    #install_from_git -T -N hblock -n hblock -f 'text/x-shellscript' hectorm/hblock
    install_from_url  hblock 'https://raw.githubusercontent.com/hectorm/hblock/master/hblock'
}


# estonian ID card soft; tags: digidoc, id-kaart, id kaart, id card, id-card
# based on script @ https://github.com/open-eid/linux-installer/blob/master/install-open-eid.sh
#
# test browser webeid auth @ https://web-eid.eu/
#
# note our setup logic configures apt repo
# note digidoc4 client executable is likely `qdigidoc4`
install_open_eid() {
    install_block -f 'opensc  open-eid' || return 1

    # Configure Chrome/Firefox PKCS11 driver for current user, /etc/xdg/autstart/ will init other users on next logon
    exe '/usr/bin/pkcs11-register --skip-chrome=off --skip-firefox=off'
}


# https://www.binance.com/en/download
install_binance() {
    install_from_url  binance 'https://ftp.binance.com/electron-desktop/linux/production/binance-amd64-linux.deb'
}


# https://electrum.org/#download
# https://github.com/spesmilo/electrum
# - old reddit post w/ recommended wallets: https://www.reddit.com/r/Bitcoin/comments/f6ahfx/best_mobile_wallets_for_btc_non_kyc_preferred/fi4i9t4/
install_electrum_wallet() {
    install_from_any  electrum 'https://electrum.org/#download' \
        'https://download\.electrum\.org/[0-9.]+/electrum-[0-9.]+-x86_64.AppImage'
}


install_revanced() {
    local d
    d="$BASE_PROGS_DIR/revanced"
    ensure_d "$d" || return 1

    install_bin_from_git -A -N revanced.jar -d "$d"  ReVanced/revanced-cli 'all.jar'
    install_bin_from_git -A -N patches.rvp  -d "$d"  ReVanced/revanced-patches  'patches-.*.rvp'
}


install_apkeditor() {
    local d
    d="$BASE_PROGS_DIR/apkeditor"
    ensure_d "$d" || return 1

    install_bin_from_git -A -N apkeditor.jar -d "$d"  REAndroid/APKEditor 'APKEditor-.*.jar'
}


# note this gives us sdkmanager that can be used to install whatever else;
# see  $ sdkmanager --list     for avail/installed packages
#
# ! note we have some env vars that are bound to our installation path !
install_android_command_line_tools() {
    local target

    target="$BASE_PROGS_DIR/android"
    ensure_d "$target" || return 1

    install_from_any -D -d "$target" -I android-command-line-tools  cmdline-tools \
        'https://developer.android.com/studio#command-line-tools-only' \
        'commandlinetools-linux-[0-9]+_latest.zip'
}


# https://github.com/schollz/croc
# share files between computers/phones
install_croc() {
    install_bin_from_git -N croc -n croc  schollz/croc  '_Linux-64bit.tar.gz'
}


# https://github.com/ventoy/Ventoy
install_ventoy() {
    install_from_git -D -d "$BASE_PROGS_DIR" -N ventoy  ventoy/Ventoy '-linux.tar.gz' || return 1
}


# configure internal ntp servers, if access to public ones is blocked;
configure_ntp_for_work() {
    local conf servers i

    [[ "$PROFILE" != work ]] && return

    readonly conf='/etc/ntp.conf'
    declare -ar servers=('server gibntp01.prod.williamhill.plc'
                         'server gibntp02.prod.williamhill.plc'
                        )

    is_f -m 'is ntp installed?' "$conf" || return 1

    for i in "${servers[@]}"; do
        if ! grep -qFx "$i" "$conf"; then
            report "adding [$i] to $conf"
            exe "echo $i | sudo tee --append $conf > /dev/null"
        fi
    done
}


_init_seafile_cli() {
    local ccnet_conf parent_dir

    readonly ccnet_conf="$HOME/.ccnet"
    readonly parent_dir="$BASE_DATA_DIR"

    is_d "$parent_dir" || return 1
    [[ -f "$ccnet_conf/seafile.ini" && -d "$(cat "$ccnet_conf/seafile.ini")" ]] && return 0  # everything seems set, no need to init

    check_progs_installed  seaf-cli || return 1
    seaf-cli init -c "$ccnet_conf" -d "$parent_dir" || { err "[seaf-cli init] failed w/ $?"; return 1; }
}


# https://help.seafile.com/syncing_client/linux-cli/
#
# this is only to be invoked manually.
# note the client daemon needs to be running _prior_ to downloading the libraries.
#
# This function should leave us with a situation where
#  - $BASE_DATA_DIR/seafile/       contains our library directories
#  - $BASE_DATA_DIR/seafile-data/  contains seafile's own metadata (we don't interact with ourselves)
#
# useful commands:
#  - seaf-cli list [--json]  -> info about synced libraries
#  - seaf-cli list-remote
#  - seaf-cli status  -> see download/sync status of libraries
#  - seaf-cli desync -d /path/to/local/library  -> desync with server
setup_seafile() {
    local ccnet_conf parent_dir libs lib user passwd libs_conf

    readonly ccnet_conf="$HOME/.ccnet"
    readonly parent_dir="$BASE_DATA_DIR/seafile"  # where libraries will be downloaded into

    is_noninteractive && { err "do not exec $FUNCNAME() in non-interactive mode"; return 1; }
    _init_seafile_cli || return 1

    if ! is_proc_running seaf-daemon; then
        err "seafile daemon not running, abort"; return 1
    elif __is_work && ! confirm "continue w/ downloading libs on work machine?"; then
        return 1
    fi

    # filter out libs we've already synced with:
    IFS=, read -ra libs_conf <<< "$SEAFILE_LIBS"
    [[ "${#libs_conf[@]}" -eq 0 ]] && err "env var SEAFILE_LIBS is empty - misconfiguration?"  # sanity
    for lib in "${libs_conf[@]}"; do
        [[ -d "$parent_dir/$lib" ]] || libs+=("$lib")
    done

    select_items -h 'choose libraries to sync' "${libs[@]}" || return

    for lib in "${__SELECTED_ITEMS[@]}"; do
        [[ -z "$user" ]] && read -r -p 'enter seafile user (should be mail): ' user
        [[ -z "$passwd" ]] && read -r -p 'enter seafile pass: ' passwd
        [[ -z "$user" || -z "$passwd" ]] && { err "user and/or pass were not given"; return 1; }

        seaf-cli download-by-name --libraryname "$lib" -s 'https://seafile.aliste.eu' \
            -d "$parent_dir" -u "$user" -p "$passwd" || { err "[seaf-cli download-by-name] for lib [$lib] failed w/ $?"; continue; }
    done
}


# https://wiki.debian.org/nftables
# DO NOT edit our nftable rules, instead do it via firewalld
#
# see also:
# - https://www.naturalborncoder.com/2024/10/installing-and-configuring-nftables-on-debian/
#
# config file @ /etc/nftables.conf
#
# some commands:
# - list ruleset:
#    sudo nft list ruleset
enable_fw() {
    exe 'sudo systemctl enable nftables.service'
}


# https://docs.mopidy.com/en/latest/running/service/#running-as-a-service
#
# - print effective config:
#     sudo mopidyctl config
#
# !note when running as a service, then 'mopidy cmd' should be ran as 'sudo mopidyctl cmd'
setup_mopidy() {
    local mopidy_confdir file

    readonly mopidy_confdir='/etc/mopidy'
    readonly file="$COMMON_PRIVATE_DOTFILES/backups/mopidy.conf"  # note filename needs to match that of original/destination

    is_d -m 'is mopidy installed?' "$mopidy_confdir" || return 1
    is_f -m "won't install it" "$file" || return 1

    exe "sudo install -m644 -C '$file' '$mopidy_confdir'" || { err "installing [$file] failed w/ $?"; return 1; }
    # when mopidy is ran as a service, the config file needs to be owned by mopidy user:
    exe "sudo chown mopidy:root $mopidy_confdir/mopidy.conf" || return 1

    exe "sudo systemctl enable --now mopidy"  # note --now flag effectively also starts the service immediately
    exe 'sudo mopidyctl local scan'     # update mopidy library;
}


# - change DefaultAuthType to None, so printer configuration wouldn't require basic auth;
# - add our user to necessary group (most likely 'lpadmin') so we can add/delete printers;
#
# cups web interface @ http://localhost:631/
# note our configured printers are stored in /etc/cups/printers.conf  !
#
# see also https://github.com/openprinting/cups
# - it also demos the lpadmin command usage
install_setup_printing_cups() {
    local conf_file conf2 group pkgs

    readonly conf_file='/etc/cups/cupsd.conf'  # TODO: there's also cupsctl command to configure this file
    readonly conf2='/etc/cups/cups-files.conf'

    is_native || confirm "we're not native, sure you want to install printing stack?" || return

    pkgs=(
        cups
        cups-browsed  # a daemon which browses the Bonjour broadcasts of shared remote CUPS printers and makes the printers available locally; has had security flaws in the past...
        cups-filters  # provides additional CUPS filters which are not provided by the CUPS project itself. This includes filters for a PDF based printing workflow
        ipp-usb  # userland driver for USB devices (printers, scanners, MFC), supporting the IPP over USB protocol; https://github.com/OpenPrinting/ipp-usb
        system-config-printer  # graphical interface to configure the printing system; https://github.com/OpenPrinting/system-config-printer
        #avahi-utils  # allows programs to publish and discover services and hosts running on a local network with no specific configuration. For example you can plug into a network and instantly find printers to print to
    )

    install_block "${pkgs[*]}" || return 1

    [[ -f "$conf_file" ]] || { err "cannot configure cupsd: [$conf_file] does not exist; abort;"; return 1; }

    # this bit (auth change/disabling) comes likely from https://serverfault.com/a/800901 or https://askubuntu.com/a/1142110
    if ! grep -q 'DefaultAuthType' "$conf_file"; then
        err "[$conf_file] does not contain [DefaultAuthType], see what's what"
        return 1
    elif ! grep -Eq '^DefaultAuthType\s+None' "$conf_file"; then  # hasn't been changed yet
        exe "sudo sed -i --follow-symlinks 's/^DefaultAuthType/#DefaultAuthType/g' $conf_file"  # comment out existing value
        exe "echo 'DefaultAuthType None' | sudo tee --append '$conf_file' > /dev/null"
        exe 'sudo service cups restart'
    fi

    # TODO: maybe deprecate this block, think the group is always 'lpadmin'
    # add our user to a group so we're allowed to modify printers & whatnot: {{{
    #   see https://unix.stackexchange.com/a/513983/47501
    #   and https://ro-che.info/articles/2016-07-08-debugging-cups-forbidden-error
    [[ -f "$conf2" ]] || { err "cannot configure our user for cups: [$conf2] does not exist; abort;"; return 1; }
    group="$(grep ^SystemGroup "$conf2" | awk '{print $NF}')" || { err "grepping group from [$conf2] failed w/ $?"; return 1; }
    is_single "$group" || { err "found SystemGroup in [$conf2] was unexpected: [$group]"; return 1; }
    list_contains "$group" root sys && { err "found cups SystemGroup is [$group] - verify we want to be added to that group"; return 1; }  # failsafe for not adding oursevles to root or sys groups
    add_to_group "$group"
    # }}}
}


# ff & extension configs/customisation
# TODO: conf_dir does not exist during initial full install!
# TODO: consider https://github.com/yokoffing/Betterfox  <-- real cool!
# see also:
# - https://wiki.archlinux.org/title/Firefox/Tweaks
# - https://github.com/artsyfriedchicken/EdgyArc-fr/
# - https://github.com/sainnhe/dotfiles/tree/master/.firefox
# - https://wiki.archlinux.org/title/Firefox/Profile_on_RAM !!!
#   - note this should be in addition to profile-sync-daemon, see https://wiki.archlinux.org/title/Profile-sync-daemon / https://wiki.archlinux.org/title/Firefox/Profile_on_RAM
# - find how to best move cache to RAM; there's Anything-sync-daemon, but not avail in deb repo
setup_firefox() {
    local conf_dir profile

    readonly conf_dir="$HOME/.mozilla/firefox"

    # install tridactyl native messenger:  https://github.com/tridactyl/tridactyl#extra-features
    #                                      https://github.com/tridactyl/native_messenger
    # TODO: do we want this? increases attack surface?
    # TODO 2: does ff in flatpak even support this? note native messaging portal is not working in flatpak as of '25: https://github.com/flatpak/xdg-desktop-portal/issues/655
    exe 'curl -fsSL https://raw.githubusercontent.com/tridactyl/native_messenger/master/installers/install.sh -o /tmp/trinativeinstall.sh && sh /tmp/trinativeinstall.sh master'  # 'master' refers to git ref/tag; can also remove that arg, so latest tag is installed instead.

    # install custom css/styling {  # see also https://github.com/MrOtherGuy/firefox-csshacks
    is_d "$conf_dir" || return 1
    profile="$(find "$conf_dir" -mindepth 1 -maxdepth 1 -type d -name '*default-release')"
    is_d "$profile" || return 1
    ensure_d "$profile/chrome" || return 1
    exe "pushd $profile/chrome" || return 1
    clone_or_pull_repo  MrOtherGuy  firefox-csshacks  './'

    exe popd
    # }

    # !!!!!!!!!!!!!!!! DO NOT MISS THESE !!!!!!!!!!!!!!!!
    # manual edits in about:config :
    # -  toolkit.cosmeticAnimations.enabled -> false   # remove fullscreen animation
    # -  full-screen-api.ignore-widgets -> true        # remove window decorations in non-fullscreen; note it still requires F11 toggle!
    # - change these 2 pre-existing values to 127.0.0.1:  # TODO: is it really needed? those addresses could already be blocked by hosts?
    #   - toolkit.telemetry.dap_leader
    #   - toolkit.telemetry.dap_helper
    # !!!!!!!!!!!!!!!! DO NOT MISS THESE !!!!!!!!!!!!!!!!
}


# locate / plocate conf
configure_updatedb() {
    local conf paths line i modified

    conf='/etc/updatedb.conf'
    paths=(/mnt /media /var/cache /data/seafile-data "$HOME/.cache")  # paths to be added to PRUNEPATHS definition

    is_btrfs && paths+=("$HOME/.snapshots" /.snapshots)  # */.snapshots are snapper/btrfs location
    is_f -n "$conf" || return 1
    line="$(grep -Po '^PRUNEPATHS="\K.*(?="$)' "$conf")"  # extract the value between quotes

    for i in "${paths[@]}"; do
        [[ "$line" =~ ([[:space:]]|^)"$i"([[:space:]]|$) ]] && continue  # path already included
        line+="${line:+ }$i"
        modified=TRUE
    done

    if [[ -n "$modified" ]]; then
        [[ -s "$conf" ]] && exe "sudo sed -i --follow-symlinks '/^PRUNEPATHS=.*$/d' '$conf'"  # nuke previous setting
        exe "echo 'PRUNEPATHS=\"$line\"' | sudo tee --append $conf > /dev/null"
    fi
}


# add our USER to given group, if not already in it
add_to_group() {
    local group
    readonly group="$1"

    if ! id -Gn "$USER" | grep -Eq "\b${group}\b"; then
        exe "sudo adduser $USER $group" || return $?
    fi
}


add_group() {
    # note exit 9 means group exists
    exe -c 0,9 "sudo groupadd $1" || return $?
}


add_user() {
    local user groups
    user="$1"
    groups="$2"  # optional; additional groups to add user to, comma-separated

    if ! id -- "$user" 2>/dev/null; then
        # note useradd exits w/ 9 just like groupadd if target already exists
        exe "sudo useradd --no-create-home ${groups:+--groups $groups }--shell /bin/false --user-group $user" || return $?
    fi
    return 0
}


# do not disable swap, read https://chrisdown.name/2018/01/02/in-defence-of-swap.html
# - atop in logging mode can also show you which applications are having their pages swapped out in the SWAPSZ column
#
# Also note there are userspace OOM killers to help system not hand on memory exhaustion. e.g.:
# - https://github.com/facebookincubator/oomd
# - https://github.com/hakavlad/nohang
# - https://man7.org/linux/man-pages/man8/systemd-oomd.service.8.html
#
# NOTE: as of '25, we just install systemd-zram-generator that configures us a zram
setup_swappiness() {
    local target current

    readonly target=100  # on spinning disks you'd want to set this lower; believe kernel default is 60
    current="$(cat -- /proc/sys/vm/swappiness)"
    is_digit "$current" || { err "couldn't find current swappiness value, not a digit: [$current]"; return 1; }
    [[ "$target" -eq "$current" ]] && return 0

    _sysctl_conf '50-swappiness.conf' 'vm.swappiness' "$target"
}


# configs & settings that can/need to be installed  AFTER  the related programs have
# been installed.
#
# note that this block overlaps logically a bit with setup_config_files() (though
# that function should contain configuration that doesn't depend on some programs
# being installed beforehand; also, should be mostly dependent on config files being
# pulled with homesick);
post_install_progs_setup() {

    is_native && install_acpi_events   # has to be after install_progs(), so acpid is already insalled and events/ dir present;
    enable_network_manager
    is_native && install_nm_dispatchers  # has to come after install_progs; otherwise NM wrapper dir won't be present  # TODO: do we want to install these only on native systems?
    #is_native && exe -i "sudo alsactl init"  # TODO: cannot be done after reboot and/or xsession.
    #is_native && setup_mopidy
    is_native && exe 'sudo sensors-detect --auto'   # answer enter for default values (this is lm-sensors config)
    is_pkg_installed 'command-not-found' && exe 'sudo apt-file update && sudo update-command-not-found'
    increase_inotify_watches_limit         # for intellij IDEA
    allow_user_run_dmesg
    #increase_ulimit
    #enable_unprivileged_containers_for_regular_users
    setup_tcpdump
    setup_nvim
    #setup_keyd
    is_native && add_to_group wireshark               # add user to wireshark group, so it could be run as non-root;
                                                # (implies wireshark is installed with allowing non-root users
                                                # to capture packets - it asks this during installation); see https://github.com/wireshark/wireshark/blob/master/packaging/debian/README.Debian
                                                # if wireshark is installed manually/interactively, then installer asks whether
                                                # non-root users should be allowed to dump packets; this can later be reconfigured
                                                # by running  $ sudo dpkg-reconfigure wireshark-common
                                                # TODO: in order to avoid this extra step, see how to preseed debconf database.
                                                # basically: install manually, then extract debconf stuff: $debconf-get-selections | grep wireshark
                                                # then before auto-install, set it via :$ echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
                                                # see also https://unix.stackexchange.com/a/96227
                                                # note debconf-get-selections is provided by debconf-utils pkg;

    #exe "newgrp wireshark"                  # log us into the new group; !! will stop script execution
    is_native && is_pkg_installed virtualbox && add_to_group vboxusers   # add user to vboxusers group (to be able to pass usb devices for instance); (https://wiki.archlinux.org/index.php/VirtualBox#Add_usernames_to_the_vboxusers_group)
    is_virtualbox && add_to_group vboxsf  # add user to vboxsf group (to be able to access mounted shared folders);
    #exe "newgrp vboxusers"                  # log us into the new group; !! will stop script execution
    #configure_ntp_for_work  # TODO: confirm if ntp needed in WSL
    is_native && enable_fw
    setup_nsswitch
    #add_to_group fuse  # not needed anymore?
    setup_firefox
    configure_updatedb
    is_secure_boot && setup_mok  # otherwise e.g. dkms dirs won't be there
}


install_ssh_server_or_client() {
    while true; do
        select_items -s -h 'installing ssh. what do you want to do' client-side server-side

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            break
        else
            confirm "no items were selected; exit?" && return || continue
        fi
    done

    case "$__SELECTED_ITEMS" in
        'server-side' ) install_ssh_server ;;
        'client-side' ) install_sshfs ;;
    esac
}


install_nfs_server_or_client() {
    while true; do
        select_items -s -h 'installing nfs. what do you want to do' client-side server-side

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            break
        else
            confirm "no items were selected; exit?" && return || continue
        fi
    done

    case "$__SELECTED_ITEMS" in
        'server-side' ) install_nfs_server ;;
        'client-side' ) install_nfs_client ;;
    esac
}

add_to_dl_log() {
    local id url

    id="$1"
    url="$2"

    [[ -s "$GIT_RLS_LOG" ]] && sed --follow-symlinks -i "/^$id:/d" "$GIT_RLS_LOG"
    echo -e "${id}:\t$url\t$(date +'%d %b %Y %R')" >> "$GIT_RLS_LOG"
}


is_installed() {
    local ver name

    ver="$1"
    name="$2"  # optional, just for better logging

    [[ -z "$ver" ]] && { err "empty ver passed to ${FUNCNAME}()" -1; return 2; }  # sanity
    if grep -Fq "$ver" "$GIT_RLS_LOG" 2>/dev/null; then
        report "[${COLORS[GREEN]}$ver${COLORS[OFF]}] already processed, skipping ${name:+${COLORS[YELLOW]}$name${COLORS[OFF]} }installation..." -1
        return 0
    fi

    return 1
}


is_pkg_installed() {
    apt list -qq --installed "$*" | grep -q .
}


# Fetch last/latest tag of given git repo.
# from https://stackoverflow.com/a/12704727/1803648
#
# @param {string}  url  git repo url
#
# @returns {string} last git tag
# @returns {bool} false if anything went wrong
get_git_tag() {
    local repo tag
    repo="$1"

    tag="$(git -c 'versionsort.suffix=-' \
        ls-remote --exit-code --refs --sort='version:refname' --tags "$repo" '*.*.*' \
        | tail --lines=1 \
        | cut --delimiter='/' --fields=3)"
    if [[ "$?" -ne 0 ]] || ! is_single "$tag"; then
        err "fetching [$repo] latest tag failed"
        return 1
    fi

    echo -n "$tag"
}

# Fetch the sha of HEAD of given git repo.
#
# @param {string}  url  git repo url
#
# @returns {string} url's HEAD git sha
# @returns {bool} false if anything went wrong
get_git_sha() {
    local repo sha

    repo="$1"

    [[ -z "$repo" ]] && { err "no repo url provided"; return 1; }
    sha="$(git ls-remote --exit-code "$repo" HEAD | cut -f1)"
    if [[ "$?" -ne 0 ]] || ! is_single "$sha"; then
        err "fetching [$repo] HEAD sha failed"
        return 1
    fi

    echo -n "$sha"
}

###################
# UTILS (contains no setup-related logic)
###################

confirm() {
    local msg yno opt OPTIND default timeout

    timeout=2  # default
    while getopts 'd:t:' opt; do
        case "$opt" in
           d) default="$OPTARG" ;;
           t) timeout="$OPTARG" ;;
           *) print_usage; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly msg=${1:+"\n$1"}

    while true; do
        [[ -n "$msg" ]] && >&2 echo -e "$msg"

        if is_noninteractive; then
            read -r -t "$timeout" yno
            if [[ $? -gt 128 ]]; then yno="$default"; fi  # read timed out
        else
            read -r yno
        fi

        case "$(tr '[:lower:]' '[:upper:]' <<< "$yno")" in
            Y | YES )
                report "Ok, continuing..." "->";
                return 0 ;;
            N | NO )
                >&2 echo "Abort.";
                return 1 ;;
            *)  err "incorrect answer; try again. (y/n accepted)" "->" ;;
        esac
    done
}


fail() {
    local msg caller_name

    readonly msg="$1"
    caller_name="$2"  # OPTIONAL

    if [[ -z "$caller_name" || "$caller_name" =~ ^-[0-9]+$ ]]; then
        local stack=1
        [[ -n "$caller_name" ]] && let stack+=${caller_name:1}
        caller_name="$(funname "$stack")"
        [[ -n "$caller_name" ]] && caller_name="fail @ $caller_name" || caller_name=ERR
    fi

    err "$msg" "$caller_name"  # note caller_name has to be resolved by the time err() is invoked from here
    exit 1
}



err() {
    local msg caller_name

    readonly msg="$1"
    caller_name="$2"  # OPTIONAL

    if [[ -z "$caller_name" || "$caller_name" =~ ^-[0-9]+$ ]]; then
        local stack=1
        [[ -n "$caller_name" ]] && let stack+=${caller_name:1}
        caller_name="$(funname "$stack")"
    fi

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "    ERR LOG: ${caller_name:+[$caller_name]: }$msg" >> "$EXECUTION_LOG"
    echo -e "${COLORS[RED]}${caller_name:-ERR}:${COLORS[OFF]} ${msg:-Abort}" 1>&2
}


report() {
    local msg caller_name

    readonly msg="$1"
    caller_name="$2"  # OPTIONAL

    if [[ -z "$caller_name" || "$caller_name" =~ ^-[0-9]+$ ]]; then
        local stack=1
        [[ -n "$caller_name" ]] && let stack+=${caller_name:1}
        caller_name="$(funname "$stack")"
    fi

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "OK LOG: ${caller_name:+[$caller_name]: }$msg" >> "$EXECUTION_LOG"
    >&2 echo -e "${COLORS[YELLOW]}${caller_name:-INFO}:${COLORS[OFF]} ${msg:-"--info lvl message placeholder--"}"
}


# this is to avoid the warning apt prints when installing:
# > Download is performed unsandboxed as root...
#
# see https://askubuntu.com/a/908825
# see https://unix.stackexchange.com/questions/468807/strange-error-in-apt-get-download-bug
# TODO: consider removing
sanitize_apt() {
    local target

    target="$1"

    if ! [[ -e "$target" ]]; then
        err "tried to sanitize [$target] for apt, but it doesn't exist"
        return 1
    fi

    exe "sudo chown -R _apt:root '$target'"
    exe "sudo chmod -R 700 '$target'"
}


_sanitize_ssh() {
    is_d -m "cannot sanitize it" "$HOME/.ssh" || return 1
    find -L "$HOME/.ssh/" -maxdepth 25 \( -type f -o -type d \) -exec chmod 'u=rwX,g=,o=' -- '{}' \+
}


is_ssh_key_available() {
    [[ -f "$PRIVATE_KEY_LOC" ]]
}


# Check whether the client is connected to the internet
check_connection() {
    local timeout ip

    readonly timeout=3  # in seconds
    readonly ip='http://www.google.com'

    wget --no-check-certificate -q --user-agent="$USER_AGENT" --spider \
        --timeout=$timeout -- "$ip" > /dev/null 2>&1  # works in networks where ping is not allowed
}


# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
# or: https://support.atlassian.com/bitbucket-cloud/docs/set-up-personal-ssh-keys-on-linux/
generate_ssh_key() {
    local mail valid_mail_regex

    readonly valid_mail_regex='^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$'

    if is_ssh_key_available; then
        confirm -d N "key @ [$PRIVATE_KEY_LOC] already exists; still generate key?" || return 1
    fi

    if ! command -v ssh-keygen >/dev/null; then
        err "ssh-keygen is not installed; won't generate ssh key."
        return 1
    fi

    report "generating ssh key..."
    while ! [[ "$mail" =~ $valid_mail_regex ]]; do
        report "enter your (valid) mail (eg [username@server.com]):"
        read -r mail
    done

    #exe "ssh-keygen -t rsa -b 4096 -C '$mail' -f '$PRIVATE_KEY_LOC'"  # legacy for RSA
    exe "ssh-keygen -t ed25519 -C '$mail' -f '$PRIVATE_KEY_LOC'"
}


# required for common point of logging and exception catching.
#
#  -i       ignore erroneous exit - in this case still exits 0 and doesn't log
#           on ERR level to exec logfile
#  -c code  provide value of successful exit code (defaults to 0); may be comma-separated
#           list of values if multiple exit codes are to be considered a success.
#  -r       return the original return code in order to catch the code even when
#           -c <code> or -i options were passed
#  -s       silent stdout - do not print
exe() {
    local opt OPTIND cmd exit_sig ignore_errs retain_code silent ok_code ok_codes

    ok_codes=(0)  # default
    while getopts 'irsc:' opt; do
        case "$opt" in
           i) ignore_errs=1 ;;
           r) retain_code=1 ;;
           s) silent=1 ;;
           c) IFS=',' read -ra ok_codes <<< "$OPTARG"
              for ok_code in "${ok_codes[@]}"; do
                is_digit "$ok_code" || { err "non-digit ok_code arg passed to ${FUNCNAME}: [$ok_code]"; return 1; }
                [[ "${#ok_code}" -gt 3 ]] && { err "too long ok_code arg passed to ${FUNCNAME}: [$ok_code]"; return 1; }
              done
                ;;
           *) err "unexpected opt [$opt] passed to $FUNCNAME"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly cmd="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$1")"  # trim leading-trailing whitespace

    [[ -z "$silent" ]] && >&2 echo -e "${COLORS[GREEN]}-->${COLORS[OFF]} exe [${COLORS[YELLOW]}${cmd}${COLORS[OFF]}]"
    # TODO: collect and log command execution stderr?
    eval "$cmd"
    readonly exit_sig=$?

    if [[ "$ignore_errs" != 1 ]] && ! list_contains "$exit_sig" "${ok_codes[@]}"; then
        if [[ "$LOGGING_LVL" -ge 1 ]]; then
            echo -e "    ERR CMD: [$cmd] (exit code [$exit_sig])" >> "$EXECUTION_LOG"
            echo -e "        LOC: [$(pwd -P)]" >> "$EXECUTION_LOG"
        fi

        err "command exited w/ [$exit_sig]"
        return $exit_sig
    fi

    [[ "$LOGGING_LVL" -ge 10 ]] && echo "OK CMD: $cmd" >> "$EXECUTION_LOG"
    [[ "$retain_code" == 1 ]] && return $exit_sig || return 0
}


# Provides an interface user can select items with.
#
# Opts:
#    s - force single item selection; by default multiples can be selected;
#    h - header/topic to print next to list of options to choose from;
#
# @param {string...}     options  list of options user can choose from.
#
# @returns {bool}  false if no items were selected or single empty selection was passed.
#                  doesn't return selected values, but defines global __SELECTED_ITEMS
#                  array that contains list of user selected items.
#
# original version stolen from http://serverfault.com/a/298312
# TODO: instead of bash, use whiptail or dialog, but former preferred
#       e.g.  TERM=ansi whiptail --title "Example Dialog" --infobox "This is an example of an info box" 8 78
select_items() {
    local opt OPTIND options is_single_selection hdr

    hdr='Available options:'  # default

    while getopts 'sh:' opt; do
        case "$opt" in
           s) is_single_selection=1 ;;
           h) hdr="$OPTARG" ;;
           *) echo -e "unexpected opt [$opt] passed to $FUNCNAME"; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    __SELECTED_ITEMS=()  # reset
    declare -a options=("$@")
    [[ "$hdr" != *: ]] && hdr+=':'
    hdr="${COLORS[BLUE]}${COLORS[BOLD]}${hdr}${COLORS[OFF]}"

    if [[ -z "${options[*]}" ]]; then
        return 1
    elif [[ "${#options[@]}" -eq 1 ]]; then
        __SELECTED_ITEMS+=("${options[0]}")
        return 0
    fi

    if command -v fzf > /dev/null 2>&1; then
        local opts out

        opts="$FZF_DEFAULT_OPTS "
        [[ "$is_single_selection" -eq 1 ]] && opts+=' --no-multi ' || opts+=' --multi '

        out="$(printf '%s\n' "${options[@]}" | FZF_DEFAULT_OPTS="$opts" fzf --header "$hdr")" || return 1
        mapfile -t __SELECTED_ITEMS <<< "$out"
    else  # bash-only selection prompt
        local i prompt msg choices num

        declare -a choices

        __menu() {
            local i

            echo -e "\n---------------------"
            echo "$hdr"

            #for i in "${!options[@]}"; do
            for ((i = (( ${#options[@]} - 1 )) ; i >= 0 ; i--)); do
                printf '%3d%s) %s\n' "$((i+1))" "${choices[i]:- }" "${choices[i]:+${COLORS[BOLD]}}${options[i]}${COLORS[OFF]}"
            done
            if [[ "$msg" ]]; then echo "$msg"; fi
        }

        if [[ "$is_single_selection" -eq 1 ]]; then
            readonly prompt="Check an option, only 1 item can be selected (again to uncheck, ENTER when done): "
        else
            readonly prompt="Check an option, multiple items allowed (again to uncheck, ENTER when done): "
        fi

        while __menu && read -rp "$prompt" num && [[ "$num" ]]; do
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#options[@]} )) ||
            { msg="${COLORS[RED]}Invalid option: ${COLORS[BOLD]}${num}${COLORS[OFF]}"; continue; }
            ((num--)); msg="[${COLORS[YELLOW]}${COLORS[BOLD]}${options[num]}${COLORS[OFF]}] was ${choices[num]:+un}checked"

            if [[ "$is_single_selection" -eq 1 ]]; then
                # un-select others to enforce single item only:
                for i in "${!choices[@]}"; do
                    [[ "$i" -ne "$num" ]] && choices[i]=''
                done
            fi

            [[ "${choices[num]}" ]] && choices[num]='' || choices[num]="${COLORS[PURPLE]}${COLORS[BOLD]}>${COLORS[OFF]}"
        done

        # collect the selections:
        for i in "${!options[@]}"; do
            [[ -n "${choices[i]}" ]] && __SELECTED_ITEMS+=( "${options[i]}" )
        done

        unset __menu  # to keep the inner function really an inner one (ie private).
    fi

    [[ "${#__SELECTED_ITEMS[@]}" -eq 0 ]] && return 1 || return 0
}


remove_items_from_list() {
    local orig_list elements_to_remove i j

    [[ "$#" -ne 2 ]] && { err "exactly 2 args required"; return 1; }

    declare -a orig_list=( $1 )
    declare -ar elements_to_remove=( $2 )

    for i in "${!orig_list[@]}"; do
        for j in "${elements_to_remove[@]}"; do
            [[ "$j" == "${orig_list[i]}" ]] && unset orig_list[i]
        done
    done

    echo "${orig_list[*]}"
}


# deprecated by aunpack?
extract() {
    local file

    readonly file="$*"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz."
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "[$file] is not a regular file or read rights not granted."
        return 1
    fi

    case "$file" in
        *.tar.bz2) tar xjf "$file"
                ;;
        *.tar.gz) tar xzf "$file"
                ;;
        *.tar.xz) tar xpvf "$file"
                ;;
        *.bz2) bunzip2 -k -- "$file"
                ;;
        *.rar) unrar x "$file"
                ;;
        *.gz) gunzip -kd -- "$file"
                ;;
        *.tar) tar xf "$file"
                ;;
        *.tbz|*.tbz2) tar xjf "$file"
                ;;
        *.tgz) tar xzf "$file"
                ;;
        *.zip) unzip -- "$file"
                ;;
        *.7z) 7z x -- "$file"
                ;;
        *.Z) uncompress -- "$file"
                ;;
        *) err "'$file' cannot be extracted; this filetype is not supported."
           return 1
                ;;
    esac
}


is_server() {
    [[ "$HOSTNAME" == *'server'* ]]
}


# Checks whether system is a laptop.
#
# @returns {bool}   true if system is a laptop.
is_laptop() {
    local pwr_supply_dir
    readonly pwr_supply_dir="/sys/class/power_supply"

    # sanity:
    is_d -m "cannot decide if we're a laptop; assuming we're not" "$pwr_supply_dir" || return 1

    find "$pwr_supply_dir" -mindepth 1 -maxdepth 1 -name 'BAT*' -print -quit | grep -q .
}


# see https://unix.stackexchange.com/a/630956
#     https://github.com/AppImage/AppImageSpec/blob/master/draft.md#type-2-image-format
is_appimage() {
    local file i

    readonly file="$1"

    [[ $# -ne 1 ]] && { err "exactly 1 argument (node name) required."; return 1; }
    is_f "$file" || return 1
    check_progs_installed  xxd || return 2

    #i="$(xxd "$file" 2>/dev/null | head -1)"   # note likely exits w/ code 3
    i="$(xxd -l 12 -- "$file")"
    #grep -q '^00000000: 7f45 4c46 0201 0100 4149 0200' <<< "$i"    # only verifies appimage type 2 format, i.e. w/ magix hex 0x414902
    grep -q '^00000000: 7f45 4c46 0201 0100 4149 0[12]00' <<< "$i"  # also includes appimage type 1 format, i.e. w/ magic hex 0x414901
}


# Checks whether system is a thinkpad laptop.
#
# @returns {bool}   true if system is a thinkpad laptop.
is_thinkpad() {
    check_progs_installed  dmidecode || return 2
    is_laptop && sudo dmidecode | grep -A3 '^System Information' | grep -Fq 'ThinkPad'
}


# Checks whether system is running in WSL.
#
# @returns {bool}   true if we're running inside Windows.
is_windows() {
    if [[ -z "$_IS_WIN" ]]; then
        is_f -m 'cannot test if windows' /proc/version || return 2
        grep -Eq '[Mm]icrosoft|WSL' /proc/version &>/dev/null
        readonly _IS_WIN=$?
    fi

    return $_IS_WIN
}


# Checks whether system is virtualized (including WSL)
#
# @returns {bool}   true if we're running in virt mode.
is_virt() {
    if [[ -z "$_IS_VIRT" ]]; then
        is_f -m 'cannot test if virtualized' /proc/cpuinfo || return 2
        grep -Eq '^flags.*\s+hypervisor' /proc/cpuinfo &>/dev/null  # detects all virtualizations, including WSL
        readonly _IS_VIRT=$?
    fi

    return $_IS_VIRT
}


# Checks whether system is running in _virtualbox_ (not just in any virtualization)
#
# @returns {bool}   true if we're running in a virtualbox vm
is_virtualbox() {
    if [[ -z "$_IS_VIRTUALBOX" ]]; then
        is_virt && lspci | grep -qi virtualbox
        readonly _IS_VIRTUALBOX=$?
    fi

    return $_IS_VIRTUALBOX
}


# Checks whether we're running native, ie we're not running in
# vbox, hyper-v, wsl et al.
#
# @returns {bool}   true if we're native.
is_native() {
    if [[ -z "$_IS_NATIVE" ]]; then
        ! is_windows && ! is_virt
        readonly _IS_NATIVE=$?
    fi

    return $_IS_NATIVE
}


# whether we're using BTRFS
#
# TODO: depend on fstab or /run/systemd/generator/ contents?
is_btrfs() {
    local fstab='/etc/fstab'
    is_f -n "$fstab" || return 2
    grep -Eq '\bbtrfs\b' "$fstab"
}


is_64_bit() {
    # also could do  $ [[ "$(dpkg --print-architecture)" == amd64 ]]
    [[ "$(uname -m)" == x86_64 ]]
}


is_intel_cpu() {
    is_f /proc/cpuinfo || return 2
    grep -Eiq '^vendor_id.*intel' /proc/cpuinfo
}


is_amd_cpu() {
    is_f /proc/cpuinfo || return 2
    grep -Eq '^vendor_id.*AMD' /proc/cpuinfo
}


# Checks whether we're in a git repository.
#
# @returns {bool}  true, if we are in git repo.
is_git() {
    git rev-parse --is-inside-work-tree &>/dev/null
}


is_archive() {
    file --brief "$1" | grep -Eiq 'archive|compressed'
}


# Checks whether we're in graphical environment.
# TODO: differentiate between x11 & GUI; perhaps is_gui() would be better?
#
# @returns {bool}  true, if we're currently in graphical env.
is_x() {
    local exit_code

    if command -v xset > /dev/null 2>&1; then
        xset q &>/dev/null
        exit_code="$?"
    elif command -v wmctrl > /dev/null 2>&1; then
        wmctrl -m &>/dev/null
        exit_code="$?"
    else
        err "can't check, neither [xset] nor [wmctrl] are installed"
        return 2
    fi

    [[ "$exit_code" -eq 0 && -n "$DISPLAY" ]]
}


# Checks whether given url is a valid url.
#
# @param {string}  url   url which validity to test.
#
# @returns {bool}  true, if provided url was a valid url.
is_valid_url() {
    local regex
    readonly regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
    [[ "$1" =~ $regex ]]
}


# Checks whether given IP is a valid ipv4.
# from https://stackoverflow.com/a/13777424
#
# @param {string}  ip   ip which validity to test.
#
# @returns {bool}  true, if provided IP was a valid ipv4.
is_valid_ip() {
    local ip

    ip="$1"

    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        readarray -t -d '.' ip <<< "$ip"

        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        return $?
    fi

    return 1
}


# did we boot as efi/uefi?
is_efi() {
    [[ -d /sys/firmware/efi ]]
}


# from https://wiki.debian.org/SecureBoot#Has_the_system_booted_via_Secure_Boot.3F
# and https://wiki.debian.org/SecureBoot/VirtualMachine#Checking_if_secure_boot_is_active
is_secure_boot() {
    if command -v mokutil >/dev/null; then
        [[ "$(mokutil --sb-state)" == 'SecureBoot enabled' ]]
    elif command -v bootctl >/dev/null; then
        bootctl 2>/dev/null | grep -Eiq '^\s*secure boot:\s*enabled'
    else
        sudo dmesg | grep -Eiq 'secureboot: secure boot enabled'  # note need to exec as root as allow_user_run_dmesg() has not been set up yet
    fi
}


# pass '-s' as first arg to execute as sudo
# pass '-c' if $1 is a dir whose contents should each be symlinked to directory at $2
#
# second arg, the target, should end with a slash if a containing dir is meant to be
# passed, not a literal path to the link-to-be-created. in this case dir needs to exist,
# it doesn't get automatically created
create_link() {
    local opt OPTIND src srcs node target trgt sudo contents

    while getopts 'sc' opt; do
        case "$opt" in
            s) sudo=sudo ;;
            c) contents=1 ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly src="${1%/}"
    target="$2"

    declare -a srcs
    if [[ "$contents" -eq 1 ]]; then
        [[ -d "$src" ]] || { err "source [$src] should be a dir, but is [$(file_type "$src")]"; return 1; }
        [[ -d "$target" ]] || { err "with -c opt, target [$target] should be a dir, but is [$(file_type "$target")]"; return 1; }
        [[ "$target" != */ ]] && target+='/'

        for node in "$src/"*; do
            srcs+=("$node")
        done
    else
        srcs=("$src")
    fi

    for node in "${srcs[@]}"; do
        if [[ "$target" == */ ]] && $sudo test -d "$target"; then
            trgt="${target}$(basename -- "$node")"
        else
            trgt="$target"
        fi

        $sudo test -h "$trgt" && exe "${sudo:+$sudo }rm -- '$trgt'"  # only remove $trgt if it's already a symlink
        exe "${sudo:+$sudo }ln -s -- '$node' '$trgt'"
    done

    return 0
}


__is_work() {
    list_contains "$HOSTNAME" "$WORK_DESKTOP_HOSTNAME" "$WORK_LAPTOP_HOSTNAME"
}


# Checks whether the element is contained in an array/list.
#
# @param {string}        element to check.
# @param {string...}     string list to check passed element in
#
# @returns {bool}  true if array contains the element.
list_contains() {
    local array element i

    #[[ "$#" -lt 2 ]] && { err "at least 2 args required"; return 1; }

    readonly element="$1"; shift
    declare -ar array=("$@")

    #[[ -z "$element" ]]    && { err "element to check can't be empty string."; return 1; }  # it can!
    #[[ -z "${array[*]}" ]] && { err "array/list to check from can't be empty."; return 1; }  # is this check ok/necessary?

    for i in "${array[@]}"; do
        [[ "$i" == "$element" ]] && return 0
    done

    return 1
}


# Checks whether the passed programs are installed on the system.
#
# @param {string...}   list of programs whose existence to check. NOT a bash array!
#
# @returns {bool}  true if ALL the passed programs are installed.
check_progs_installed() {
    local msg msg_beginning i progs_missing

    declare -a progs_missing

    # Check whether required programs are installed:
    for i in "$@"; do
        if ! cmd_avail "$i"; then
            progs_missing+=("$i")
        fi
    done

    if [[ "${#progs_missing[@]}" -gt 0 ]]; then
        [[ "${#progs_missing[@]}" -eq 1 ]] && readonly msg_beginning="[1] required program appears" || readonly msg_beginning="[${#progs_missing[@]}] required programs appear"
        readonly msg="$msg_beginning not to be installed on the system:\n\t$(build_comma_separated_list "${progs_missing[@]}")\n\nAbort.\n"
        err "$msg"

        return 1
    fi

    return 0
}


# Checks whether a process with the given name is running.
#
# @param   {string}  proc   name of the process to check.
#
# @returns {bool}  true, if the process with given name is running.
is_proc_running() {
    local proc

    readonly proc="$1"

    [[ -z "$proc" ]] && { err "process name not provided! Abort."; return 1; }

    #if pidof "$proc"; then
    pgrep -f -- "$proc" > /dev/null 2>&1  # TODO: add -x flag to search for EXACT commands? also, -f seems like a bad idea, eg is_proc_running 'kala' would return true if file named 'kala' was opened in vim
}


# Checks whether _any_ of the passed programs are installed on the system.
#
# @param {string...}   list of programs whose existence to check. NOT a bash array!
#
# @returns {bool}  true if ANY of the passed programs is installed.
cmd_avail() {
    command -v -- "$@" > /dev/null 2>&1
}


# Retries a command on failure.
#
# @param {digit}  retries  number of retries (if 0, then no retries will be made)
# @param {string...}  cmd  command to run
#
# @returns {bool}  false, if command failed to execute successfully after
#                  given attempts.
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$*"
    local -i attempt_num=1

    until $cmd; do
        if (( attempt_num > max_attempts )); then
            err "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            report "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}


# Builds comma separated list.
# TODO: replaced by join_by()
#
# @param {string...}   list of elements to build string from.
#
# @returns {string}  comma separated list, eg "a, b, c"
build_comma_separated_list() {
    local list="$*"
    echo "${list// /, }"
}


# see https://stackoverflow.com/a/17841619/1803648
join_by() {
    local d=${1-} f=${2-}
    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}


# Copies given text to system clipboard.
#
# @param {string}  input   text to put to the clipboard.
#
# @returns {bool}  true, if copying to clipboard succeeded.
copy_to_clipboard() {
    local input

    readonly input="$1"

    { command -v xsel >/dev/null 2>/dev/null && echo -n "$input" | xsel --clipboard; } \
        || { command -v copyq >/dev/null 2>/dev/null && copyq add "$input" && copyq select 0; } \
        || { command -v xclip >/dev/null 2>/dev/null && echo -n "$input" | xclip -selection clipboard; } \
        || return 1

    return 0
}


# Create links of files in given directory, into antther dir.
#
# @param {string}  src  directory whose contents should be linked to dest
# @param {string}  dest directory where links of files in $src should be created in.
create_symlinks() {
    local src dest

    src="$1"
    dest="$2"

    is_d "$src" "$dest" || return 1

    # Create symlink of every file (note target file will be overwritten no matter what):
    find "$src" -maxdepth 1 -mindepth 1 -type f -printf 'ln -sf -- "%p" "$dest"\n' | dest="$dest" bash
    #find "$src" -maxdepth 1 -mindepth 1 -type f -print | xargs -I '{}' ln -sf -- "{}" "$dest"
}


# Tests whether given directory is empty.
#
# @param {string}  dir   directory whose emptiness to test.
# pass '-s' as first arg to execute as sudo
# TODO: default to _always_ checking dir contents as root?
#
# @returns {bool}  true, if directory IS empty.
is_dir_empty() {
    local opt OPTIND sudo dir

    while getopts 's' opt; do
        case "$opt" in
            s) sudo=sudo ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly dir="$1"

    $sudo test -d "$dir" || { err "[$dir] is not a valid dir" -1; return 2; }
    $sudo find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q . && return 1 || return 0
}


# Checks whether the argument is a non-negative integer.
#
# @param {digit}  arg   argument to check.
#
# @returns {bool}  true if argument is a valid (and non-negative) int.
is_digit() {
    [[ "$*" =~ ^[0-9]+$ ]]
}

# Checks whether the argument is a positive integer.
#
# @param {digit}  arg   argument to check.
#
# @returns {bool}  true if argument is a valid positive digit.
is_positive() {
    is_digit "$*" && [[ "$*" -gt 0 ]]
}


is_noninteractive() {
    [[ "$NON_INTERACTIVE" -eq 1 ]]
}


is_interactive() {
    ! is_noninteractive
}


# Checks whether the provided function name is actually a defined function.
#
# @param {string}   fun     name of the function whose validity to check.
#
# @returns {bool}    true, if provided function name is a valid function.
is_function() {
    local fun _type

    readonly fun="$1"

    _type="$(type -t -- "$fun" 2> /dev/null)"
    [[ "$?" -eq 0 && "$_type" == function ]]
}


funname() {
    local depth="${1:-0}"
    [[ "${#FUNCNAME[@]}" -ge "$((2+depth))" ]] && echo -n "${FUNCNAME[$((1+depth))]}"
}


is_f() {
    local opt nonempty msg quiet OPTIND f e m

    while getopts 'nqm:' opt; do
        case "$opt" in
            n) nonempty=TRUE ;;
            q) quiet=TRUE ;;
            m) msg="$OPTARG" ;;  # additional message to print on failure
            *) fail "unexpected opt [$opt] passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    for f in "$@"; do
        if ! sudo test -f "$f"; then
            [[ -e "$f" ]] && m=" (but it exists, and is [$(file_type "$f")])"
            [[ -z "$quiet" ]] && err "[$f] not a file$m${msg:+; $msg}" -1
            e=1
        elif [[ -n "$nonempty" ]] && ! sudo test -s "$f"; then
            [[ -z "$quiet" ]] && err "[$f] is an empty file${msg:+; $msg}" -1
            e=1
        fi
    done
    return ${e:-0}
}


is_d() {
    local opt nonempty msg quiet OPTIND d e m

    while getopts 'nqm:' opt; do
        case "$opt" in
            n) nonempty=TRUE ;;
            q) quiet=TRUE ;;
            m) msg="$OPTARG" ;;  # additional message to print on failure
            *) fail "unexpected opt [$opt] passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    for d in "$@"; do
        if ! sudo test -d "$d"; then
            [[ -e "$d" ]] && m=" (but it exists, and is [$(file_type "$d")])"
            [[ -z "$quiet" ]] && err "[$d] not a dir$m${msg:+; $msg}" -1
            e=1
        elif [[ -n "$nonempty" ]] && is_dir_empty -s "$d"; then
            [[ -z "$quiet" ]] && err "[$d] is an empty dir${msg:+; $msg}" -1
            e=1
        fi
    done
    return ${e:-0}
}


ensure_d() {
    local opt sudo msg OPTIND d e

    while getopts 's' opt; do
        case "$opt" in
            s) sudo=sudo ;;
            *) fail "unexpected opt [$opt] passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    for d in "$@"; do
        # note we set [umask 2] for root to make sure other group can read&traverse created dir; from https://unix.stackexchange.com/a/132201/47501
        if ! $sudo test -d "$d"; then
            [[ -e "$d" ]] && { err "[$d] exists, but is [$(file_type "$d")]" -1; e=1; continue; }
            exe "(${sudo:+umask 2 && sudo }mkdir -p -- '$d')" || e=1
        fi
    done
    return ${e:-0}
}


mkpushd() {
    local d="$1"
    # or:  exe "mkdir -p -- '$d' && cd '$dir'"
    ensure_d "$d" || return 1
    exe "pushd $d"
}


file_type() {
    if [[ -h "$*" ]]; then
        echo symlink
    elif [[ -f "$*" ]]; then
        echo file
    elif [[ -d "$*" ]]; then
        echo dir
    elif [[ -p "$*" ]]; then
        echo 'named pipe'
    elif [[ -c "$*" ]]; then
        echo 'character special'
    elif [[ -b "$*" ]]; then
        echo 'block special'
    elif [[ -S "$*" ]]; then
        echo socket
    elif ! [[ -e "$*" ]]; then
        echo 'does not exist'
    else
        err "unknown filetype for [$*]?!"
        echo UNKNOWN
    fi
}


mkt() {
    local tmpdir
    if ! tmpdir="$(mktemp -d -p "$TMP_DIR" -- "${1:-.mktemp}.XXXXX")"; then
        err "unable to create tempdir with \$mktemp" -1
        return 1
    fi
    printf '%s' "$tmpdir"
}


# Verifies given string is non-empty, non-whitespace-only and on a single line.
#
# @param {string}  s  string to validate.
#
# @returns {bool}  true, if passed string is non-empty, and on a single line.
is_single() {
    local s

    s="$(tr -d '[:blank:]' <<< "$*")"  # make sure not to strip newlines!
    [[ -n "$s" && "$(wc -l <<< "$s")" -eq 1 ]]
}

pushd() {
    command pushd "$@" > /dev/null
}

popd() {
    command popd > /dev/null
}


cleanup() {
    [[ "$__CLEANUP_EXECUTED_MARKER" == 1 || -z "$MODE" ]] && return  # don't invoke more than once.

    [[ -s "$NPMRC_BAK" ]] && mv -- "$NPMRC_BAK" ~/.npmrc   # move back

    if [[ -d "$ZSH_COMPLETIONS" && "$ZSH_COMPLETIONS" == /usr/* ]]; then
        exe -s "sudo chmod -R 'o+r' '$ZSH_COMPLETIONS'"  # ensure 'other' group has read rights
    fi

    # shut down the build container:
    if command -v docker >/dev/null 2>&1 && [[ -n "$(docker ps -qa -f status=running -f name="$BUILD_DOCK")" ]]; then
        exe "docker stop '$BUILD_DOCK'" || err "[cleanup] stopping build container [$BUILD_DOCK] failed"
    fi

    if [[ -e "$EXECUTION_LOG" ]]; then
        sed -i --follow-symlinks '/^\s*$/d' "$EXECUTION_LOG"  # strip empty lines

        echo -e "\n\n___________________________________________"
        echo -e "    script execution log can be found at [$EXECUTION_LOG]"
        grep -qF '    ERR' "$EXECUTION_LOG" && echo -en "${COLORS[RED]}    NOTE: log contains errors.${COLORS[OFF]}  "
        copy_to_clipboard "$EXECUTION_LOG" && echo -e '(logfile location has been copied to clipboard)'
        echo -e "___________________________________________"
    fi

    readonly __CLEANUP_EXECUTED_MARKER=1  # states cleanup() has been invoked;
}


#----------------------------
#---  Script entry point  ---
#----------------------------
ORIG_OPTS="$@"
while getopts 'NFSUQOP:L:T:h' OPT; do
    case "$OPT" in
        N) NON_INTERACTIVE=1 ;;
        F) MODE=1 ;;  # full install
        S) MODE=0 ;;  # single task
        U) MODE=2 ;;  # update/quick_refresh
        Q) MODE=3 ;;  # even faster update/quick_refresh
        O) ALLOW_OFFLINE=1 ;;  # allow running offline
        P) PLATFORM="$OPTARG" ;;  # force the platform-specific config to install (as opposed to deriving it from hostname);
                                  # best not use it and let platform be resolved from our hostname
        L) LOGGING_LVL="$OPTARG"
           is_digit "$OPTARG" || fail "log level needs to be an int, but was [$OPTARG]"
            ;;
        T) TMP_DIR="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done
shift "$((OPTIND-1))"

readonly PROFILE="$1"   # work | personal

[[ "$EUID" -eq 0 ]] && fail "don't run as root"

validate_and_init
check_dependencies

# we need to make sure our system clock is roughly right; otherwise stuff like apt-get might start failing:
#is_native || exe "rdate -s tick.greyware.com"
#is_native || exe "tlsdate -V -n -H encrypted.google.com"
is_native || update_clock || exit 1  # needs to be done _after_ check_dependencies as update_clock() uses some

choose_step

[[ "$SYSCTL_CHANGED" == 1 ]] && exe 'sudo sysctl -p --system'

exit 0


# ISSUES:
# if no sound, make sure alsa is defaulting to right card:
# aplay -l   and check card number; probably it's defaulting to 0;
# you want it to use the PCH device; if somehtings wrong, then
# create either /etc/asound.conf or $HOME/.asoundrc with these 3 lines:
    #defaults.ctl.card 1
    #defaults.pcm.card 1
    #defaults.timer.card 1
# in that case you probably need to change the device xfce4-volumed is controlling

# common debugging:
#   sudo dmesg | grep -i apparmor | grep -i denied  <- shows if some stuff is blocked by apparmor (eg we had this issue with msmtp if .msmtprc was under /data, not somewhere under $HOME)
#   sudo journalctl -u apparmor   <- eg when at boot-time it compalined 'Failed to load AppArmor profiles'

# TODOS:
# - if apt-get update fails, then we should fail script fast?
#
# GAMES:
# - flightgear/unstable
# - openttd
#
# UTILS:
# - for another bandwidth monitor, see https://github.com/tgraf/bmon
# - yet another top: bpytop: https://github.com/aristocratos/bpytop
#   required true colors, so urxvt doesn't quite cut it :(
# - for laptop power management, see also laptop-mode-tools https://github.com/rickysarraf/laptop-mode-tools (there's also arch wiki on it)
#
# OTHER PROGS:
# - another raster image editor: krita (more for painting & illustration)
# - TODO/productivity mngr: https://github.com/johannesjo/super-productivity
#
# vifm alternatives:
#  - https://github.com/jarun/nnn
#  - https://github.com/gokcehan/lf    - go-based ranger-alike
#  - https://github.com/sxyazi/yazi    - rust
#    - tl;dr: better OOTB ux than vifm?
#    - has zoxide integration?
#  - https://github.com/dylanaraps/fff - bash file mngr [deprecated]
#
#  TODO:
#  - replace cron w/ systemd timers
#    - consider installing systemd-cron if needed - converts legacy cron to sd-timers
#  - migrate to zfs (or bcachefs ?)
#   - if zfs, look into installing timeshift & integrating it w/ zfs
#   - same for btrfs - timeshift & snapper
#  - enable keepassxc integration w/ ssh-agent? see https://www.techrepublic.com/article/how-to-integrate-ssh-key-authentication-into-keepassxc/
#  - verify our smartd setup
#  - install TLP
#    - see these grub edits for TLP: https://linuxblog.io/thinkpad-t14s-gen-3-amd-linux-user-review-tweaks/#My_etcdefaultgrub_edits
#    - there's tlpui for GUI
#    - should we install auto-cpufreq w/ tlp?
#      - its author says it works w/ TLP as long as you disable tlp's cpu settings: https://www.reddit.com/r/linux/comments/ejxx9f/github_autocpufreq_automatic_cpu_speed_power/fd4y36k/
#    - it has USB_EXCLUDE_BTUSB opt to exclude bluetooth devices from usb autosuspend feature
#  - databse defrag/compactions should be scheduled, e.g. "notmuch compact"
#  - consider installing & setting up logwatch & fwlogwatch
#  - consider using Timeshift creator's tinytools: https://teejeetech.com/tinytools/
#  - consider zsh:
#    - w/ p10k prompt
#    - _if_ we go for plugin mngr, check out zinit
#      - does it inlcude caching logic like znap does, e.g. $ znap eval zcolors zcolors   ?
#      - or zim: https://github.com/zimfw/zimfw
#      - of better yet, no manager: https://github.com/mattmc3/zsh_unplugged
#        - see also https://www.reddit.com/r/zsh/comments/1etl9mz/fastest_plugin_manager/lie04dt/
#  - 'sides zsh, maybe fish or nushell
#    - loads of traction, x-platform, looks interesting
#    - other interesting interactive shells:
#      - elvish
#      - murex
#      - xonsh
#      - see also pharo: https://github.com/pharo-project/pharo (smalltalk-like lang with a repl/ide tooling)
#  - for shell: consider
#    - ble.sh (readline alternative for bash)
#      - be sure to test for input lag
#    - atuin (shell agnostic history nicety)
#  - window managers:
#    - gnome has paperWM for scrollable tiling
#    - niri - another scrollable tiling wm
#    - scroll - sway-compatible scroller: https://github.com/dawsers/scroll  ! looks cool !!
#       - alternatively, there's also papersway: https://spwhitton.name/tech/code/papersway/
#  - consider https://gitlab.com/Zesko/systemd-timer-notify/-/tree/e31e8ecf11a81f844ec3a2a699d7fa0f30f05e46/
#    - display desktop notifications when systemd timers start services. Notifications close automatically when the services finish
#
#
# list of sysadmin cmds:  https://haydenjames.io/90-linux-commands-frequently-used-by-linux-sysadmins/
#
