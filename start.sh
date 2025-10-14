#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
PROJECT_DIR="${PROJECT_DIR:-$HOME/TSD}"
BACKEND_DIR="$PROJECT_DIR/server"
LOG_DIR="$PROJECT_DIR/.logs"
PID_DIR="$PROJECT_DIR/.pids"

BACKEND_PORT="${BACKEND_PORT:-8000}"
OFFLINE="${OFFLINE:-1}"          # 1 = n'installe rien (offline). Mettre OFFLINE=0 pour forcer l'install.

mkdir -p "$LOG_DIR" "$PID_DIR"

# ========= Utils =========
ensure_pid_not_running() {
  local pidfile="$1"
  if [[ -f "$pidfile" ]]; then
    local pid; pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && ps -p "$pid" >/dev/null 2>&1; then
      echo "🔧 Kill ancien processus (PID $pid)…"
      kill "$pid" 2>/dev/null || true
      sleep 0.3
    fi
    rm -f "$pidfile"
  fi
}

ensure_port_free() {
  local port="$1"
  if ss -lptn "sport = :$port" | awk 'NR>1{exit 1}'; then
    return 0
  fi
  echo "🔧 Port $port occupé → kill via fuser…"
  sudo fuser -k "${port}/tcp" 2>/dev/null || true
  for _ in {1..20}; do
    ss -lptn "sport = :$port" | awk 'NR>1{exit 1}' && break
    sleep 0.2
  done
}

detect_pi_ip() {
  local iface="${1:-wlan0}"
  local ip
  ip="$(ip -4 addr show "$iface" | sed -n 's/.* inet \([0-9.]*\).*/\1/p' | head -n1)"
  if [[ -z "$ip" ]]; then
    ip="$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
  fi
  echo "${ip:-127.0.0.1}"
}

# ========= IP =========
IFACE="${IFACE:-wlan0}"
PI_IP="$(detect_pi_ip "$IFACE")"

echo "🚀 Démarrage BACKEND uniquement"
echo "   Projet : $PROJECT_DIR"
echo "   IFACE  : $IFACE  | IP: $PI_IP"
echo

# ========= BACKEND =========
echo "🐍 Backend : préparation de l'environnement…"
cd "$BACKEND_DIR"

if [[ ! -d venv ]]; then
  echo "   ➜ Création venv (une fois pour toutes)"
  python3 -m venv venv
fi

if [[ "$OFFLINE" != "1" ]]; then
  source venv/bin/activate
  python -m pip install --upgrade pip >/dev/null 2>&1 || true
  [[ -f requirements.txt ]] && python -m pip install -r requirements.txt >/dev/null 2>&1 || true
  deactivate
fi

echo "🐍 Backend : lancement…"
ensure_pid_not_running "$PID_DIR/backend.pid"
ensure_port_free "$BACKEND_PORT"

nohup bash -lc "cd '$BACKEND_DIR' && source venv/bin/activate && HOST=0.0.0.0 PORT=$BACKEND_PORT python app.py" \
  > "$LOG_DIR/backend.log" 2>&1 &

echo $! > "$PID_DIR/backend.pid"
BACK_PID="$(cat "$PID_DIR/backend.pid")"
echo "   → PID backend: $BACK_PID | Log: $LOG_DIR/backend.log"

echo
echo "✅ Backend prêt !"
echo "   API Health  : http://$PI_IP:$BACKEND_PORT/api/health"
echo "   Flux MJPEG  : http://$PI_IP:$BACKEND_PORT/api/camera/video_feed"
echo
echo "📜 Logs (live) — Ctrl+C = quitte le tail (le backend continue) :"
tail -n +1 -F "$LOG_DIR/backend.log"
