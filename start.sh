#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
PROJECT_DIR="$HOME/TSD"
BACKEND_DIR="$PROJECT_DIR/server"
FRONT_DIR="$PROJECT_DIR/front-end"
LOG_DIR="$PROJECT_DIR/.logs"
PID_DIR="$PROJECT_DIR/.pids"

BACKEND_PORT="${BACKEND_PORT:-8000}"
CAM_PORT="${CAM_PORT:-5000}"
FRONT_PORT="${FRONT_PORT:-3000}"
FRONT_HOST="0.0.0.0"

mkdir -p "$LOG_DIR" "$PID_DIR"

# --- IP du Pi (hotspot = wlan0) ---
IFACE="${IFACE:-wlan0}"
PI_IP="$(ip -4 addr show "$IFACE" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
PI_IP="${PI_IP:-127.0.0.1}"

echo "🚀 Démarrage projet (backend + caméra + frontend)"
echo "   Projet : $PROJECT_DIR"
echo "   Logs   : $LOG_DIR"
echo "   PIDs   : $PID_DIR"
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
echo "   → PID: $(cat "$PID_DIR/backend.pid") | Log: $LOG_DIR/backend.log"

# ====== CAMERA STREAM (Flask MJPEG) ======
echo "📷 Camera : lancement…"
nohup bash -lc "cd '$BACKEND_DIR' && source venv/bin/activate && HOST=0.0.0.0 PORT=$CAM_PORT python camera_stream.py" \
  >"$LOG_DIR/camera.log" 2>&1 &
echo $! > "$PID_DIR/camera.pid"
echo "   → PID: $(cat "$PID_DIR/camera.pid") | Log: $LOG_DIR/camera.log"

# ====== FRONTEND (React) ======
echo "🧩 Frontend : install (si besoin)…"
cd "$FRONT_DIR"
PKG_MGR_CMD="npm"
[ -f yarn.lock ] && command -v yarn >/dev/null 2>&1 && PKG_MGR_CMD="yarn"

if [ ! -d node_modules ]; then
  [ "$PKG_MGR_CMD" = "yarn" ] && yarn install || npm install
fi

echo "🧩 Frontend : lancement…"
if grep -q "\"vite\"" package.json 2>/dev/null; then
  FRONT_CMD=$([ "$PKG_MGR_CMD" = "yarn" ] && echo "yarn dev --host $FRONT_HOST --port $FRONT_PORT" || echo "npx vite --host $FRONT_HOST --port $FRONT_PORT")
else
  FRONT_CMD=$([ "$PKG_MGR_CMD" = "yarn" ] && echo "HOST=$FRONT_HOST PORT=$FRONT_PORT yarn start" || echo "HOST=$FRONT_HOST PORT=$FRONT_PORT npm start")
fi

nohup bash -lc "cd '$FRONT_DIR' && $FRONT_CMD" \
  >"$LOG_DIR/frontend.log" 2>&1 &
echo $! > "$PID_DIR/frontend.pid"
echo "   → PID: $(cat "$PID_DIR/frontend.pid") | Log: $LOG_DIR/frontend.log"

# ====== INFOS ======
echo
echo "✅ Tout est lancé !"
echo "   Backend API     : http://$PI_IP:$BACKEND_PORT"
echo "   Caméra (MJPEG)  : http://$PI_IP:$CAM_PORT/video_feed"
echo "   Front (React)   : http://$PI_IP:$FRONT_PORT"
echo
echo "ℹ️  Dans l’UI React, mets l'API Base URL sur :  http://$PI_IP:$CAM_PORT"
echo "    (le composant ajoutera /video_feed tout seul)"
echo
echo "🔎 Logs :"
echo "   tail -f '$LOG_DIR/backend.log'"
echo "   tail -f '$LOG_DIR/camera.log'"
echo "   tail -f '$LOG_DIR/frontend.log'"



