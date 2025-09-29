#!/bin/bash

echo "🚀 Configuration Raspberry Pi pour projet"

# === 1. Mise à jour système ===
sudo apt update && sudo apt upgrade -y

# === 2. Outils de base ===
sudo apt install -y git curl wget build-essential python3 python3-pip python3-venv

# === 3. Installer Node.js (LTS) ===
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g yarn

# === 4. Cloner le projet Git ===
PROJECT_DIR="$HOME/TSD"
if [ -d "$PROJECT_DIR" ]; then
    echo "⚠️  Le dossier existe déjà, mise à jour..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "📥 Clonage du projet..."
    git clone https://github.com/TON_USER/TON_REPO.git "$PROJECT_DIR" !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    cd "$PROJECT_DIR"
fi

# === 5. Backend Python (server) ===
cd server
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi
deactivate

# === 6. Frontend React ===
cd ../front-end
yarn install || npm install

# === 7. Config Hotspot Wi-Fi (hostapd + dnsmasq) ===
sudo apt install -y hostapd dnsmasq

# Stop services while we configure
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Sauvegarde ancienne config
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

# Nouvelle config dnsmasq
cat <<EOF | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

# Config réseau statique
cat <<EOF | sudo tee -a /etc/dhcpcd.conf

interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

# Config hostapd
cat <<EOF | sudo tee /etc/hostapd/hostapd.conf
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

sudo sed -i 's|#DAEMON_CONF="".*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Redémarrage des services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl restart dhcpcd
sudo systemctl start hostapd
sudo systemctl start dnsmasq

echo "📡 Hotspot Wi-Fi activé → SSID: CarPi | Mot de passe: raspberry123"

# === 8. Instructions de lancement ===
echo "✅ Installation terminée !"
echo "Pour démarrer le backend :"
echo "  cd $PROJECT_DIR/server && source venv/bin/activate && python app.py"
echo "Pour démarrer le frontend :"
echo "  cd $PROJECT_DIR/front-end && yarn install && yarn start"


# chmod +x setup.sh
# ./setup.sh

