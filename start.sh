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

# ====== PREP ======
mkdir -p "$LOG_DIR" "$PID_DIR"

echo "🚀 Démarrage projet (backend + frontend)"
echo "   Projet : $PROJECT_DIR"
echo "   Logs   : $LOG_DIR"
echo "   PIDs   : $PID_DIR"

# ====== BACKEND (Python) ======
echo "🐍 Backend : préparation de l'environnement Python…"
cd "$BACKEND_DIR"
if [ ! -d "venv" ]; then
  python3 -m venv venv
fi
# Met à jour pip + installe requirements si présents
source venv/bin/activate
python -m pip install --upgrade pip >/dev/null
if [ -f requirements.txt ]; then
  python -m pip install -r requirements.txt
fi
deactivate

echo "🐍 Backend : lancement…"
# On tente de forcer l'écoute réseau via variables standards (si ton app les supporte)
# Sinon, adapte la commande "python app.py" selon ton serveur (Flask, FastAPI, etc.)
nohup bash -lc "cd '$BACKEND_DIR' && source venv/bin/activate && \
  HOST=0.0.0.0 PORT=$BACKEND_PORT python app.py" \
  >"$LOG_DIR/backend.log" 2>&1 &

BACKEND_PID=$!
echo $BACKEND_PID > "$PID_DIR/backend.pid"
echo "   → PID: $BACKEND_PID | Log: $LOG_DIR/backend.log"

# ====== FRONTEND (React) ======
echo "🧩 Frontend : installation (si nécessaire)…"
cd "$FRONT_DIR"
if [ -f yarn.lock ]; then
  PKG_MGR_CMD="yarn"
elif [ -f package-lock.json ]; then
  PKG_MGR_CMD="npm"
else
  # par défaut, tenter yarn puis npm
  if command -v yarn >/dev/null 2>&1; then PKG_MGR_CMD="yarn"; else PKG_MGR_CMD="npm"; fi
fi

if [ ! -d node_modules ]; then
  if [ "$PKG_MGR_CMD" = "yarn" ]; then
    yarn install
  else
    npm install
  fi
fi

echo "🧩 Frontend : lancement…"
# Détection Vite (dev server) vs CRA (react-scripts)
if grep -q "\"vite\"" package.json 2>/dev/null; then
  # Vite
  if [ "$PKG_MGR_CMD" = "yarn" ]; then
    FRONT_CMD="yarn dev --host $FRONT_HOST --port $FRONT_PORT"
  else
    FRONT_CMD="npx vite --host $FRONT_HOST --port $FRONT_PORT"
  fi
else
  # CRA (create-react-app) – HOST/PORT par variables env
  if [ "$PKG_MGR_CMD" = "yarn" ]; then
    FRONT_CMD="HOST=$FRONT_HOST PORT=$FRONT_PORT yarn start"
  else
    FRONT_CMD="HOST=$FRONT_HOST PORT=$FRONT_PORT npm start"
  fi
fi

nohup bash -lc "cd '$FRONT_DIR' && $FRONT_CMD" \
  >"$LOG_DIR/frontend.log" 2>&1 &

FRONT_PID=$!
echo $FRONT_PID > "$PID_DIR/frontend.pid"
echo "   → PID: $FRONT_PID | Log: $LOG_DIR/frontend.log"

# ====== INFOS ======
echo
echo "✅ Tout est lancé !"
echo "   Backend (port $BACKEND_PORT) PID: $(cat "$PID_DIR/backend.pid")"
echo "   Front   (http://$FRONT_HOST:$FRONT_PORT) PID: $(cat "$PID_DIR/frontend.pid")"
echo
echo "🔎 Pour suivre les logs :"
echo "   tail -f '$LOG_DIR/backend.log'"
echo "   tail -f '$LOG_DIR/frontend.log'"
