#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Configuration Raspberry Pi pour projet (npm only, Hotspot NetworkManager)"

# ===== 1) Système =====
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget build-essential python3 python3-pip python3-venv network-manager

# ===== 2) Node.js (LTS 20) =====
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
echo "➡️  Node: $(node -v) | npm: $(npm -v)"

# ===== 3) Cloner le projet =====
PROJECT_DIR="$HOME/TSD"
if [ -d "$PROJECT_DIR/.git" ]; then
  echo "⚠️  Repo déjà présent → pull --rebase"
  git -C "$PROJECT_DIR" pull --rebase
else
  echo "📥 Clonage du projet…"
  git clone https://github.com/K0ola/TSD.git "$PROJECT_DIR"
fi
cd "$PROJECT_DIR"

# ===== 4) Backend Python =====
cd server
python3 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
if [ -f requirements.txt ]; then
  python -m pip install -r requirements.txt
fi
deactivate

# ===== 5) Frontend (npm) =====
cd ../front-end
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

# ===== 6) Hotspot Wi-Fi avec NetworkManager (Bookworm) =====
echo "📡 Configuration du hotspot via NetworkManager…"

SSID="${SSID:-TSD_K0la}"
WIFI_PSK="${WIFI_PSK:-daylight}"
CON_NAME="Hotspot-$SSID"

# Évite les conflits si hostapd/dnsmasq avaient été configurés avant
sudo systemctl stop hostapd dnsmasq 2>/dev/null || true
sudo systemctl disable hostapd dnsmasq 2>/dev/null || true

# Active le Wi-Fi et détecte l’interface (wlan0 généralement)
sudo nmcli radio wifi on
IFACE="$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi"{print $1; exit}')"
IFACE="${IFACE:-wlan0}"
echo "➡️  Interface Wi-Fi détectée : $IFACE"

# Supprime une éventuelle ancienne connexion de même nom
if nmcli -t -f NAME con show | grep -qx "$CON_NAME"; then
  sudo nmcli con delete "$CON_NAME"
fi

# Crée la connexion AP
sudo nmcli con add type wifi ifname "$IFACE" con-name "$CON_NAME" ssid "$SSID"
sudo nmcli con modify "$CON_NAME" \
  802-11-wireless.mode ap 802-11-wireless.band bg \
  wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$WIFI_PSK" \
  ipv4.method shared

# (Option) Adresse IP voulue (sinon NM mettra 10.42.0.1)
sudo nmcli con modify "$CON_NAME" ipv4.addresses 192.168.4.1/24 || true

# Monte le hotspot
sudo nmcli con up "$CON_NAME"

# Récupère l'IP réellement assignée
HOTSPOT_IP="$(ip -4 addr show dev "$IFACE" | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
echo "📡 Hotspot actif → SSID: $SSID | Mot de passe: $WIFI_PSK | IP du Pi: ${HOTSPOT_IP:-10.42.0.1}"

# ===== 7) Rappels =====
echo "✅ Installation terminée !"
echo "➡️  Backend :  cd $PROJECT_DIR/server && source venv/bin/activate && python app.py"
echo "➡️  Front   :  cd $PROJECT_DIR/front-end && HOST=0.0.0.0 PORT=3000 npm start"
echo "ℹ️  Depuis ton PC (connecté au Wi-Fi $SSID) :"
echo "    Front  →  http://${HOTSPOT_IP:-10.42.0.1}:3000"
echo "    API    →  http://${HOTSPOT_IP:-10.42.0.1}:8000 (si backend sur 8000)"


# chmod +x setup.sh
# ./setup.sh