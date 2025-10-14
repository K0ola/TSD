#!/usr/bin/env bash
set -euo pipefail

echo "🛑 Arrêt du backend…"

PROJECT_DIR="${PROJECT_DIR:-$HOME/TSD}"
PID_DIR="$PROJECT_DIR/.pids"

if [[ -f "$PID_DIR/backend.pid" ]]; then
  pid="$(cat "$PID_DIR/backend.pid" 2>/dev/null || true)"
  if [[ -n "${pid:-}" ]] && ps -p "$pid" >/devnull 2>&1; then
    echo "➡️  kill $pid"
    kill "$pid" || true
    sleep 0.5
  fi
  rm -f "$PID_DIR/backend.pid"
fi

# sécurité: tue un éventuel python app.py restant
pkill -f "python app.py" >/dev/null 2>&1 || true

echo "✅ Backend arrêté."
