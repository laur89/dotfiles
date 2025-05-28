# LA's Debian netinstall base setup

Pre-requisities:
* Debian testing release netinstall
* media/data mountpoint mounted at /data

Notes:
*  this setup is heavily dependent on the system configuration found in numerous
homeshick castles. Some of them are publicly not accessible, so your milage
WILL vary.

## Installation

The installation script under .bootstrap provides setup logic intended to be run on
fresh Debian netinstall installation. It also offers a possibility to run one of the
steps separately apart from the full installation mode.

### Full install:

1. Install Debian testing release netinstall (in reality, any Debian base distro
   should work fine).
    * can be found from https://www.debian.org/devel/debian-installer/
    * (or https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/amd64/iso-cd/
      more specifically)
    * *Note*: sometimes the daily images are broken, verify the build is passing [here](https://d-i.debian.org/daily-images/daily-build-overview.html)
      before downloading.
    * ~~If you're installing on a laptop/wifi and need firmware, you might be better
      off with these [unofficial images w/ firmware](https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/weekly-builds/amd64/iso-cd/):~~
      - Ignore, as of `bookworm`, [firmware is included in normal installer images](https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/)
      - [weekly testing netinst w/ firmware](https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/weekly-builds/amd64/iso-cd/firmware-testing-amd64-netinst.iso)
      - OR [daily sid netinst w/ firmware](https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/daily-builds/sid_d-i/current/amd64/iso-cd/firmware-testing-amd64-netinst.iso)
        from [this page](https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/daily-builds/sid_d-i/current/amd64/iso-cd/)

1. optionally preseed the installation (`esc` when graphical menu appears):

```
    auto url=webserver.eu/path/preseed.cfg
    debian-installer/allow_unauthenticated_ssl=true
    hostname=myhostname domain=internal.yourdomain.tld
    passwd/root-password=r00tpass
    passwd/root-password-again=r00tpass
    passwd/user-fullname="Full Name"
    passwd/username=username
    passwd/user-password=userpass
    passwd/user-password-again=userpass
```
  - note under UEFI installation, `esc` likely doesn't do anything; in that
    case:
        - highlight `Advanced options` -> `Automated install`
        - press `e`
        - down arrow 3 times, move cursor to right after `auto=true`, and add
        "url="/"hostname="/other params
  - note if you don't provide required data, installer will ask for it anyway
  - alternatively, if you don't want to provide any params to preseed, you can
    also choose `Advanced options` -> `(Graphical) Automated install` -> type
    url of our preseed file
    - note to preseed hostname, we _have to_ provide it as kernel params, so
      this option would leave our domain as default "`debian`"

1. wget https://github.com/laur89/dotfiles/raw/master/.bootstrap/install_system.sh
    * or `wget https://github.com/laur89/dotfiles/raw/develop/.bootstrap/install_system.sh`
      for develop branch.
1. `chmod +x install_system.sh`
1. install sudo, if not already installed:
    * su
    * apt-get install sudo
1. add your user to sudo group:
    * `/usr/sbin/adduser $USER  sudo`    (and logout + login afterwards!)
1. sudo apt-get update
1. execute script:
    * `./install_system.sh -F personal|work`
    * optionally pass `-N` option for non-interactive (ie standalone) mode,
      e.g. `./install_system.sh -N personal`

### Single task:

This mode is intended to be used througout the system lifetime post-fullinstall.
It provides maintenance/management options, such as
* generating ssh key
* switching active jdk versions
* upgrading kernel
* installing various drivers
* installing the base package set
* build and/or install software (such as vim, copyq, oracle jdk)

### Update:

This mode is to be ran periodically to build/install software; note it also includes
non-standard sources, such as github releases/, and being directly built from source.

## Partitioning

Note our main preseed.cfg entails manual partitioning, as we [cannot preseed
encrypted partitions w/o LVM](https://forums.debian.net/viewtopic.php?p=822924)

Instead we partition it manually. Instructions from [here](https://www.dwarmstrong.org/minimal-debian/):
- select `Manual` partitioning
- create `EFI` partition, beginning, 538 MB
    - TODO: decrease to 300MB?
- create `ext4` partition, beginning, mount to `/boot`, 1044 MB
  - could be btrfs, but some features, such as [savedefault](https://wiki.archlinux.org/title/GRUB/Tips_and_tricks#Recall_previous_entry)
    (relevant w/ dualboot or multiple kernels) might not work
- create `physical volume for encryption` partition, beginning, remaining size
- select `Configure encrypted volumes`, select `Yes`
- select `Create encrypted volumes`
- select the `crypto` devices/partitions
- `Finish`
- go through the data erasure, will prolly take a lot of time
- set encryption pass
- select our encrypted volume (under 'Encrypted volume' section, should be at
  the top), `btrfs`, mount to `/`
- `Finish partitioning and write changes to disk`

Note if we had more than one encrypted volume (e.g. / and /home), then we'd
have to configure a keyfile to forego entering two passphrases, see the bottom
of the above blog post.


## Troubleshooting

- dark theme not set.
in eary '25 it
started defaulting to light theme again until `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`
was ran; could be [gtk4](https://wiki.archlinux.org/title/GTK#Dark_theme_variant) thing.
gsettings likely has (a binary!) config file at `~/.config/dconf/user`.
For GUI dconf editor install `dconf-editor` pkg.
    - note it's a binary file, [which should not be replaced while logged in](https://askubuntu.com/a/984214),
    so be careful if storing it in our dotfiles/git repo.
        - u/muru's reply below it shows a way to configure it via text files
            system-wide under `/etc/dconf/db/database.d/`
    - there's also [this askubuntu answer](https://askubuntu.com/a/875922) that
        might be relevant;
    - as always, Arch' [wiki on GTK](https://wiki.archlinux.org/title/GTK) is good.

- for uniform GTK & QT look, see [this arch wiki](https://wiki.archlinux.org/title/Uniform_look_for_Qt_and_GTK_applications)
- for theming under Wayland, read [this!](https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland)

## TODO

1. delay homeshick repos' https->ssh change to later stages; otherwise
   if we need to restart installation, pull can fail due to missing ssh
   keys or port 22 being blocked (and relevant git config still not in place);
1. see into using [simple-cdd](https://wiki.debian.org/Simple-CDD) to preseed
   the installation iso
1. see into network PXE boot (iPXE?)
1. consider using https://netboot.xyz/docs/quick-start
1. consider using [calamares installer](https://github.com/calamares/calamares)
  - or [this opinionated installer](https://github.com/r0b0/debian-installer)
    - supports browser-based installation, automation (preseed replacement?)
1. see other dotfiles:
  - https://github.com/infokiller/config-public
  - https://github.com/risu729/dotfiles (wsl stuff as well!)
  - https://gitlab.com/sio/server_common (from [this reddit post](https://www.reddit.com/r/linux/comments/vd9qkn/it_took_years_to_perfect_my_setup_and_now_i_want/ickhfsc/))
