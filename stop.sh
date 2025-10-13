#!/usr/bin/env bash
set -euo pipefail

echo "🛑 Arrêt du projet…"

PROJECT_DIR="${PROJECT_DIR:-$HOME/TSD}"
PID_DIR="$PROJECT_DIR/.pids"

kill_if_running() {
  local pidfile="$1"
  local label="$2"
  if [[ -f "$pidfile" ]]; then
    local pid; pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && ps -p "$pid" >/dev/null 2>&1; then
      echo "➡️  Arrêt $label (PID $pid)…"
      kill "$pid" 2>/dev/null || true
      sleep 0.5
      kill -9 "$pid" 2>/dev/null || true
    else
      echo "⚠️  $label déjà arrêté."
    fi
    rm -f "$pidfile"
  else
    echo "⚠️  Pas de PID pour $label."
  fi
}

# 1) Backend & Front (via PID files)
kill_if_running "$PID_DIR/backend.pid"  "backend"
kill_if_running "$PID_DIR/frontend.pid" "frontend"

# 2) Fallback par ports (si nécessaire)
for port in 8000 3000; do
  if ss -lptn "sport = :$port" | awk 'NR>1{exit 1}'; then
    : # libre
  else
    echo "🔧 Port $port encore occupé → kill via fuser…"
    sudo fuser -k "${port}/tcp" 2>/dev/null || true
  fi
done

echo "✅ Tout est arrêté proprement !"
