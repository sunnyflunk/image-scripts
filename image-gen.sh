#!/usr/bin/env -S bash --norc --noprofile

executionPath=$(dirname $(realpath -s $0))

# Build in RAM for testing
LABEL="Serpent"
WORKDIR="${executionPath}/${LABEL}IMG"
ROOTDIR="${WORKDIR}/ROOT"
EFIDIR="${WORKDIR}/EFI"
IMAGE_SIZE="5GB"
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

    # Create EFI
fi

sync

