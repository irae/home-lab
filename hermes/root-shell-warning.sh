if [[ $- == *i* && $EUID == 0 ]]; then
    printf '\n%s\n' \
        'WARNING: root maintenance shell — not for agent or coding work.' \
        'Use this shell only for setup, configuration, and repairs.' \
        '' \
        'For normal use, exit and run one of these on the Docker host:' \
        '  docker exec -it --user hermes --env HOME=/opt/data hermes hermes' \
        '  docker exec -it --user hermes --env HOME=/opt/data hermes bash' \
        'Or connect over SSH:' \
        '  ssh -p 2202 hermes@sheeta' \
        '' >&2
fi
