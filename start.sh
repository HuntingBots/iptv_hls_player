#!/bin/bash
set -e

echo "[+] Starting NGINX..."
nginx

echo "[+] Starting IPTV streams..."

mkdir -p /var/log
touch /var/log/iptv.log

RECONNECT_FLAGS="-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5"

jq -c '.[]' /app/channels.json | while read channel; do

  NAME=$(echo "$channel" | jq -r '.name')
  TYPE=$(echo "$channel" | jq -r '.type')
  URL=$(echo "$channel" | jq -r '.url')
  KEY=$(echo "$channel" | jq -r '.key // empty')

  OUTDIR="/app/hls/$NAME"
  mkdir -p "$OUTDIR"

  echo "[+] Starting channel: $NAME"

  if [[ "$TYPE" == "mpd" && -n "$KEY" ]]; then

    # MPD (DRM)
    ffmpeg \
      -loglevel warning \
      -stats \
      $RECONNECT_FLAGS \
      -decryption_key "$KEY" \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      "$OUTDIR/index.m3u8" >> /var/log/iptv.log 2>&1 &

  else

    # m3u8 / ts
    ffmpeg \
      -loglevel warning \
      -stats \
      $RECONNECT_FLAGS \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 4 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      "$OUTDIR/index.m3u8" >> /var/log/iptv.log 2>&1 &

  fi

done

echo "[✓] All channels running"
echo "[✓] Log file: /var/log/iptv.log"

# keep container alive
tail -f /var/log/iptv.log
