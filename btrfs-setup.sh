#!/bin/sh
#
# note this will run on busybox! meaning it's ash, NOT bash.
#
readonly DEFAULT_ROOT_SUBVOL='@rootfs'  # default root subvol name used by debian, do not customize
#######################################################################
# for HDD it's ok to go with higher compression (say zstd:3) as you're not
# likely to be cpu limited. zstd:1 reasonable for nvme's. SATA SSD maybe zstd:2
#
# noatime as we don't really care for it. also atime makes many snapshots more costly.
# compress-force will try to compress even if the first 64KiB of a file is not compressible.
# - TODO: enable autodefrag?
# - does 'nodatasum' need to go w/ nodatacow?
#   - don't think, nodatacow should imply the former, and the othe way around
#   - !! apparently nodatadow also implies no compression
# - btrfs does not support mounting subvols from the same partition w/
#   different settings regardign cow - best use chattr +C !!!
#   - see https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/FAQ.html#Can_I_mount_subvolumes_with_different_mount_options.3F
# - TODO:  I make /home/<user>/.cache a separate BTRFS subvolume and I mark that directory as nodatacow. But that's really a separate discussion.
# - some people set +C on entire /var - reasonable?
BTRFS_MOUNT_OPTS='defaults,noatime,compress=zstd:1'  # optional; leave blank to use default opts set by debian installer.
                                                     # note it should _not_ include the ",subvolume=" tail
ROOT_SUBVOL="$DEFAULT_ROOT_SUBVOL"  # if you want to rename the default root subvol, change this value; e.g. commonly used value is '@'

while getopts 'm:' opt; do
    case "$opt" in
        m)      BTRFS_MOUNT_OPTS="$OPTARG" ;;
        \?)     exit 1 ;;
    esac
done
shift $(expr $OPTIND - 1)

# note one interesting layout is making snapshots its subject subvolume siblings, see
# https://bbs.archlinux.org/viewtopic.php?pid=1766676#p1766676
#
# TODO: can we grep ID=1000 username from /etc/passwd or elsewhere, and make /home/<user>/.cache a separate BTRFS subvolume and I mark that directory as nodatacow
if [ $# -eq 0 ]; then
    # default subvolume-to-mountpoint mappings to create:
    set -- 'snapshots/@root:.snapshots' \
           '@home:home' \
           'snapshots/@home:home/.snapshots' \
           '@data:data' \
           '@opt:opt' \
           'var/@log:var/log' \
           'var/@tmp:var/tmp' \
           'var/@run:var/run' \
           'var/@lock:var/lock' \
           'var/@cache:var/cache' \
           'var/lib/@containers:var/lib/containers:NOCOW' \
           'var/lib/@machines:var/lib/machines:NOCOW' \
           'var/lib/libvirt/@images:var/lib/libvirt/images:NOCOW' \
           'var/lib/apt/@lists:var/lib/apt/lists:NOCOW'
fi
#######################################################################

# upstream scripts import this common lib, e.g. https://salsa.debian.org/installer-team/partman-basicfilesystems/-/blob/master/finish.d/aptinstall_basicfilesystems
#. /lib/partman/lib/base.sh

[ -s /target/etc/fstab ] || exit 1  # sanity

# verify whether we've partitioned using btrfs; if not, bail successfully.
# note upstream scripts do it differently, see script under /lib/partman/finish.d/70aptinstall_btrfs
grep -Eq -m 1 "\s+/\s+btrfs\s+.*=${DEFAULT_ROOT_SUBVOL}\s+" /target/etc/fstab || exit 0


umnt() {  # unmount provided mountpoint, and return the fs that was mounted
    local mountpoint fs
    mountpoint="$1"
    fs="$(df -P | awk -v "M=$mountpoint" '{if($NF == M) print $1}')"
    if [ -n "$fs" ]; then
        umount "$mountpoint" > /dev/null || return 1
    fi
    echo -n "$fs"
}

# capture the original mount opts, sans the ',subvol=':
if [ -z "$BTRFS_MOUNT_OPTS" ]; then
    BTRFS_MOUNT_OPTS="$(sed -nr -e "s|^.*\s+/\s+btrfs\s+(\S+),subvol=${DEFAULT_ROOT_SUBVOL}\s+.*|\1|p" /target/etc/fstab)"
    [ -z "$BTRFS_MOUNT_OPTS" ] && exit 1  # sanity
fi

# set our BTRFS mount opts:
if [ "$ROOT_SUBVOL" != "$DEFAULT_ROOT_SUBVOL" ]; then
    # additionally change the root subvolume ($DEFAULT_ROOT_SUBVOL -> $ROOT_SUBVOL):
    sed -r -e "s|(^.*\s+/\s+btrfs\s+)\S+,subvol=${DEFAULT_ROOT_SUBVOL}(\s+.*)|\1${BTRFS_MOUNT_OPTS},subvol=${ROOT_SUBVOL}\2|g" -i /target/etc/fstab || exit 1
else
    sed -r -e "s|(^.*\s+/\s+btrfs\s+)\S+(,subvol=${DEFAULT_ROOT_SUBVOL}\s+.*)|\1${BTRFS_MOUNT_OPTS}\2|g" -i /target/etc/fstab || exit 1
fi

FSTAB_MOUNTLINE="$(grep -E "\s+/\s+btrfs\s+.*subvol=${ROOT_SUBVOL}\s+" /target/etc/fstab)" || exit 1

# first unmount our partitions:
EFI_FS="$(umnt /target/boot/efi)" || exit 1  # results in empty var if mountpoint doesn't exist
BOOT_FS="$(umnt /target/boot)" || exit 1  # results in empty var if mountpoint doesn't exist
ROOT_FS="$(umnt /target)" || exit 1  # required non-empty
[ -z "$ROOT_FS" ] && exit 1  # sanity

mount "$ROOT_FS" /mnt || exit 1

# rename the root subvol:
if [ "$ROOT_SUBVOL" != "$DEFAULT_ROOT_SUBVOL" ]; then
    TARGET_ROOT_SUBVOL="/mnt/$ROOT_SUBVOL"
    [ -e "$TARGET_ROOT_SUBVOL" ] && exit 1  # sanity
    #find /mnt -mindepth 1 -maxdepth 1 -name "$DEFAULT_ROOT_SUBVOL" -exec mv {} "$TARGET_ROOT_SUBVOL" \;
    mv -- "/mnt/$DEFAULT_ROOT_SUBVOL" "$TARGET_ROOT_SUBVOL" || exit 1
    [ -e "$TARGET_ROOT_SUBVOL" ] || exit 1  # sanity
fi

# re-mount our root volume to be able to create additional dirs for subvols:
mount -o "${BTRFS_MOUNT_OPTS},subvol=${ROOT_SUBVOL}" "$ROOT_FS" /target || exit 1
##################

# 1. create mountpoints (i.e. dirs) for each subvol;
# 2. create additional subvols;
# 3. mount them (i.e. to the dir created in step 1)
for mapping in "$@"; do
    subvol="$(echo "$mapping" | cut -d: -f1)"
    mountpoint="$(echo "$mapping" | cut -d: -f2)"
    opts="$(echo "$mapping" | cut -d: -f3)"

    mntp="/target/$mountpoint"

    # create subvol:
    [ -e "/mnt/$subvol" ] && exit 1  # sanity
    btrfs subvolume create -p "/mnt/$subvol" || exit 1  # -p is similar to mkdir's -p
    # create mountpoint:
    mkdir -p -- "$mntp" || exit 1
    if [ "$opts" == *NOCOW* ]; then  # TODO verify ash supports this
        # TODO: or should we set it on /mnt/$subvol?:
        chattr +C -- "$mntp" || exit 1  # confirm values via  $ lsattr
    fi

    # mount:
    mount -o "${BTRFS_MOUNT_OPTS},subvol=$subvol" "$ROOT_FS" "$mntp" || exit 1
    # add fstab entry:
    echo "$FSTAB_MOUNTLINE" | sed -r -e "s|(^.*\s+)/(\s+btrfs.*)|\1/${mountpoint}\2|" \
                                  -e "s|,subvol=${ROOT_SUBVOL}|,subvol=$subvol|" >> /target/etc/fstab || exit 1
done

umount /mnt || exit 1

# mount boot and/or efi back:
if [ -n "$BOOT_FS" ]; then
    mount "$BOOT_FS" /target/boot || exit 1
fi

if [ -n "$EFI_FS" ]; then
    mount "$EFI_FS" /target/boot/efi || exit 1
fi

exit 0
