#!/bin/bash
# Install the stacks image-update systemd units and the LAN IPv6-off sysctl.
#
# Run as root (sudo is not installed on this box).
# Starting the persistent timer can run a missed update immediately.
# The unit uses the live worker at /data/stacks/host/stacks-image-update.sh.
#
# Review the files in this directory before running this.

UNIT_SRC="/data/stacks/host"
UNIT_DST="/etc/systemd/system"
SERVICE_NAME="stacks-image-update.service"
TIMER_NAME="stacks-image-update.timer"
SYSCTL_NAME="90-lan-ipv6-off.conf"

echo "install-root: start"

if [ "$(id -u)" -ne 0 ]
then
    echo "install-root: ERROR must run as root"
    exit 1
fi

echo "install-root: WARNING the persistent timer may run a missed update immediately"
echo "install-root: validate units"
systemd-analyze verify "${UNIT_SRC}/${SERVICE_NAME}" "${UNIT_SRC}/${TIMER_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR unit validation failed"
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

echo "install-root: copy ${SYSCTL_NAME}"
cp "${UNIT_SRC}/${SYSCTL_NAME}" "/etc/sysctl.d/${SYSCTL_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR copy sysctl failed"
    exit 1
fi

echo "install-root: apply ${SYSCTL_NAME}"
sysctl -p "/etc/sysctl.d/${SYSCTL_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR apply sysctl failed"
    exit 1
fi

echo "install-root: enable and start ${TIMER_NAME}"
systemctl enable --now "${TIMER_NAME}"
if [ $? -ne 0 ]
then
    echo "install-root: ERROR enable or start timer failed"
    exit 1
fi

if ! systemctl is-enabled --quiet "${TIMER_NAME}" || ! systemctl is-active --quiet "${TIMER_NAME}"
then
    echo "install-root: ERROR timer must be enabled and active"
    exit 1
fi

echo "install-root: done"
echo "install-root: timer is enabled and active"
echo "install-root: check with: systemctl status stacks-image-update.timer"
echo "install-root: check update results with: journalctl -u stacks-image-update.service -n 100"
exit 0
