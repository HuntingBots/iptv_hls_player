#!/bin/bash

echo "[+] IPTV system starting..."

mkdir -p /app/streams /app/tmp

# start nginx in background
nginx &

# small delay
sleep 2

# start worker (foreground)
exec bash /app/worker.sh
