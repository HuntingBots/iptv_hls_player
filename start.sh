#!/bin/bash

echo "[START] IPTV service"
mkdir -p /app/hls
touch /var/log/iptv.log

# Clear old segments on restart
rm -rf /app/hls/*

jq -c '.channels[]' /app/channels.json | while read ch; do

    NAME=$(echo "$ch" | jq -r '.name')
    TYPE=$(echo "$ch" | jq -r '.type')
    URL=$(echo "$ch" | jq -r '.url')
    KEY=$(echo "$ch" | jq -r '.key // empty')

    echo "[CHANNEL] $NAME ($TYPE)" | tee -a /var/log/iptv.log

    mkdir -p "/app/hls/$NAME"

    # =========================
    # MPD (ClearKey)
    # =========================
    if [ "$TYPE" = "mpd" ]; then

        if [[ "$KEY" == *":"* ]]; then
            echo "[MPD] ClearKey for $NAME" | tee -a /var/log/iptv.log

            ffmpeg \
            -loglevel warning \
            -reconnect 1 \
            -reconnect_streamed 1 \
            -reconnect_delay_max 5 \
            -decryption_key "$KEY" \
            -i "$URL" \
            -c copy \
            -f hls \
            -hls_time 4 \
            -hls_list_size 10 \
            -hls_flags delete_segments+append_list \
            "/app/hls/$NAME/index.m3u8" \
            >> /var/log/iptv.log 2>&1 &

        else
            echo "[ERROR] MPD key missing or invalid for $NAME" | tee -a /var/log/iptv.log
        fi
    fi

    # =========================
    # M3U8
    # =========================
    if [ "$TYPE" = "m3u8" ]; then
        echo "[STREAM] M3U8 $NAME" | tee -a /var/log/iptv.log

        ffmpeg \
        -loglevel warning \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 5 \
        -i "$URL" \
        -c copy \
        -f hls \
        -hls_time 4 \
        -hls_list_size 10 \
        -hls_flags delete_segments+append_list \
        "/app/hls/$NAME/index.m3u8" \
        >> /var/log/iptv.log 2>&1 &
    fi

    # =========================
    # TS / MPEGTS
    # =========================
    if [ "$TYPE" = "ts" ]; then
        echo "[STREAM] TS $NAME" | tee -a /var/log/iptv.log

        ffmpeg \
        -loglevel warning \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 5 \
        -i "$URL" \
        -c copy \
        -f hls \
        -hls_time 4 \
        -hls_list_size 10 \
        -hls_flags delete_segments+append_list \
        "/app/hls/$NAME/index.m3u8" \
        >> /var/log/iptv.log 2>&1 &
    fi

done

# keep container alive forever
tail -f /var/log/iptv.log
