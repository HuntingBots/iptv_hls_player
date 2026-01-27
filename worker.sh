#!/bin/bash

STREAM_DIR="/streams"
TMP="/tmp/iptv"

mkdir -p "$STREAM_DIR" "$TMP"

start_mpd_clearkey() {
    NAME="$1"
    URL="$2"
    KID="$3"
    KEY="$4"

    OUT="$STREAM_DIR/$NAME"
    mkdir -p "$OUT"

    echo "[+] ClearKey channel start: $NAME"

    shaka-packager \
      "input=$URL,stream=video,init_segment=$TMP/${NAME}_v_init.mp4,segment_template=$TMP/${NAME}_v_\$Number\$.m4s" \
      "input=$URL,stream=audio,init_segment=$TMP/${NAME}_a_init.mp4,segment_template=$TMP/${NAME}_a_\$Number\$.m4s" \
      --enable_raw_key_decryption \
      --keys key_id=$KID:key=$KEY \
      --quiet &

    sleep 5

    ffmpeg -re \
      -i "$TMP/${NAME}_v_init.mp4" \
      -c copy \
      -f hls \
      -hls_time 6 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      "$OUT/index.m3u8" \
      >/dev/null 2>&1 &
}

start_normal() {
    NAME="$1"
    URL="$2"

    OUT="$STREAM_DIR/$NAME"
    mkdir -p "$OUT"

    echo "[+] Normal channel start: $NAME"

    ffmpeg -re \
      -i "$URL" \
      -c copy \
      -f hls \
      -hls_time 6 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      "$OUT/index.m3u8" \
      >/dev/null 2>&1 &
}

while true; do
  jq -c '.channels[]' /app/channels.json | while read ch; do

    NAME=$(echo "$ch" | jq -r .name)
    TYPE=$(echo "$ch" | jq -r .type)

    if pgrep -f "$STREAM_DIR/$NAME/index.m3u8" >/dev/null; then
      continue
    fi

    if [ "$TYPE" = "mpd-clearkey" ]; then
      URL=$(echo "$ch" | jq -r .url)
      KID=$(echo "$ch" | jq -r .kid)
      KEY=$(echo "$ch" | jq -r .key)
      start_mpd_clearkey "$NAME" "$URL" "$KID" "$KEY"
    else
      URL=$(echo "$ch" | jq -r .url)
      start_normal "$NAME" "$URL"
    fi

  done

  sleep 10
done
