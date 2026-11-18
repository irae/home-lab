#!/command/with-contenv sh
set -eu
export HOME=/opt/data
export T3CODE_HOME="$HOME/.t3"
cd "$HOME"
exec /command/s6-setuidgid hermes sh -ec '
    umask 077
    mkdir -p "$T3CODE_HOME"
    exec /usr/local/bin/t3 serve --lan --port 3773 --base-dir "$T3CODE_HOME" >"$T3CODE_HOME/hermes-service.log" 2>&1
'
