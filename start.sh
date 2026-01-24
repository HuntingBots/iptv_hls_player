#!/bin/bash
set -e

echo "[+] Starting NGINX..."
nginx

mkdir -p /app/hls

echo "[+] Starting all channels..."

jq -c '.channels[]' /app/channels.json | while read ch; do
  NAME=$(echo "$ch" | jq -r '.name')
  TYPE=$(echo "$ch" | jq -r '.type')
  URL=$(echo "$ch" | jq -r '.url')
  KEY=$(echo "$ch" | jq -r '.key // empty')

  mkdir -p /app/hls/$NAME

  echo "[+] Channel: $NAME ($TYPE)"

  if [ "$TYPE" = "mpd" ]; then
    ffmpeg \
      -headers "User-Agent: Mozilla/5.0" \
      -decryption_key "$KEY" \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 10 \
      -hls_flags delete_segments \
      /app/hls/$NAME/index.m3u8 &

  elif [ "$TYPE" = "m3u8" ]; then
    ffmpeg \
      -headers "User-Agent: Mozilla/5.0" \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 10 \
      -hls_flags delete_segments \
      /app/hls/$NAME/index.m3u8 &

  elif [ "$TYPE" = "ts" ]; then
    ffmpeg \
      -headers "User-Agent: Mozilla/5.0" \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 10 \
      -hls_flags delete_segments \
      /app/hls/$NAME/index.m3u8 &
  fi
done

echo "[+] Starting Cloudflare tunnel (no domain mode)..."

while true; do
  cloudflared tunnel --url http://localhost:80 --no-autoupdate
  sleep 5
done
