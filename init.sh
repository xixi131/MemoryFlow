#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
BACKEND_DIR="$PROJECT_ROOT/back-end"
FRONTEND_DIR="$PROJECT_ROOT/front-end"

# Default to the web dev flow because it is easier to validate with browser MCP.
FRONTEND_MODE="${MEMORYFLOW_FRONTEND_MODE:-web}"
BACKEND_PORT="${MEMORYFLOW_BACKEND_PORT:-8080}"
backend_pid=""

print_backend_config_help() {
  echo
  echo "MemoryFlow backend dev configuration is missing."
  echo "Provide one of the following before running init.sh:"
  echo "1. Create back-end/uploads/config/application-dev.yml"
  echo "2. Or export the required Spring env vars, for example:"
  echo "   SPRING_DATASOURCE_URL"
  echo "   SPRING_DATASOURCE_USERNAME"
  echo "   SPRING_DATASOURCE_PASSWORD"
  echo
  echo "Optional env vars that may also be needed depending on your setup:"
  echo "  SPRING_DATA_REDIS_HOST"
  echo "  SPRING_DATA_REDIS_PORT"
  echo "  SPRING_DATA_REDIS_PASSWORD"
  echo "  JWT_SECRET"
  echo
}

find_listen_pid_by_port() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n 1
}

ensure_backend_port_available() {
  local existing_pid existing_cmd
  existing_pid="$(find_listen_pid_by_port "$BACKEND_PORT" || true)"

  if [[ -z "$existing_pid" ]]; then
    return
  fi

  existing_cmd="$(ps -p "$existing_pid" -o command= 2>/dev/null || true)"

  if [[ "$existing_cmd" == *"com.memoryflow.MemoryFlowApplication"* && "$existing_cmd" == *"$BACKEND_DIR"* ]]; then
    echo "Found stale MemoryFlow backend on port ${BACKEND_PORT} (PID ${existing_pid}), stopping it..."
    kill "$existing_pid" 2>/dev/null || true

    for _ in {1..10}; do
      if ! kill -0 "$existing_pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done

    if kill -0 "$existing_pid" 2>/dev/null; then
      echo "Failed to stop stale backend process PID ${existing_pid}. Please stop it manually and retry." >&2
      exit 1
    fi
    return
  fi

  echo "Backend port ${BACKEND_PORT} is already in use by PID ${existing_pid}." >&2
  if [[ -n "$existing_cmd" ]]; then
    echo "Process: ${existing_cmd}" >&2
  fi
  echo "Stop that process or set MEMORYFLOW_BACKEND_PORT to another port, then rerun init.sh." >&2
  exit 1
}

cleanup() {
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then
    echo
    echo "Stopping backend (${backend_pid})..."
    kill "$backend_pid" 2>/dev/null || true
    wait "$backend_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

if [[ ! -d "$BACKEND_DIR" ]]; then
  echo "Missing backend directory: $BACKEND_DIR" >&2
  exit 1
fi

if [[ ! -d "$FRONTEND_DIR" ]]; then
  echo "Missing frontend directory: $FRONTEND_DIR" >&2
  exit 1
fi

if [[ "$FRONTEND_MODE" != "web" && "$FRONTEND_MODE" != "electron" ]]; then
  echo "Unsupported MEMORYFLOW_FRONTEND_MODE: $FRONTEND_MODE" >&2
  echo "Use 'web' or 'electron'." >&2
  exit 1
fi

if [[ ! -f "$BACKEND_DIR/uploads/config/application-dev.yml" ]]; then
  if [[ -z "${SPRING_DATASOURCE_URL:-}" || -z "${SPRING_DATASOURCE_USERNAME:-}" || -z "${SPRING_DATASOURCE_PASSWORD:-}" ]]; then
    print_backend_config_help
    exit 1
  fi
fi

echo "Starting MemoryFlow backend..."
cd "$BACKEND_DIR"

export JAVA_HOME="${JAVA_HOME:-$("/usr/libexec/java_home" -v 17)}"
export PATH="$JAVA_HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export SERVER_PORT="$BACKEND_PORT"

ensure_backend_port_available

mvn spring-boot:run &
backend_pid=$!

sleep 3
if ! kill -0 "$backend_pid" 2>/dev/null; then
  echo "Backend failed to stay running. See logs above for details." >&2
  exit 1
fi

echo "Preparing MemoryFlow frontend dependencies..."
cd "$FRONTEND_DIR"

if [[ ! -d node_modules ]]; then
  npm install
fi

if [[ "$FRONTEND_MODE" == "electron" ]]; then
  echo "Starting MemoryFlow frontend in Electron mode..."
  npm run electron:dev
else
  echo "Starting MemoryFlow frontend in web mode..."
  npm run dev
fi
