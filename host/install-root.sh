#!/bin/bash
# Install the stacks image-update systemd units.
#
# Run as root in a root SSH session (sudo is not installed on this box).
# This script copies unit files into /etc/systemd/system/ and enables the
# timer. It does not start a compose update now. It does not touch the
# reboot cron. It does not copy the worker script; the unit execs the git
# copy at /data/stacks/host/stacks-image-update.sh.
#
# Review the files in this directory before running this.

UNIT_SRC="/data/stacks/host"
UNIT_DST="/etc/systemd/system"
SERVICE_NAME="stacks-image-update.service"
TIMER_NAME="stacks-image-update.timer"

echo "install-root: start"

if [ "$(id -u)" -ne 0 ]
then
    echo "install-root: ERROR must run as root"
    exit 1
fi

echo "install-root: copy ${SERVICE_NAME}"
cp "${UNIT_SRC}/${SERVICE_NAME}" "${UNIT_DST}/${SERVICE_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR copy service failed"
    exit 1
fi

echo "install-root: copy ${TIMER_NAME}"
cp "${UNIT_SRC}/${TIMER_NAME}" "${UNIT_DST}/${TIMER_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR copy timer failed"
    exit 1
fi

echo "install-root: daemon-reload"
systemctl daemon-reload
if [ $? -ne 0 ]
then
    echo "install-root: ERROR daemon-reload failed"
    exit 1
fi

echo "install-root: enable ${TIMER_NAME}"
systemctl enable "${TIMER_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR enable timer failed"
    exit 1
fi

echo "install-root: done"
echo "install-root: timer is enabled, not started as a compose run"
echo "install-root: check with: systemctl status stacks-image-update.timer"
echo "install-root: test run with: systemctl start stacks-image-update.service"
exit 0
