#!/bin/bash

echo "[+] IPTV system starting..."

mkdir -p /streams 
# start nginx in background
nginx &

# small delay
sleep 2

# start worker (foreground)
exec bash /app/worker.sh
