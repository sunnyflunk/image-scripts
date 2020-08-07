#!/bin/true

# Common functionality between all scripts


# Emit a warning to tty
function printWarning()
{
    echo -en '\e[1m\e[93m[WARNING]\e[0m '
    echo -e $*
}

# Emit an error to tty
function printError()
{
    echo -en '\e[1m\e[91m[ERROR]\e[0m '
    echo -e $*
}

# Emit info to tty
function printInfo()
{
    echo -en '\e[1m\e[94m[INFO]\e[0m '
    echo -e $*
}

# Failed to do a thing. Exit fatally.
function serpentFail()
{
    printError $*
    exit 1
}

function requireTools()
{
    for tool in $* ; do
        which "${tool}" &>/dev/null  || serpentFail "Missing host executable: ${tool}"
    done
}

function clean_mounts() {
    # Umount stuff to exit cleanly
    [[ `grep ${ROOTDIR}/proc /etc/mtab` ]] && umount ${ROOTDIR}/proc
    [[ `grep ${ROOTDIR} /etc/mtab` ]] && umount ${ROOTDIR}
    [[ `grep ${EFIROOTDIR} /etc/mtab` ]] && umount ${EFIROOTDIR}
}
