#!/usr/bin/env -S bash --norc --noprofile

# Build in RAM for testing
LABEL="Serpent"
WORKDIR="/tmp/${LABEL}ISO"
ROOTDIR="${WORKDIR}/ROOT"
IMAGE_SIZE="5GB"
IMG="${WORKDIR}/IMG/${LABEL}.img"
executionPath=$(dirname $(realpath -s $0))

if [ `id --user` != 0 ]; then
    serpentFail "Script must be run as root"
fi

# Import used functions
. ${executionPath}/common/functions.sh

requireTools fallocate mkfs.ext4 tune2fs

[[ -d ${WORKDIR} ]] && rm -rf ${WORKDIR}

mkdir -p ${WORKDIR}/IMG
mkdir -p ${ROOTDIR}

# Prepare blank image
fallocate -l ${IMAGE_SIZE} ${IMG} || serpentFail "Unable to create image"
mkfs.ext4 -F ${IMG} || serpentFail "Unable to format image"
tune2fs -c0 -i0 ${IMG}

mount -o loop -t auto ${IMG} ${ROOTDIR} || serpentFail "Unable to mount image to ${ROOTDIR}"
