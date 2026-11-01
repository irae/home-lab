#!/bin/sh
set -eu
if [ "$#" -eq 0 ]; then
    set -- -l
fi
exec /command/s6-envdir -Lf -- /run/s6/container_environment \
    /usr/bin/env HOME=/opt/data SHELL=/bin/bash /bin/bash "$@"
