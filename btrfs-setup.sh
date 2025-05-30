#!/bin/sh
#
# note this will run on busybox! meaning it's ash, NOT bash.
#######################################################################
BTRFS_MOUNT_OPTS=''  # optional; leave blank to use default opts set by debian installer.
                     # note it should _not_ include the ",subvolume=" tail

while getopts 'sm:' opt; do
    case "$opt" in
        s)      exit 0 ;;  # skip
        m)      BTRFS_MOUNT_OPTS="$OPTARG" ;;
        \?)     exit 1 ;;
    esac
done
shift $(expr $OPTIND - 1)

if [ $# -eq 0 ]; then
    # default subvolume-to-mountpoint mappings:
    set -- '@snapshots:.snapshots' \
           '@home:home' \
           '@var:var'
fi
#######################################################################

# upstream scripts import this common lib, e.g. https://salsa.debian.org/installer-team/partman-basicfilesystems/-/blob/master/finish.d/aptinstall_basicfilesystems
#. /lib/partman/lib/base.sh

# verify whether we've partitioned using btrfs; if not, bail successfully.
# note upstream scripts do it differently, see script under /lib/partman/finish.d/70aptinstall_btrfs
#apt list -qq --installed btrfs-progs | grep -q . || exit 0  # TODO: we might not have apt set up yet...
grep -Eq -m 1 '\s+/\s+btrfs\s+.*=@rootfs\s+' /target/etc/fstab || exit 0
[ -d /target ] || exit 1  # sanity


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
    BTRFS_MOUNT_OPTS="$(sed -nr -e "s|^.*\s+/\s+btrfs\s+(\S+),subvol=@rootfs\s+.*|\1|p" /target/etc/fstab)"
    [ -z "$BTRFS_MOUNT_OPTS" ] && exit 1  # sanity
fi

sed -r -e "s|(^.*\s+/\s+btrfs\s+)\S+(,subvol=@rootfs\s+.*)|\1${BTRFS_MOUNT_OPTS}\2|g" -i /target/etc/fstab || exit 1
FSTAB_MOUNTLINE="$(grep -E '\s+/\s+btrfs\s+.*subvol=@rootfs\s+' /target/etc/fstab)" || exit 1

# first unmount our partitions:
EFI_FS="$(umnt /target/boot/efi)" || exit 1  # results in empty var if mountpoint doesn't exist
BOOT_FS="$(umnt /target/boot)" || exit 1  # results in empty var if mountpoint doesn't exist
ROOT_FS="$(umnt /target)" || exit 1  # required non-empty
[ -z "$ROOT_FS" ] && exit 1  # sanity

mount "$ROOT_FS" /mnt || exit 1

# re-mount our root volume to be able to create additional dirs for subvols:
mount -o "${BTRFS_MOUNT_OPTS},subvol=@rootfs" "$ROOT_FS" /target || exit 1
##################

# 1. create mountpoints (i.e. dirs) for each subvol;
# 2. create additional subvols;
# 3. mount them (i.e. to the dir created in step 1)

# first awk version...:
#awk -v "SNAPSHOT_TO_MOUNTPOINT=@snapshots:.snapshots;@home:home;@var:var" \
#    -v "ROOT_FS=$ROOT_FS" \
#    -v "BTRFS_MOUNT_OPTS=$BTRFS_MOUNT_OPTS" \
#    -v "FSTAB=$FSTAB_MOUNTLINE" '
#  BEGIN {
#    n=split(SNAPSHOT_TO_MOUNTPOINT,pp,";")
#    for(i=1; i<=n; i++) {
#      split(pp[i],subvol_mountpoint,":")
#      system("btrfs subvolume create /mnt/" subvol_mountpoint[1])
#      system("mkdir /target/" subvol_mountpoint[2])
#      system("mount -o " BTRFS_MOUNT_OPTS ",subvol=" subvol_mountpoint[1] " " ROOT_FS " /target/" subvol_mountpoint[2])
#
#      t = FSTAB;
#      sub(",subvol=@",",subvol=" subvol_mountpoint[1],t);
#      sub(" / "," /" subvol_mountpoint[2] " ",t);
#
#      #system("echo \"" t "\" >> /target/etc/fstab")
#      print t >> "/target/etc/fstab"
#    }
#}'
# ...and pure ash:
for mapping in "$@"; do
    subvol="$(echo "$mapping" | cut -d: -f1)"
    mountpoint="$(echo "$mapping" | cut -d: -f2)"
    mntp="/target/$mountpoint"

    # create subvol:
    btrfs subvolume create "/mnt/$subvol" || exit 1
    # create mountpoint:
    mkdir "$mntp" || exit 1
    # mount:
    mount -o "${BTRFS_MOUNT_OPTS},subvol=$subvol" "$ROOT_FS" "$mntp" || exit 1
    # add fstab entry:
    echo "$FSTAB_MOUNTLINE" | sed -r -e "s|(^.*\s+)/(\s+btrfs.*)|\1/${mountpoint}\2|" \
                                  -e "s|,subvol=@rootfs|,subvol=$subvol|" >> /target/etc/fstab || exit 1
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
