#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
PROJECT_DIR="${PROJECT_DIR:-$HOME/TSD}"
BACKEND_DIR="$PROJECT_DIR/server"
FRONT_DIR="$PROJECT_DIR/front-end"
LOG_DIR="$PROJECT_DIR/.logs"
PID_DIR="$PROJECT_DIR/.pids"

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONT_PORT="${FRONT_PORT:-3000}"
FRONT_HOST="${FRONT_HOST:-0.0.0.0}"

# Par défaut on NE FAIT AUCUNE INSTALL (offline).
# Si tu veux forcer une install ponctuelle: OFFLINE=0 ./start.sh
OFFLINE="${OFFLINE:-1}"

mkdir -p "$LOG_DIR" "$PID_DIR"

# ========= UTILITAIRE =========
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
    # secours: prends la première IPv4 non loopback
    ip="$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
  fi
  echo "${ip:-127.0.0.1}"
}

# ========= IP =========
IFACE="${IFACE:-wlan0}"
PI_IP="$(detect_pi_ip "$IFACE")"

echo "🚀 Démarrage projet (backend + frontend)"
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
# N'installe pas si OFFLINE=1
if [[ "$OFFLINE" != "1" ]]; then
  # Petites installs silencieuses si tu veux forcer (réseau requis)
  source venv/bin/activate
  python -m pip install --upgrade pip >/dev/null 2>&1 || true
  [[ -f requirements.txt ]] && python -m pip install -r requirements.txt >/dev/null 2>&1 || true
  deactivate
fi

echo "🐍 Backend : lancement…"
ensure_pid_not_running "$PID_DIR/backend.pid"
ensure_port_free "$BACKEND_PORT"

# lance en arrière-plan + log
nohup bash -lc "cd '$BACKEND_DIR' && source venv/bin/activate && HOST=0.0.0.0 PORT=$BACKEND_PORT python app.py" \
  > "$LOG_DIR/backend.log" 2>&1 &

echo $! > "$PID_DIR/backend.pid"
BACK_PID="$(cat "$PID_DIR/backend.pid")"
echo "   → PID backend: $BACK_PID | Log: $LOG_DIR/backend.log"

# stream des logs backend dans ce terminal
echo
echo "📜 Logs Backend (live) — Ctrl+C ne stoppe que le tail (pas le backend)"
tail -n +1 -F "$LOG_DIR/backend.log" &
TAIL_BACK_PID=$!

# Nettoyage du tail à la sortie du script
trap 'kill $TAIL_BACK_PID >/dev/null 2>&1 || true' EXIT

# ========= FRONTEND =========
echo
echo "🧩 Frontend : préparation…"
cd "$FRONT_DIR"

if [[ ! -d node_modules ]]; then
  if [[ "$OFFLINE" = "1" ]]; then
    echo "   ⚠️  node_modules absent et OFFLINE=1 → je ne lance pas le front dev."
    echo "      ➜ Pour l’interface, utilise le front *buildé* servi par Flask si présent."
    FRONT_SKIP=1
  else
    echo "   ➜ Installation des dépendances (réseau requis)…"
    npm ci >/dev/null 2>&1 || npm install >/dev/null 2>&1
    FRONT_SKIP=0
  fi
else
  FRONT_SKIP=0
fi

if [[ "$FRONT_SKIP" = "0" ]]; then
  echo "🧩 Frontend : lancement dev server…"
  ensure_pid_not_running "$PID_DIR/frontend.pid"
  ensure_port_free "$FRONT_PORT"
  # Important pour que le front appelle le backend local sans Internet
  REACT_APP_API_BASE="http://$PI_IP:$BACKEND_PORT"

  nohup bash -lc "cd '$FRONT_DIR' \
    && REACT_APP_API_BASE='$REACT_APP_API_BASE' HOST='$FRONT_HOST' PORT='$FRONT_PORT' npm start" \
    > "$LOG_DIR/frontend.log" 2>&1 &

  echo $! > "$PID_DIR/frontend.pid"
  FRONT_PID="$(cat "$PID_DIR/frontend.pid")"
  echo "   → PID front: $FRONT_PID | Log: $LOG_DIR/frontend.log"
fi

# ========= INFOS =========
echo
echo "✅ Tout est lancé !"
echo "   Backend API    : http://$PI_IP:$BACKEND_PORT"
echo "   Flux MJPEG     : http://$PI_IP:$BACKEND_PORT/api/camera/video_feed"
if [[ "$FRONT_SKIP" = "0" ]]; then
  echo "   Front (dev)    : http://$PI_IP:$FRONT_PORT"
fi
echo
echo "ℹ️  L’UI React parle au backend via :  http://$PI_IP:$BACKEND_PORT"
echo
echo "🔎 Logs front :  tail -f '$LOG_DIR/frontend.log'"
echo "⏹️  Stopper le suivi logs backend (seulement le tail) :  kill $TAIL_BACK_PID"
