#!/bin/bash

STREAM_DIR="/streams"
TMP_DIR="/tmpstreams"

mkdir -p "$STREAM_DIR" "$TMP_DIR"

start_clearkey() {

    NAME="$1"
    URL="$2"
    KEY="$3"
    HEADERS_RAW="$4"

    OUT="$STREAM_DIR/$NAME"
    TMP="$TMP_DIR/$NAME"

    mkdir -p "$OUT" "$TMP"

    echo "[+] ClearKey start: $NAME"

    NM_HEADERS=()
    while IFS="=" read -r k v; do
        NM_HEADERS+=(--header "$k: $v")
    done <<< "$HEADERS_RAW"

    n_m3u8dl-re "$URL" \
      --key "$KEY" \
      "${NM_HEADERS[@]}" \
      --save-dir "$TMP" \
      --live-real-time-decryption \
      --disable-update-check \
      --no-log &

    # wait for segments
    while true; do
        ls "$TMP"/*.ts >/dev/null 2>&1 && break
        sleep 2
    done

    ffmpeg -re \
      -f concat \
      -safe 0 \
      -i <(for f in "$TMP"/*.ts; do echo "file '$f'"; done) \
      -c copy \
      -f hls \
      -hls_time 6 \
      -hls_list_size 6 \
      -hls_flags delete_segments+append_list \
      "$OUT/index.m3u8" \
      >/dev/null 2>&1 &
}

start_direct() {

    NAME="$1"
    URL="$2"
    HEADERS="$3"

    OUT="$STREAM_DIR/$NAME"
    mkdir -p "$OUT"

    echo "[+] Direct start: $NAME"

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
      map("\(.key)=\(.value)") |
      join("\n")
    ')

    if [ "$TYPE" = "mpd-clearkey" ]; then
        pgrep -f "$TMP_DIR/$NAME" >/dev/null || \
        start_clearkey "$NAME" "$URL" "$KEY" "$HEADERS"
    else
        pgrep -f "$STREAM_DIR/$NAME/index.m3u8" >/dev/null || \
        start_direct "$NAME" "$URL" "$HEADERS"
    fi

  done
  sleep 15
done
