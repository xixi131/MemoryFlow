#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/back-end"
FRONTEND_DIR="$SCRIPT_DIR/front-end"
BACKEND_PORT=8080
FRONTEND_PORT=3101
ISLAND_BUNDLE_ID="com.memoryflow.island"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
backend_pid=""
frontend_pid=""

find_listen_pids() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | sort -u
}

wait_for_port() {
  local port="$1"
  local label="$2"
  local attempts="$3"

  for _ in $(seq 1 "$attempts"); do
    if [[ -n "$(find_listen_pids "$port" || true)" ]]; then
      return 0
    fi
    sleep 1
  done

  echo "$label did not start on port $port." >&2
  return 1
}

stop_port_owners() {
  local port="$1"
  local label="$2"
  local pids pid command

  pids="$(find_listen_pids "$port" || true)"
  [[ -z "$pids" ]] && return 0

  echo "Port $port is occupied; stopping existing $label process..."
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    echo "  PID $pid: ${command:-unknown command}"
    kill "$pid" 2>/dev/null || true
  done <<< "$pids"

  for _ in {1..10}; do
    if [[ -z "$(find_listen_pids "$port" || true)" ]]; then
      echo "Port $port is now available."
      return 0
    fi
    sleep 1
  done

  echo "$label did not stop cleanly; forcing port $port to close..." >&2
  pids="$(find_listen_pids "$port" || true)"
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill -KILL "$pid" 2>/dev/null || true
  done <<< "$pids"

  for _ in {1..5}; do
    if [[ -z "$(find_listen_pids "$port" || true)" ]]; then
      echo "Port $port is now available."
      return 0
    fi
    sleep 1
  done

  echo "Failed to release $label port $port." >&2
  return 1
}

refresh_island_url_handler() {
  local current_app=""
  local island_pid command app registered_paths
  local removed=0

  island_pid="$(pgrep -x MemoryFlowIsland | head -n 1 || true)"
  if [[ -n "$island_pid" ]]; then
    command="$(ps -p "$island_pid" -o command= 2>/dev/null || true)"
    if [[ "$command" == *"/Contents/MacOS/MemoryFlowIsland"* ]]; then
      current_app="${command%%/Contents/MacOS/MemoryFlowIsland*}"
    fi
  fi

  registered_paths="$($LSREGISTER -dump | awk -v bundle_id="$ISLAND_BUNDLE_ID" '
    /^path:/ {
      path = $0
      sub(/^path:[[:space:]]+/, "", path)
      sub(/[[:space:]]+\(0x[0-9a-fA-F]+\)$/, "", path)
    }
    $1 == "identifier:" && $2 == bundle_id { print path }
  ' | sort -u)"

  while IFS= read -r app; do
    [[ -z "$app" || "$app" == "$current_app" ]] && continue
    if [[ "$app" == /private/tmp/* ||
          "$app" == /tmp/* ||
          "$app" == "$HOME/Library/Developer/Xcode/DerivedData/"* ]]; then
      $LSREGISTER -u "$app" >/dev/null 2>&1 || true
      (( removed += 1 ))
    fi
  done <<< "$registered_paths"

  if [[ -n "$current_app" && -d "$current_app" ]]; then
    $LSREGISTER -f -R -trusted "$current_app"
  fi
  $LSREGISTER -gc >/dev/null 2>&1 || true

  if (( removed > 0 )); then
    echo "Removed $removed stale MemoryFlow Island URL handler registration(s)."
  fi
}

cleanup() {
  trap - EXIT INT TERM

  if [[ -n "$frontend_pid" ]] && kill -0 "$frontend_pid" 2>/dev/null; then
    echo "Stopping frontend (PID $frontend_pid)..."
    kill "$frontend_pid" 2>/dev/null || true
  fi

  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then
    echo "Stopping backend (PID $backend_pid)..."
    kill "$backend_pid" 2>/dev/null || true
  fi

  wait 2>/dev/null || true
}

trap cleanup EXIT INT TERM

if [[ ! -f "$BACKEND_DIR/uploads/config/application-dev.yml" ]]; then
  if [[ -z "${SPRING_DATASOURCE_URL:-}" ||
        -z "${SPRING_DATASOURCE_USERNAME:-}" ||
        -z "${SPRING_DATASOURCE_PASSWORD:-}" ]]; then
    echo "Missing back-end/uploads/config/application-dev.yml and datasource environment variables." >&2
    exit 1
  fi
fi

refresh_island_url_handler

stop_port_owners "$BACKEND_PORT" "backend"
echo "Starting backend on http://127.0.0.1:$BACKEND_PORT/api ..."
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17)}"
export PATH="$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

(
  cd "$BACKEND_DIR"
  SERVER_PORT="$BACKEND_PORT" mvn spring-boot:run
) &
backend_pid=$!
wait_for_port "$BACKEND_PORT" "Backend" 60

stop_port_owners "$FRONTEND_PORT" "frontend"
echo "Starting frontend on http://127.0.0.1:$FRONTEND_PORT ..."
(
  cd "$FRONTEND_DIR"
  if [[ ! -d node_modules ]]; then
    npm install
  fi
  npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT"
) &
frontend_pid=$!
wait_for_port "$FRONTEND_PORT" "Frontend" 30

echo
echo "MemoryFlow mac-island development services are ready:"
echo "  Frontend: http://127.0.0.1:$FRONTEND_PORT"
echo "  Login:    http://127.0.0.1:$FRONTEND_PORT/#/login?callback=desktop&client=mac-island"
echo "  Backend:  http://127.0.0.1:$BACKEND_PORT/api"
echo
echo "Press Ctrl-C to stop services started by this script."

while true; do
  if [[ -n "$backend_pid" ]] && ! kill -0 "$backend_pid" 2>/dev/null; then
    echo "Backend process exited unexpectedly." >&2
    exit 1
  fi
  if [[ -n "$frontend_pid" ]] && ! kill -0 "$frontend_pid" 2>/dev/null; then
    echo "Frontend process exited unexpectedly." >&2
    exit 1
  fi
  sleep 2
done
