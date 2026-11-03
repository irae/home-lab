#!/bin/bash
# Update every compose project under /data/stacks.
#
# For each directory that contains a compose.yaml, run three commands in
# order, as separate steps (not chained):
#   1. docker compose build --pull
#   2. docker compose pull
#   3. docker compose up -d
#
# This script is the worker for stacks-image-update.service. systemd runs it
# as root. irae is in group docker, but this is a system timer so it does not
# depend on a user session.
#
# Failures: if one stack fails, log it and continue to the next stack so a
# broken project does not block other projects. The script exits 1 if any
# stack failed, so the systemd unit records a failure.
#
# There is no retry loop. There is no "already up to date" shortcut.

STACKS_ROOT="/data/stacks"
failed=0
did_any=0

echo "stacks-image-update: start $(date --iso-8601=seconds)"
echo "stacks-image-update: root ${STACKS_ROOT}"

if [ ! -d "${STACKS_ROOT}" ]
then
    echo "stacks-image-update: ERROR stacks root is not a directory"
    exit 1
fi

for entry in "${STACKS_ROOT}"/*
do
    if [ ! -d "${entry}" ]
    then
        continue
    fi

    compose_file="${entry}/compose.yaml"
    if [ ! -f "${compose_file}" ]
    then
        echo "stacks-image-update: skip $(basename "${entry}") (no compose.yaml)"
        continue
    fi

    stack_name="$(basename "${entry}")"
    did_any=1
    echo "stacks-image-update: stack ${stack_name}"

    cd "${entry}"
    if [ $? -ne 0 ]
    then
        echo "stacks-image-update: ERROR cannot cd to ${entry}"
        failed=1
        continue
    fi

    echo "stacks-image-update: ${stack_name}: compose build --pull"
    docker compose build --pull
    if [ $? -ne 0 ]
    then
        echo "stacks-image-update: ERROR ${stack_name}: build failed"
        failed=1
        continue
    fi

    echo "stacks-image-update: ${stack_name}: compose pull"
    docker compose pull
    if [ $? -ne 0 ]
    then
        echo "stacks-image-update: ERROR ${stack_name}: pull failed"
        failed=1
        continue
    fi

    echo "stacks-image-update: ${stack_name}: compose up -d"
    docker compose up -d
    if [ $? -ne 0 ]
    then
        echo "stacks-image-update: ERROR ${stack_name}: up failed"
        failed=1
        continue
    fi

    echo "stacks-image-update: ${stack_name}: ok"
done

if [ "${did_any}" -eq 0 ]
then
    echo "stacks-image-update: ERROR no compose.yaml found under ${STACKS_ROOT}"
    exit 1
fi

echo "stacks-image-update: end $(date --iso-8601=seconds)"

if [ "${failed}" -ne 0 ]
then
    echo "stacks-image-update: finished with errors"
    exit 1
fi

echo "stacks-image-update: finished ok"
exit 0
