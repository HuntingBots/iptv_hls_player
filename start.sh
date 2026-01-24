#!/bin/bash
set -e

LOG_FILE="/var/log/iptv.log"
mkdir -p /app/hls
mkdir -p /var/log
touch $LOG_FILE

echo "[START] IPTV service" | tee -a $LOG_FILE

jq -c '.channels[]' /app/channels.json | while read channel; do

    NAME=$(echo "$channel" | jq -r '.name')
    TYPE=$(echo "$channel" | jq -r '.type')
    URL=$(echo "$channel" | jq -r '.url')
    KEY=$(echo "$channel" | jq -r '.key // empty')

    OUT="/app/hls/$NAME"
    mkdir -p "$OUT"

    echo "[CHANNEL] $NAME ($TYPE)" | tee -a $LOG_FILE

    if [[ "$TYPE" == "mpd" ]]; then

        if [[ "$KEY" == *":"* ]]; then
            echo "[MPD] ClearKey full for $NAME" | tee -a $LOG_FILE

            ffmpeg \
            -reconnect 1 \
            -reconnect_streamed 1 \
            -reconnect_delay_max 5 \
            -cenc_decryption_key "$KEY" \
            -i "$URL" \
            -map 0 \
            -c copy \
            -f hls \
            -hls_time 4 \
            -hls_list_size 6 \
            -hls_flags delete_segments+append_list \
            "$OUT/index.m3u8" \
            >> $LOG_FILE 2>&1 &

        else
            echo "[MPD] Single key mode for $NAME" | tee -a $LOG_FILE

            ffmpeg \
            -reconnect 1 \
            -reconnect_streamed 1 \
            -reconnect_delay_max 5 \
            -cenc_decryption_key "$KEY" \
            -i "$URL" \
            -map 0 \
            -c copy \
            -f hls \
            -hls_time 4 \
            -hls_list_size 6 \
            -hls_flags delete_segments+append_list \
            "$OUT/index.m3u8" \
            >> $LOG_FILE 2>&1 &
        fi

    else
        echo "[STREAM] $NAME" | tee -a $LOG_FILE

        ffmpeg \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 5 \
        -i "$URL" \
        -map 0 \
        -c copy \
        -f hls \
        -hls_time 4 \
        -hls_list_size 6 \
        -hls_flags delete_segments+append_list \
        "$OUT/index.m3u8" \
        >> $LOG_FILE 2>&1 &
    fi

done

tail -f /dev/null
