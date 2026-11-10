#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if ! command -v opencode >/dev/null 2>&1; then
  echo "[workshop] OpenCode is not installed. Rebuild the Codespace container."
  exit 1
fi

LOGIN_FILE="$ROOT/.opencode-login.txt"
LOG_FILE="$ROOT/.opencode-web.log"
PID_FILE="$ROOT/.opencode-web.pid"
PORT=4096

if [ -f "$LOGIN_FILE" ]; then
  PASSWORD="$(sed -n 's/^Password: //p' "$LOGIN_FILE" | head -n 1)"
else
  PASSWORD="$(openssl rand -hex 24)"
  umask 077
  {
    echo "OpenCode Web login"
    echo "Username: opencode"
    echo "Password: $PASSWORD"
    echo "Port: $PORT (private Codespaces forwarded port)"
  } > "$LOGIN_FILE"
  chmod 600 "$LOGIN_FILE"
fi

if [ -z "$PASSWORD" ]; then
  echo "[workshop] Login file is invalid: $LOGIN_FILE"
  exit 1
fi

STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$PORT/" 2>/dev/null || true)"
if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
  echo "[workshop] OpenCode Web is already responding on port $PORT."
  echo "[workshop] Private login details are in .opencode-login.txt"
  exit 0
fi

nohup env OPENCODE_SERVER_USERNAME=opencode OPENCODE_SERVER_PASSWORD="$PASSWORD" \
  opencode web --hostname 0.0.0.0 --port "$PORT" \
  > "$LOG_FILE" 2>&1 < /dev/null &
echo $! > "$PID_FILE"

for attempt in $(seq 1 30); do
  STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$PORT/" 2>/dev/null || true)"
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
    echo "[workshop] OpenCode Web is ready on port $PORT."
    echo "[workshop] Username: opencode"
    echo "[workshop] Password is stored privately in .opencode-login.txt"
    exit 0
  fi
  sleep 1
done

echo "[workshop] OpenCode Web did not become ready. Recent log:"
tail -n 60 "$LOG_FILE" || true
exit 1
