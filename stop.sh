set -euo pipefail

echo "🛑 Arrêt du projet en cours..."

PROJECT_DIR="$HOME/TSD"

# === 1) Backend Python ===
if pgrep -f "python app.py" >/dev/null; then
  echo "➡️  Arrêt du backend..."
  pkill -f "python app.py"
else
  echo "⚠️  Backend déjà arrêté."
fi

# === 2) Frontend React ===
if pgrep -f "react-scripts start" >/dev/null; then
  echo "➡️  Arrêt du frontend React..."
  pkill -f "react-scripts start"
else
  echo "⚠️  Frontend déjà arrêté."
fi

# === 3) Hotspot Wi-Fi (optionnel) ===
echo "➡️  Arrêt des services hostapd + dnsmasq..."
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true

echo "✅ Tout est arrêté proprement !"
