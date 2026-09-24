#!/bin/sh
set -eu
cp /data/stacks/local-llm-sandboxed/local-llm-sandboxed-egress.service /etc/systemd/system/local-llm-sandboxed-egress.service
systemctl daemon-reload
systemctl enable --now local-llm-sandboxed-egress.service
