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
  - make sure to use the preseed template expander script, not the preseed
    template directly;
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
* upgrading kernel
* installing various drivers
* installing the base package set
* build and/or install software (vim, copyq et al.)

### Update:

This mode is to be ran periodically to build/install software; note it also includes
non-standard sources, such as github releases/, and being directly built from source.

## Manual partitioning

Note our main preseed.cfg entails manual partitioning, as we [cannot preseed
encrypted partitions w/o LVM](https://forums.debian.net/viewtopic.php?p=822924)

Instead we partition it manually. Instructions from [here](https://www.dwarmstrong.org/minimal-debian/):
- select `Manual` partitioning
- create `EFI` partition, beginning, 538 MB
    - TODO: decrease to 300MB?
- create `ext4` partition, beginning, mount to `/boot`, 1044 MB
  - could be btrfs, but some features, such as [savedefault](https://wiki.archlinux.org/title/GRUB/Tips_and_tricks#Recall_previous_entry)
    (relevant w/ dualboot or multiple kernels) might not work
  - when using systemd-boot and encrypting everything, then no need for
    separate /boot partition as commit c0cde1e8348db5915a026ec3c8ad2220031e6fcc
    implies
    - also somewhat relevant to no-boot partition is [this debian forum post](https://forums.debian.net/viewtopic.php?p=822950)
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
of the (minimal-debian post) blog post above.

### [another instruction](https://medium.com/@inatagan/installing-debian-with-btrfs-snapper-backups-and-grub-btrfs-27212644175f)
- sets up grub-btrfs to allow us to boot directly into our snapshots without the need of a live media

- after finishing the partition, do NOT start installing base-system, but isntead
1. `ctrl+alt+f2` to enter busybox terminal
1. `df` to see current mounted fs
1. unmount our target fs by:
    - `unmount /target/boot/efi`
    - `unmount /target/boot`
    - `unmount /target`
1. mount our encrypted partition w/ `mount /dev/mapper/$VOLUME_GROUP_NAME /mnt`
    - VOL_GROUP_NAME will be likely be the one that was mounted to /target
1. `cd /mnt`
1. `ls`
    - should show only `@rootfs`
1. rename to `@` to be compatible w/ timeshift:
    - `mv @rootfs/ @`
1. create additional subvolumes:
    - `btrfs su cr @snapshots`
    - `btrfs su cr @home`
    - `btrfs su cr @tmp`
    - `btrfs su cr @var`
1. let's mount our root sub-volume to be able to create additional dirs for subvols:
    - `mount -o noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@ /dev/mapper/$VOLUME_GROUP_NAME_FOR_ROOT /target`
1. now create mountpoints for each subvol:
    - `cd /target`
      > It’s also best to create /var/lib/portables and /var/lib/machines 
        if not already there. Systemd creates them automatically 
        as nested subvolumes. Nested subvolumes will force you to do some
        manual removal after restoring a snapshot and removing old snapshots.
      > var/lib/containers should be podman location
      > TODO: shouldn't mount /tmp when using tmpfs, right?!
    - `mkdir -p .snapshots home var/{log,cache,crash,tmp,spool} var/lib/{libvirt/images,containers,portables,machines}`
        - old, ignore
    - `mkdir -p .snapshots home tmp var`
1. mount each subvol to their mountpoint:
```sh
mount -o noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@snapshots /dev/mapper/$VOLUME_GROUP_NAME_FOR_ROOT /target/.snapshots
mount -o noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@home /dev/mapper/$VOLUME_GROUP_NAME_FOR_ROOT /target/home
mount -o noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@tmp /dev/mapper/$VOLUME_GROUP_NAME_FOR_ROOT /target/tmp
mount -o noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@var /dev/mapper/$VOLUME_GROUP_NAME_FOR_ROOT /target/var
```
1. also mount boot & efi:
    - `mount /dev/sdx2 boot`
    - `mount /dev/sdx1 boot/efi`
1. now we edit fstab (note busybox doesn't have vim) TODO: does it have vi?
    - `nano etc/fstab`
    - first edit the line where "@rootfs" is, then press `home`, and then
      `ctrl+k` to cut & `ctrl+u` to paste as many lines as needed; then just
      edit the mountpoint labels:
```sh
/dev/mapper/$VOLUME_GROUP /             btrfs  noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@             0    0
/dev/mapper/$VOLUME_GROUP /.snapshots   btrfs  noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@snapshots    0    0
/dev/mapper/$VOLUME_GROUP /home         btrfs  noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@home         0    0
/dev/mapper/$VOLUME_GROUP /tmp          btrfs  noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@tmp          0    0
/dev/mapper/$VOLUME_GROUP /var          btrfs  noatime,space_cache=v2,compress=zstd:1,ssd,discard=async,subvol=@var          0    0
```
1. cd to root and unmount:
    - `cd /; umount /mnt; exit`
1. return to standard installation:
    - `ctrl+alt+f1`
1. install base system
1. reboot
1. `sudo apt-get install snapper inotify-tools`
1. configure `snapper` to take initial snapshots prior to further installation:
    1. > The default way that snapper works is to automatically create a new subvolume
         “.snapshots” under the path of the subvolume that we are creating a snapshot.
         Because we want to keep our snapshots separated from the backed up subvolume
         itself we must remove the snapper created “.snapshot” subvolume and then
         re-mount using the one that we created before in a separate subvolume at @snapshots
         - `cd /`
         - `sudo umount .snapshots`
         - `sudo rm -r .snapshots`
1. now we can create a new config for snapper:
    - `sudo snapper -c root create-config /`
    - this should have crated a new .snapshots/ directory as well a new btrfs
      subvol of same name. we will rm this new subvol and link our own
      @snapshots subvol to his path, so our snapshots are safely stored in a 
      different location:
    - `sudo btrfs subvolume delete /.snapshots`  # delete auto-created subvol
    - `sudo mkdir /.snapshots`  # recreate dir
    - `sudo mount -av`  # remount our @snapshots to /.snapshots
1. snapper is ready to be used
1. to disable auto-snapshotting on boot:
    - `sudo systemctl disable snapper-boot.timer`
1. to disable snapper timeline:
    - `sudo snapper -c root set-config 'TIMELINE_CREATE=no'`
1. adding sudo group to allow our user to use snapper:
    - `sudo snapper -c root set-config 'ALLOW_GROUPS=sudo'`
    - `sudo snapper -c root set-config 'SYNC_ACL=yes'`
1. snapper will auto-create a pair of pre- & post- snapshots every time we use apt
   to change it, modify `/etc/apt/apt.conf.d/80snapper`
1. change amount of snapshots kept (NOTE: docs recommended to keep max 12)
    - `sudo snapper -c root set-config "NUMBER_LIMIT=10"`
    - `sudo snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=10"`
1. finally create first default snapshot:
    - `sudo snapper -c root create --description "default fresh install"`

TODO: look into grub-btrfs (not avail on debian repos); any alternative for systemd-boot?


## BTRFS notes 

- [it is best to have /boot and / on the same filesystem, when using the snapshot-feature of btrfs]
  (https://forum.manjaro.org/t/btrfs-and-separate-boot-ext4-partition/155211/9)
- cow should be disabled where loads of writes is done, e.g. VM images,
  databases...
  - as per [this comment](https://www.reddit.com/r/btrfs/comments/p1xa0u/terrible_vm_performance_even_with_mitigations/h8gdyui/)
    > If you have any snapshots, CoW is force enabled
    meaning even if you `chattr +C a directory`, taking a snapshot of that subvolume / directory will make it CoW again
  - if you need cow, use KVM's `Qcow2` instead
- if you're making snapshots of /, make sure to take it together with /boot
  (assuming latter is on a different partition), otherwise you might end up in
  an unbootable state due to missing kernel
- quota usage with btrfs is questionable - both from performance & reported
  data usage perspective
- see https://github.com/kdave/btrfsmaintenance for maintenance scripts
- unsure about the differences, but do not run `check` unless we're having
  problems; for general maintenance, `scrub` & `balance` are the tools
  - think it's becuase `check` looks for fs consistency, but btrfs can't become
    inconsistent like ext4 due to cow?
- look into duplicate metadata on single drive
- verify scrub is scheduled by sytemd/deb
- look into `btrfs de stats`
- on [defrag](https://btrfs.readthedocs.io/en/latest/Defragmentation.html):
    > Defragmentation does not preserve extent sharing, e.g. files created by cp --reflink
      or existing on multiple snapshots. Due to that the data space consumption may increase
    - this is also mentioned [here](https://btrfs.readthedocs.io/en/latest/ch-mount-options.html)
- `lsattr` cmd to confirm our cow/nodatacow attr (`C`)
- from [here](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Snapshots),
  in order to roll back to a snapshot, unmount the modified original subvolume,
  use `mv` to rename the old subvolume to a temp location, and then again to
  rename the snapshot to the original name. you can then remount the subvolume.
  at this point the original subvol may be deleted.
- when using multi disk, you should periodically [balance](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Balancing)
- https://en.opensuse.org/SDB:BTRFS
- see also: https://github.com/baodrate/snap-sync
- see also: https://github.com/digint/btrbk
- confirm this is reasonable way for rollbacks:
```sh
$ sudo btrfs subvolume delete /btrfs/@
$ sudo btrfs subvolume snapshot /btrfs/@snapshots/root/15/snapshot /btrfs/@
```
- another rollback way, where `/btrfs/@snpashots/root/15/snapshot` is the currently
  booted ro-snapshot; note this method saves the damaged subvolume:
```sh
$ sudo mv /btrfs/@ /btrfs/@snapshots/old_root
$ sudo btrfs su sn /btrfs/@snapshots/root/15/snapshot /btrfs/@
```


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

## Notes/see also
- [zfs installation script](https://github.com/danfossi/Debian-ZFS-Root-Installation-Script)

## TODO

1. delay homeshick repos' https->ssh change to later stages; otherwise
   if we need to restart installation, pull can fail due to missing ssh
   keys or port 22 being blocked (and relevant git config still not in place);
1. see into using [simple-cdd](https://wiki.debian.org/Simple-CDD) to preseed
   the installation iso
1. see into network PXE boot (iPXE?)
1. consider using https://netboot.xyz/docs/quick-start
1. consider using [calamares installer](https://github.com/calamares/calamares)
   (_Distribution-independent installer framework_)
    - or [this opinionated installer](https://github.com/r0b0/debian-installer)
      - supports browser-based installation, automation (preseed replacement?)
1. see other dotfiles:
    - https://github.com/infokiller/config-public
    - https://github.com/risu729/dotfiles (wsl stuff as well!)
    - https://gitlab.com/sio/server_common (from [this reddit post](https://www.reddit.com/r/linux/comments/vd9qkn/it_took_years_to_perfect_my_setup_and_now_i_want/ickhfsc/))
