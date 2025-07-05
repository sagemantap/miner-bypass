#!/bin/bash

##   Linux-Junk-Cleaner    :       Junk cleaner + proxy/DPI checker
##   Author                :       ArjunCodesmith + ChatGPT (modded by Ram Danis)
##   Version               :       1.1.0

author="ArjunCodesmith + Ram Danis"
version="v1.1.0"
LOG_FILE="$HOME/cleanup_log.txt"

typing_effect() {
    local text="$1"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.02
    done
    echo
}

banner() {
    echo -e "\e[1;31m
         ┌─────────┐     ┌─────────┐
       ──────│\e[94m [▓▓▓▓▓▓▓▓░░░░░] \e[1;31m│──────
 ─────────── │  \e[38;5;83m LINUX JΞNK \e[1;31m   │ ───────────
 ─────────── │ \e[38;5;83m C L E A N E R \e[1;31m │ ───────────
       ──────│\e[94m [░░░░░▓▓▓▓▓▓▓▓] \e[1;31m│──────
         └─────────┘     └─────────┘\e[0m"
    echo -e "         \033[40;38;5;83m Version \033[30;48;5;83m $version \033[0m"
    echo -e "    \033[30;48;5;83m   Copyright \033[40;38;5;83m $author \033[0m"
    echo -e " \e[1;34m--------------------------------------------\e[0m"
}

dpi_firewall_tips() {
    echo -e "\n\e[1;36m[~] Passive DPI Firewall Evasion Tips:\e[0m"
    echo -e " - SOCKS5 Proxy via ssh: ssh -D 1080 user@host"
    echo -e " - Use Tor: torsocks curl https://example.com"
    echo -e " - Use DoH DNS (dns.google, Cloudflare)"
    echo -e " - Override User-Agent in curl/wget"
}

check_proxy_status() {
    echo -e "\n\e[1;36m[~] Checking SOCKS5 proxy on 127.0.0.1:1080...\e[0m"
    curl --socks5-hostname 127.0.0.1:1080 -s https://ipinfo.io/ip >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32m[✔] SOCKS5 proxy is active.\e[0m"
        echo "[SOCKS5 proxy active]" >> "$LOG_FILE"
    else
        echo -e "\e[1;33m[!] SOCKS5 proxy not available.\e[0m"
        echo "[SOCKS5 proxy inactive]" >> "$LOG_FILE"
    fi
}

check_doh_dns() {
    echo -e "\n\e[1;36m[~] Checking DNS-over-HTTPS (DoH)...\e[0m"
    doh=$(curl -s -H 'accept: application/dns-json'         'https://dns.google/resolve?name=example.com&type=A' | grep -o '"Status":0')
    if [[ $doh == '"Status":0' ]]; then
        echo -e "\e[1;32m[✔] DNS-over-HTTPS working (Google).\e[0m"
        echo "[DoH resolver working]" >> "$LOG_FILE"
    else
        echo -e "\e[1;33m[!] DoH resolver failed.\e[0m"
        echo "[DoH failed]" >> "$LOG_FILE"
    fi
}

check_tor() {
    echo -e "\n\e[1;36m[~] Checking Tor (torsocks)...\e[0m"
    if command -v torsocks >/dev/null; then
        torsocks curl -s https://check.torproject.org | grep -q "Congratulations"
        if [[ $? -eq 0 ]]; then
            echo -e "\e[1;32m[✔] Tor is working.\e[0m"
            echo "[Tor working]" >> "$LOG_FILE"
        else
            echo -e "\e[1;33m[!] Tor not active.\e[0m"
            echo "[Tor failed]" >> "$LOG_FILE"
        fi
    else
        echo -e "\e[1;33m[!] torsocks not installed.\e[0m"
    fi
}

clean_cache() { typing_effect "🧹 Cleaning cache..."; find ~/.cache -type f -delete -print 2>/dev/null >> "$LOG_FILE"; }
clean_temp() { typing_effect "🗑️ Cleaning temp..."; find /tmp -type f -delete -print 2>/dev/null >> "$LOG_FILE"; find "$HOME/tmp" -type f -delete -print 2>/dev/null >> "$LOG_FILE"; }
clean_logs() { typing_effect "📄 Cleaning logs..."; find "$HOME" -name "*.log" -delete -print 2>/dev/null >> "$LOG_FILE"; }
clean_backup() { typing_effect "📦 Cleaning .bak..."; find "$HOME" -name "*.bak" -delete -print 2>/dev/null >> "$LOG_FILE"; }
apt_clean() { typing_effect "📦 Cleaning apt cache..."; sudo apt-get clean >> "$LOG_FILE" 2>/dev/null; }
apt_autoremove() { typing_effect "🧼 Removing unused packages..."; sudo apt autoremove -y >> "$LOG_FILE" 2>/dev/null; }

success_msg() { echo -e "\n\e[40;38;5;83m✅ Cleanup done. Check $LOG_FILE \e[0m\n"; }

interactive_cleanup() {
    read -p $'\e[1;35mClean logs? (y/n): \e[0m' l
    read -p $'\e[1;35mClean cache? (y/n): \e[0m' c
    read -p $'\e[1;35mClean temp? (y/n): \e[0m' t
    read -p $'\e[1;35mClean .bak files? (y/n): \e[0m' b
    read -p $'\e[1;35mAPT cache cleanup? (y/n): \e[0m' a
    read -p $'\e[1;35mAutoremove unused packages? (y/n): \e[0m' u

    [[ $l == [yY] ]] && clean_logs
    [[ $c == [yY] ]] && clean_cache
    [[ $t == [yY] ]] && clean_temp
    [[ $b == [yY] ]] && clean_backup
    [[ $a == [yY] ]] && apt_clean
    [[ $u == [yY] ]] && apt_autoremove
    success_msg
}

cli_mode() {
    for arg in "$@"; do
        case "$arg" in
            -c) clean_cache ;;
            -t) clean_temp ;;
            -l) clean_logs ;;
            -b) clean_backup ;;
            -p) apt_clean ;;
            -n) apt_autoremove ;;
            -a) clean_cache; clean_temp; clean_logs; clean_backup; apt_clean; apt_autoremove ;;
            -h|--help)
                echo -e "\nUsage: $0 [options]"
                echo " -c  Clean user cache"
                echo " -t  Clean /tmp and ~/tmp"
                echo " -l  Clean *.log files"
                echo " -b  Clean *.bak files"
                echo " -p  Clean APT package cache"
                echo " -n  Remove unused packages"
                echo " -a  All clean"
                echo " -h  Help"
                exit 0
                ;;
            *) echo -e "\e[1;31mUnknown option: $arg\e[0m" ;;
        esac
    done
    success_msg
}

banner
dpi_firewall_tips
check_proxy_status
check_doh_dns
check_tor

if [[ $# -eq 0 ]]; then
    interactive_cleanup
else
    cli_mode "$@"
fi
