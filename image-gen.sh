#!/usr/bin/env -S bash --norc --noprofile

executionPath=$(dirname $(realpath -s $0))

# Build in RAM for testing
LABEL="serpent"
WORKDIR="/tmp/${LABEL}IMG"
ROOTDIR="${WORKDIR}/ROOT"
EFIROOTDIR="${WORKDIR}/EFI"
IMAGE_SIZE="3GB"
EFI_SIZE="75MB"
ISO_BUILD=1
COMPRESSION_LEVEL=3
IMG="${WORKDIR}/IMG/${LABEL}.img"
EFI=efi.img
EFIIMG="${WORKDIR}/IMG/${EFI}"
kernel_version=5.11.3-173


if [ `id --user` != 0 ]; then
    serpentFail "Script must be run as root"
fi

# Import used functions, temporary package manager that can be easily replaced with a real one
. ${executionPath}/common/functions.sh

# Cleanup from previous run
clean_mounts

requireTools fallocate mkfs.ext4 tune2fs mksquashfs chroot xorriso

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

    MODULES="bash dmsquash-live pollcdrom rescue systemd"
    DRIVERS="ext2 ohci_hcd sd_mod squashfs sr_mod uhci_hcd usb_storage usbhid vfat xhci_hcd xhci_pci"
#msdosehci_hcd
    chroot ${ROOTDIR} dracut --prelink --strip --hardlink --force \
        --no-hostonly-cmdline -N --nomdadmconf --early-microcode \
        --kver $kernel_version.current \
        --add "${MODULES}" \
        --add-drivers "${DRIVERS}" \
        /initrd

    # Setup user account

fi

chroot ${ROOTDIR} eopkg dc
umount -f ${ROOTDIR}/proc


# Steps if making an ISO
if [[ ${ISO_BUILD} ]]; then
    # Create EFI
    fallocate -l ${EFI_SIZE} ${EFIIMG} || serpentFail "Unable to create EFI"
    mkfs.vfat -F 12 -n ESP ${EFIIMG} || serpentFail "Unable to format EFI"
    mount -o loop -t auto ${EFIIMG} ${EFIROOTDIR} || serpentFail "Unable to mount EFI to ${EFIROOTDIR}"

    install -Dm00755 ${ROOTDIR}/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${EFIROOTDIR}/EFI/Boot/BOOTX64.EFI
    install -Dm00644 ${ROOTDIR}/usr/lib/kernel/com.solus-project.current.$kernel_version ${EFIROOTDIR}/kernel
    mv ${ROOTDIR}/initrd ${EFIROOTDIR}/initrd
    mkdir -p ${EFIROOTDIR}/loader/entries

    echo "default ${LABEL}
timeout 5" > ${EFIROOTDIR}/loader/loader.conf

    echo "title ${LABEL}
linux /kernel
initrd /initrd
options root=${LABEL}:CDLABEL=${LABEL} ro quiet splash" > ${EFIROOTDIR}/loader/entries/${LABEL}.conf

    sync
    umount ${EFIROOTDIR}
fi

# mksquashfs to compress the image
umount ${ROOTDIR}
#mksquashfs ${ROOTDIR}/* ${IMG} -comp zstd -Xcompression-level ${COMPRESSION_LEVEL} -progress

# xorriso to have EFI booting iso
if [[ ${ISO_BUILD} ]]; then
    xorriso -as mkisofs -o ${WORKDIR}/${LABEL}.iso -iso-level 3 -V ${LABEL} -A "TEST ISO" ${IMG} ${EFIIMG} -e /${EFI} -no-emul-boot
fi

echo "qemu-system-x86_64 -enable-kvm -m 2048 -cpu host -smp cpus=2 -bios /usr/share/ovmf/OVMF.fd -cdrom ${WORKDIR}/${LABEL}.iso -soundhw hda"
