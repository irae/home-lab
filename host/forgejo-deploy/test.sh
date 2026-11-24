#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
pid=
port=15008
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

TEST_OUTPUT="$tmp/output" FORGEJO_DEPLOY_HOST=127.0.0.1 FORGEJO_DEPLOY_PORT=$port \
  node /data/stacks/host/forgejo-deploy/server.mjs --config "$tmp/config.json" >"$tmp/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 20); do curl --silent --fail "http://127.0.0.1:$port/healthz" >/dev/null && break; sleep 0.1; done

curl --silent --fail "http://127.0.0.1:$port/healthz" | jq -e '.apps == 1' >/dev/null
[ "$(curl --silent --output /dev/null --write-out '%{http_code}' -X POST "http://127.0.0.1:$port/v1/deploy/test" -d '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}')" = 401 ]
curl --silent --fail -X POST \
  -H 'Authorization: Bearer test-token' -H 'Content-Type: application/json' \
  -d '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' \
  "http://127.0.0.1:$port/v1/deploy/test" | jq -e '.exitCode == 0' >/dev/null
[ "$(cat "$tmp/output")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]

echo "forgejo-deploy tests passed"
