#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-"$PROJECT_ROOT/backend"}"
VENV_DIR="${VENV_DIR:-"$BACKEND_ROOT/.venv"}"
HOST="${APP_HOST:-0.0.0.0}"
PORT="${APP_PORT:-8000}"
SERVICE_NAME="${SERVICE_NAME:-xivdaily-backend}"
INSTALL_SYSTEMD=0
START_FOREGROUND=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy/deploy-backend-linux.sh [options]

Options:
  --host <host>           Uvicorn bind host, default: 0.0.0.0
  --port <port>           Uvicorn bind port, default: 8000
  --install-systemd       Write and enable a systemd service, requires sudo/root
  --start-foreground      Start uvicorn in current shell after setup
  -h, --help              Show help

Environment:
  APP_ENV, APP_LOG_LEVEL, DATABASE_URL, LLM_*, ZOTERO_* can be set in backend/.env.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --install-systemd)
      INSTALL_SYSTEMD=1
      shift
      ;;
    --start-foreground)
      START_FOREGROUND=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing command: $name" >&2
    return 1
  fi
}

ensure_python() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
    return
  fi
  if command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
    return
  fi
  echo "Missing python3. Install Python 3.11+ first." >&2
  exit 1
}

write_env_if_missing() {
  local env_file="$BACKEND_ROOT/.env"
  if [[ -f "$env_file" ]]; then
    echo "Keep existing .env: $env_file"
    return
  fi

  cat >"$env_file" <<EOF
APP_NAME=XivDaily Backend
APP_ENV=production
APP_HOST=$HOST
APP_PORT=$PORT
APP_LOG_LEVEL=INFO
DATABASE_URL=sqlite:///./data/xivdaily.db
ARXIV_BASE_URL=https://export.arxiv.org/api/query
ARXIV_REQUEST_TIMEOUT_SECONDS=20
ARXIV_CACHE_TTL_SECONDS=900
LLM_BASE_URL=https://yangyioryy.cc.cd
LLM_API_KEY=
LLM_MODEL=glm5
LLM_REQUEST_TIMEOUT_SECONDS=30
ZOTERO_BASE_URL=https://api.zotero.org
ZOTERO_USER_ID=
ZOTERO_LIBRARY_TYPE=user
ZOTERO_API_KEY=
ZOTERO_TARGET_COLLECTION_NAME=XivDaily
EOF
  chmod 600 "$env_file"
  echo "Created .env template: $env_file"
  echo "Fill LLM_API_KEY/ZOTERO_* in backend/.env before using AI or Zotero features."
}

install_systemd_service() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "--install-systemd requires root. Run with sudo or root." >&2
    exit 1
  fi

  local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
  cat >"$service_file" <<EOF
[Unit]
Description=XivDaily Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$BACKEND_ROOT
EnvironmentFile=$BACKEND_ROOT/.env
Environment=PYTHONPATH=$BACKEND_ROOT
ExecStart=$VENV_DIR/bin/python -m uvicorn app.main:app --host $HOST --port $PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
  systemctl --no-pager --full status "$SERVICE_NAME" || true
}

ensure_python
require_command curl

mkdir -p "$BACKEND_ROOT/data"
cd "$BACKEND_ROOT"

"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r "$BACKEND_ROOT/requirements.txt"

write_env_if_missing

export PYTHONPATH="$BACKEND_ROOT"
"$VENV_DIR/bin/python" -m alembic upgrade head

if [[ "$INSTALL_SYSTEMD" -eq 1 ]]; then
  install_systemd_service
fi

if [[ "$START_FOREGROUND" -eq 1 ]]; then
  exec "$VENV_DIR/bin/python" -m uvicorn app.main:app --host "$HOST" --port "$PORT"
fi

if [[ "$INSTALL_SYSTEMD" -eq 1 ]]; then
  sleep 2
  curl --fail --show-error --silent "http://127.0.0.1:${PORT}/health"
  echo
else
  echo "Setup complete."
  echo "Start backend:"
  echo "  cd $BACKEND_ROOT && PYTHONPATH=$BACKEND_ROOT $VENV_DIR/bin/python -m uvicorn app.main:app --host $HOST --port $PORT"
fi
