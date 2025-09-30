#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
PROJECT_DIR="$HOME/TSD"
BACKEND_DIR="$PROJECT_DIR/server"
FRONT_DIR="$PROJECT_DIR/front-end"
LOG_DIR="$PROJECT_DIR/.logs"
PID_DIR="$PROJECT_DIR/.pids"

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONT_PORT="${FRONT_PORT:-3000}"
FRONT_HOST="0.0.0.0"

mkdir -p "$LOG_DIR" "$PID_DIR"

# --- IP du Pi (hotspot = wlan0) ---
IFACE="${IFACE:-wlan0}"
PI_IP="$(ip -4 addr show "$IFACE" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
PI_IP="${PI_IP:-127.0.0.1}"

echo "🚀 Démarrage projet (backend + frontend)"
echo "   Projet : $PROJECT_DIR"
echo "   IFACE  : $IFACE  | IP: $PI_IP"

# ====== BACKEND (Flask) ======
echo "🐍 Backend : venv & deps…"
cd "$BACKEND_DIR"
if [ ! -d "venv" ]; then python3 -m venv venv; fi
source venv/bin/activate
python -m pip install --upgrade pip >/dev/null
[ -f requirements.txt ] && python -m pip install -r requirements.txt >/dev/null
deactivate

echo "🐍 Backend : lancement…"
nohup bash -lc "cd '$BACKEND_DIR' && source venv/bin/activate && HOST=0.0.0.0 PORT=$BACKEND_PORT python app.py" \
  >"$LOG_DIR/backend.log" 2>&1 &
echo $! > "$PID_DIR/backend.pid"
echo "   → PID backend: $(cat "$PID_DIR/backend.pid") | Log: $LOG_DIR/backend.log"

# ====== FRONTEND (React / npm) ======
echo "🧩 Frontend : install (si besoin)…"
cd "$FRONT_DIR"
if [ ! -d node_modules ]; then npm install; fi

echo "🧩 Frontend : lancement…"
nohup bash -lc "cd '$FRONT_DIR' && HOST=$FRONT_HOST PORT=$FRONT_PORT npm start" \
  >"$LOG_DIR/frontend.log" 2>&1 &
echo $! > "$PID_DIR/frontend.pid"
echo "   → PID front: $(cat "$PID_DIR/frontend.pid") | Log: $LOG_DIR/frontend.log"

# ====== INFOS ======
echo
echo "✅ Tout est lancé !"
echo "   Frontend       : http://$PI_IP:$FRONT_PORT"
echo "   Backend API    : http://$PI_IP:$BACKEND_PORT"
echo "   Flux MJPEG     : http://$PI_IP:$BACKEND_PORT/api/camera/video_feed"
echo
echo "ℹ️  Dans l’UI React, l’API par défaut sera :  http://$PI_IP:$BACKEND_PORT"
echo "   (tu peux aussi la saisir à la main dans le champ “API Base URL”)."
echo
echo "🔎 Logs :"
echo "   tail -f '$LOG_DIR/backend.log'"
echo "   tail -f '$LOG_DIR/frontend.log'"
