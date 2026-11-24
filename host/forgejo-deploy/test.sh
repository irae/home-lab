#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
pid=
cleanup() {
  [ -z "$pid" ] || kill "$pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

cat > "$tmp/deploy.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$FORGEJO_DEPLOY_SHA" > "$TEST_OUTPUT"
EOF
chmod +x "$tmp/deploy.sh"
printf '%s' test-token > "$tmp/key"
jq -n --arg key "$tmp/key" --arg command "$tmp/deploy.sh" \
  '{apps:{test:{keyFile:$key,command:[$command],timeoutMs:5000}}}' > "$tmp/config.json"

TEST_OUTPUT="$tmp/output" FORGEJO_DEPLOY_SOCKET="$tmp/server.sock" \
  node /data/stacks/host/forgejo-deploy/server.mjs --config "$tmp/config.json" >"$tmp/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 20); do [ -S "$tmp/server.sock" ] && break; sleep 0.1; done

curl --silent --fail --unix-socket "$tmp/server.sock" http://localhost/healthz | jq -e '.apps == 1' >/dev/null
[ "$(curl --silent --output /dev/null --write-out '%{http_code}' --unix-socket "$tmp/server.sock" -X POST http://localhost/v1/deploy/test -d '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}')" = 401 ]
curl --silent --fail --unix-socket "$tmp/server.sock" -X POST \
  -H 'Authorization: Bearer test-token' -H 'Content-Type: application/json' \
  -d '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' \
  http://localhost/v1/deploy/test | jq -e '.exitCode == 0' >/dev/null
[ "$(cat "$tmp/output")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]

echo "forgejo-deploy tests passed"
