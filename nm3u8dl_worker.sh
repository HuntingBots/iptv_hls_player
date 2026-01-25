#!/bin/bash

CHANNELS="/app/channels.json"

while true; do

jq -c '.[]' "$CHANNELS" | while read -r ch; do

    name=$(echo "$ch" | jq -r '.name')
    type=$(echo "$ch" | jq -r '.type')
    url=$(echo "$ch" | jq -r '.url')
    key=$(echo "$ch" | jq -r '.key // empty')

    safe=$(echo "$name" | tr ' ' '_' | tr -cd '[:alnum:]_')
    out="/app/streams/$safe"

    headers=""
    echo "$ch" | jq -r '.headers // {} | to_entries[]? | "\(.key): \(.value)"' |
    while read -r h; do
        headers+=" --header \"$h\""
    done

    echo "[+] Channel: $name ($type)"

    # ---- MPD ----
    if [[ "$type" == "mpd" ]]; then

        cmd="N_m3u8DL-RE \"$url\" \
            --live-real-time-merge \
            --live-pipe-mux \
            -o \"$out\" \
            --no-log"

        [[ -n "$key" ]] && cmd+=" --key $key"
        [[ -n "$headers" ]] && cmd+="$headers"

        eval "timeout 3600 $cmd &"

    # ---- M3U8 ----
    elif [[ "$type" == "m3u8" ]]; then

        cmd="N_m3u8DL-RE \"$url\" \
            --live-real-time-merge \
            --live-pipe-mux \
            -o \"$out\" \
            --no-log"

        [[ -n "$headers" ]] && cmd+="$headers"

        eval "timeout 3600 $cmd &"

    # ---- TS ----
    elif [[ "$type" == "ts" ]]; then

        ffmpeg \
          -loglevel quiet \
          -headers "$(echo "$ch" | jq -r '.headers // {} | to_entries | map("\(.key): \(.value)") | join("\r\n")')" \
          -i "$url" \
          -c copy \
          -f hls \
          -hls_time 4 \
          -hls_list_size 6 \
          -hls_flags delete_segments \
          "$out/index.m3u8" &

    fi

    sleep 5
done

sleep 60
done
