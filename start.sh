#!/bin/bash

mkdir -p /app/hls

echo "[+] Starting NGINX"
nginx

echo "[+] Starting IPTV channels"

jq -c '.[]' /app/channels.json | while read ch; do

  NAME=$(echo "$ch" | jq -r '.name')
  TYPE=$(echo "$ch" | jq -r '.type')
  URL=$(echo "$ch" | jq -r '.url')
  KEY=$(echo "$ch" | jq -r '.key // empty')

  mkdir -p /app/hls/$NAME

  if [ "$TYPE" = "mpd" ]; then
    ffmpeg \
      -decryption_key "$KEY" \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      -hls_segment_filename "/app/hls/$NAME/seg_%03d.ts" \
      "/app/hls/$NAME/stream.m3u8" &
  else
    ffmpeg \
      -reconnect 1 \
      -reconnect_streamed 1 \
      -reconnect_delay_max 5 \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      -hls_segment_filename "/app/hls/$NAME/seg_%03d.ts" \
      "/app/hls/$NAME/stream.m3u8" &
  fi

done

echo "[+] Starting Cloudflare Named Tunnel"
cloudflared tunnel run iptv
