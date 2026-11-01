if [[ $- == *i* && $EUID == 0 ]]; then
    printf '\n%s\n' \
        'WARNING: ROOT MAINTENANCE SHELL — DO NOT RUN PI OR OTHER AGENTS HERE.' \
        'Root is only for deliberate setup, configuration, and repairs.' \
        'Coding, tools, and agent work must run as the existing haku user.' \
        '' \
        'Exit this shell and run one of these on the Docker host:' \
        '  docker exec -it --user haku --env HOME=/home/haku local-llm-sandboxed pi' \
        '  docker exec -it --user haku --env HOME=/home/haku local-llm-sandboxed bash' \
        'Or connect over SSH:' \
        '  ssh -p 2201 haku@sheeta' \
        '' >&2
fi
