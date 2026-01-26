#!/bin/bash

mkdir -p /app/streams

start_channel() {
    NAME="$1"
    TYPE="$2"
    URL="$3"
    KEY="$4"
    HEADERS="$5"

    OUT="/app/streams/$NAME"
    mkdir -p "$OUT"

    echo "[+] Starting $NAME"

    # build ffmpeg headers
    FFMPEG_HEADERS=""
    if [ -n "$HEADERS" ]; then
        while IFS="=" read -r k v; do
            FFMPEG_HEADERS+="$k: $v\r\n"
        done <<< "$HEADERS"
    fi

    if [ "$TYPE" = "mpd-clearkey" ]; then

        n_m3u8dl-re "$URL" \
          --key "$KEY" \
          --header "$HEADERS" \
          --live-real-time-merge \
          --live-pipe-mux \
          --no-log \
          -o - | \
        ffmpeg -re \
          -headers "$FFMPEG_HEADERS" \
          -i pipe:0 \
          -c copy \
          -f hls \
          -hls_time 6 \
          -hls_list_size 6 \
          -hls_flags delete_segments+append_list \
          "$OUT/index.m3u8" \
          >/dev/null 2>&1 &

    else

        ffmpeg -re \
          -headers "$FFMPEG_HEADERS" \
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
      map("\(.key)=\(.value)") |
      join("\n")
    ')

    if ! pgrep -f "/app/streams/$NAME/index.m3u8" >/dev/null; then
        start_channel "$NAME" "$TYPE" "$URL" "$KEY" "$HEADERS"
    fi

  done

  sleep 10
done
