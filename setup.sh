#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Configuration Raspberry Pi pour projet (npm only)"

# === 1) Mise à jour système ===
sudo apt update && sudo apt upgrade -y

# === 2) Outils de base ===
sudo apt install -y git curl wget build-essential python3 python3-pip python3-venv

# === 3) Node.js (LTS 20) ===
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
echo "➡️  Node: $(node -v) | npm: $(npm -v)"

# === 4) Cloner le projet Git ===
PROJECT_DIR="$HOME/TSD"
if [ -d "$PROJECT_DIR/.git" ]; then
  echo "⚠️  Repo déjà présent → pull"
  git -C "$PROJECT_DIR" pull --rebase
else
  echo "📥 Clonage du projet…"
  git clone https://github.com/K0ola/TSD.git "$PROJECT_DIR"
fi
cd "$PROJECT_DIR"

# === 5) Backend Python (server) ===
cd server
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi
deactivate

# === 6) Frontend React (npm) ===
cd ../front-end
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

# === 7) Hotspot Wi-Fi (hostapd + dnsmasq) ===
sudo apt install -y hostapd dnsmasq

# Stop services while configuring
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true

# Sauvegarde ancienne config dnsmasq si elle existe
if [ -f /etc/dnsmasq.conf ]; then
  sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
fi

# Nouvelle config dnsmasq
sudo tee /etc/dnsmasq.conf >/dev/null <<'EOF'
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

# Config réseau statique
sudo tee -a /etc/dhcpcd.conf >/dev/null <<'EOF'

interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

# Config hostapd
sudo tee /etc/hostapd/hostapd.conf >/dev/null <<'EOF'
interface=wlan0
driver=nl80211
ssid=TSD_K0la
hw_mode=g
channel=7
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=daylight
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

sudo sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Redémarrage des services
sudo systemctl unmask hostapd || true
sudo systemctl enable hostapd dnsmasq
sudo systemctl restart dhcpcd
sudo systemctl start hostapd
sudo systemctl start dnsmasq

echo "📡 Hotspot Wi-Fi activé → SSID: TSD_K0la | Mot de passe: daylight | IP du Pi: 192.168.4.1"

# === 8) Rappels de lancement ===
echo "✅ Installation terminée !"
echo "➡️  Backend :  cd $PROJECT_DIR/server && source venv/bin/activate && python app.py"
echo "➡️  Front   :  cd $PROJECT_DIR/front-end && npm start"


# chmod +x setup.sh
# ./setup.sh