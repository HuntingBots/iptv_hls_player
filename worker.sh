#!/bin/bash

STREAM_DIR="/app/streams"
TMP_DIR="/app/tmp"

mkdir -p "$STREAM_DIR" "$TMP_DIR"

start_channel() {

    NAME="$1"
    TYPE="$2"
    URL="$3"
    KEY="$4"
    HEADERS="$5"

    OUT="$STREAM_DIR/$NAME"
    TMP="$TMP_DIR/$NAME"

    mkdir -p "$OUT" "$TMP"

    echo "[+] Starting $NAME"

    if [ "$TYPE" = "mpd-clearkey" ]; then

        echo "[*] ClearKey MPD detected"

        # Decrypt MPD continuously
        n_m3u8dl-re "$URL" \
          --key "$KEY" \
          --save-dir "$TMP" \
          --live-real-time-decryption \
          --disable-update-check \
          --no-log &

        sleep 6

        # Convert decrypted TS → HLS
        ffmpeg -re \
          -stream_loop -1 \
          -i "$TMP"/*.ts \
          -c copy \
          -f hls \
          -hls_time 6 \
          -hls_list_size 6 \
          -hls_flags delete_segments+append_list \
          "$OUT/index.m3u8" \
          >/dev/null 2>&1 &

    else
        # m3u8 / ts direct rebroadcast
        ffmpeg -re \
          -headers "$HEADERS" \
          -i "$URL" \
          -c copy \
          -f hls \
          -hls_time 6 \
          -hls_list_size 6 \
          -hls_flags delete_segments+append_list \
          "$OUT/index.m3u8" \
          >/dev/null 2>&1 &
    fi
}

while true; do
  jq -c '.channels[]' /app/channels.json | while read ch; do

    NAME=$(echo "$ch" | jq -r '.name')
    TYPE=$(echo "$ch" | jq -r '.type')
    URL=$(echo "$ch" | jq -r '.url')
    KEY=$(echo "$ch" | jq -r '.key // empty')

    HEADERS=$(echo "$ch" | jq -r '
      .headers // {} |
      to_entries |
      map("\(.key): \(.value)") |
      join("\r\n")
    ')

    if ! pgrep -f "$STREAM_DIR/$NAME/index.m3u8" >/dev/null; then
        start_channel "$NAME" "$TYPE" "$URL" "$KEY" "$HEADERS"
    fi

  done

  sleep 15
done
