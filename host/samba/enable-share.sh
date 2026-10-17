#!/bin/bash
# Leave one share link in shares-enabled/.
# This script edits the git tree only. It does not change the live server.
#
# Usage: bash /data/stacks/host/samba/enable-share.sh sabnzbd
# Then, as root: bash /data/stacks/host/samba/install-root.sh

SRC="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"

echo "enable-share: start"

if [ -z "${NAME}" ]
then
    echo "enable-share: ERROR usage: enable-share.sh <name>"
    echo "enable-share: available:"
    ls "${SRC}/shares-available"
    exit 1
fi

if [ ! -f "${SRC}/shares-available/${NAME}.conf" ]
then
    echo "enable-share: ERROR missing shares-available/${NAME}.conf"
    exit 1
fi

mkdir -p "${SRC}/shares-enabled"
find "${SRC}/shares-enabled" -mindepth 1 -maxdepth 1 -exec rm -f {} +
if [ $? -ne 0 ]
then
    echo "enable-share: ERROR clear shares-enabled failed"
    exit 1
fi

ln -s "../shares-available/${NAME}.conf" "${SRC}/shares-enabled/${NAME}.conf"
if [ $? -ne 0 ]
then
    echo "enable-share: ERROR symlink failed"
    exit 1
fi

echo "enable-share: enabled ${NAME}"
echo "enable-share: apply with root: bash ${SRC}/install-root.sh"
exit 0
