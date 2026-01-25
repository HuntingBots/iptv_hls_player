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

    mkdir -p "$out"

    # headers
    header_args=()
    echo "$ch" | jq -r '.headers // {} | to_entries[]? | "\(.key): \(.value)"' |
    while read -r h; do
        header_args+=("-H" "$h")
    done

    echo "[+] Channel: $name ($type)"

    # ---------------- MPD ----------------
    if [[ "$type" == "mpd" ]]; then

        cmd=(
          N_m3u8DL-RE "$url"
          --save-dir "$out"
          --save-name index
          --live-real-time-merge
          --live-pipe-mux
          --log-level INFO
        )

        [[ -n "$key" ]] && cmd+=(--key "$key")

        for h in "${header_args[@]}"; do
            cmd+=("$h")
        done

        timeout 3600 "${cmd[@]}" &

    # ---------------- M3U8 ----------------
    elif [[ "$type" == "m3u8" ]]; then

        cmd=(
          N_m3u8DL-RE "$url"
          --save-dir "$out"
          --save-name index
          --live-real-time-merge
          --live-pipe-mux
          --log-level INFO
        )

        for h in "${header_args[@]}"; do
            cmd+=("$h")
        done

        timeout 3600 "${cmd[@]}" &

    # ---------------- TS ----------------
    elif [[ "$type" == "ts" ]]; then

        ffmpeg \
          -loglevel info \
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
