#!/usr/bin/env -S bash --norc --noprofile

# Build in RAM for testing
LABEL="Serpent"
WORKDIR="/tmp/${LABEL}ISO"
executionPath=$(dirname $(realpath -s $0))

if [ `id --user` != 0 ]; then
    serpentFail "Script must be run as root"
fi

# Import used functions
. ${executionPath}/common/functions.sh

[[ -d $WORKDIR ]] && rm -rf $WORKDIR

mkdir -p $WORKDIR
