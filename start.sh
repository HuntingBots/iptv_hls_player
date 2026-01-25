#!/bin/bash
set -e

echo "[+] IPTV system starting..."

mkdir -p /app/streams /app/output /app/logs

nginx

sleep 2

bash /app/nm3u8dl_worker.sh &

while true; do
    bash /app/generate_m3u.sh
    sleep 20
done
