#!/usr/bin/env -S bash --norc --noprofile

executionPath=$(dirname $(realpath -s $0))

# Build in RAM for testing
LABEL="serpent"
WORKDIR="${executionPath}/${LABEL}IMG"
ROOTDIR="${WORKDIR}/ROOT"
EFIROOTDIR="${WORKDIR}/EFI"
IMAGE_SIZE="5GB"
EFI_SIZE="75MB"
ISO_BUILD=1
IMG="${WORKDIR}/IMG/${LABEL}.img"
EFIIMG="${WORKDIR}/IMG/EFI.img"


if [ `id --user` != 0 ]; then
    serpentFail "Script must be run as root"
fi

# Import used functions, temporary package manager that can be easily replaced with a real one
. ${executionPath}/common/functions.sh

# Cleanup from previous run
clean_mounts

requireTools fallocate mkfs.ext4 tune2fs

[[ -d ${WORKDIR} ]] && rm -rf ${WORKDIR}

mkdir -p ${WORKDIR}/IMG
mkdir -p ${ROOTDIR}
mkdir -p ${EFIROOTDIR}

# Prepare blank image
fallocate -l ${IMAGE_SIZE} ${IMG} || serpentFail "Unable to create image"
mkfs.ext4 -F ${IMG} || serpentFail "Unable to format image"
tune2fs -c0 -i0 ${IMG}
mount -o loop -t auto ${IMG} ${ROOTDIR} || serpentFail "Unable to mount image to ${ROOTDIR}"

# Temporary rootfs (solbuild img)
cp -a /tmp/lll/* ${ROOTDIR}
mount proc -t proc ${ROOTDIR}/proc
chroot ${ROOTDIR} usysconf run

cp /etc/resolv.conf ${ROOTDIR}/etc/resolv.conf
chroot ${ROOTDIR} eopkg upgrade -y

# Config a default system
echo LANG=en_US.UTF-8 > ${ROOTDIR}/etc/locale.conf

# Steps if making an ISO
if [[ ${ISO_BUILD} ]]; then
    # Install ISO tools and make initrd
    chroot ${ROOTDIR} eopkg install -y linux-current intel-microcode dracut prelink

    kernel_version=5.6.19-158.current
    MODULES="bash dmsquash-live pollcdrom rescue systemd"
    DRIVERS="ext2 msdosehci_hcd ohci_hcd sd_mod squashfs sr_mod uhci_hcd usb_storage usbhid vfat xhci_hcd xhci_pci"

    chroot ${ROOTDIR} dracut --prelink --strip --hardlink --force \
        --no-hostonly-cmdline -N --nomdadmconf --early-microcode \
        --kver $kernel_version \
        --add "${MODULES}" \
        --add-drivers "${DRIVERS}" \
        /initrd

    # Setup user account

fi

# mksquashfs to compress the image

# Steps if making an ISO
if [[ ${ISO_BUILD} ]]; then
    # Create EFI
    fallocate -l ${EFI_SIZE} ${EFIIMG} || serpentFail "Unable to create EFI"
    mkfs.vfat -F 12 -n ESP ${EFIIMG} || serpentFail "Unable to format EFI"
    mount -o loop -t auto ${EFIIMG} ${EFIROOTDIR} || serpentFail "Unable to mount EFI to ${EFIROOTDIR}"

    install -Dm00755 ${ROOTDIR}/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${EFIROOTDIR}/EFI/Boot/BOOTX64.EFI
    install -Dm00644 ${ROOTDIR}/usr/lib/kernel/com.solus-project.current.$kernel_version ${EFIROOTDIR}/kernel
    install -Dm00644 ${ROOTDIR}/initrd ${EFIROOTDIR}/initrd
    echo "default ${LABEL}\ntimeout 5\n" > ${EFIROOTDIR}/loader/loader.conf
    mkdir -p ${EFIROOTDIR}/entries
    echo "title ${LABEL}\nlinux /kernel\ninitrd /initrd\noptions root=${LABEL}:CDLABEL=${LABEL} ro quiet splash" > ${EFIROOTDIR}/entries/${LABEL}.conf

    sync
    umount ${EFIROOTDIR}
    # xorriso to have EFI booting iso

fi


