#!/bin/bash

# Start script for IPTV restreamer
# - Passes optional per-channel HTTP headers into ffmpeg
# - Uses larger probe/analyze settings to avoid mis-probing and reduce ffmpeg crashes
# - Gracefully tracks ffmpeg background PIDs and kills them on exit

set -u

LOGFILE="/var/log/iptv.log"
HLS_DIR="/app/hls"
CHANNELS="/app/channels.json"
CLEAR_ON_START="${CLEAR_ON_START:-true}"

# input probe options to improve stream detection and avoid invalid frame/codec probing
INPUT_OPTS="-probesize 100M -analyzeduration 100M -fflags +genpts"

echo "[START] IPTV service" | tee -a "$LOGFILE"
mkdir -p "$HLS_DIR"
touch "$LOGFILE"

if [ ! -f "$CHANNELS" ]; then
  echo "[ERROR] channels.json not found at $CHANNELS" | tee -a "$LOGFILE"
  exit 1
fi

if [ "$CLEAR_ON_START" = "true" ] || [ "$CLEAR_ON_START" = "1" ]; then
  echo "[INFO] Clearing old segments on start" | tee -a "$LOGFILE"
  rm -rf "${HLS_DIR:?}/"*
else
  echo "[INFO] Keeping existing segments (CLEAR_ON_START=$CLEAR_ON_START)" | tee -a "$LOGFILE"
fi

# Ensure ffmpeg exists
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[ERROR] ffmpeg not found in PATH" | tee -a "$LOGFILE"
  exit 1
fi

# Check if ffmpeg supports -decryption_key for dash demuxer
if ffmpeg -h demuxer=dash 2>/dev/null | grep -q decryption_key; then
  DECRYPTION_SUPPORTED=true
else
  DECRYPTION_SUPPORTED=false
  echo "[WARN] ffmpeg dash demuxer does not advertise 'decryption_key' option. MPD ClearKey decryption may not work." | tee -a "$LOGFILE"
  echo "[WARN] Make sure the image is built with a static ffmpeg that includes dash decryption support." | tee -a "$LOGFILE"
fi

PIDS=()

terminate() {
  echo "[STOP] IPTV service shutting down" | tee -a "$LOGFILE"
  if [ ${#PIDS[@]} -gt 0 ]; then
    echo "[STOP] Stopping ffmpeg processes: ${PIDS[*]}" | tee -a "$LOGFILE"
    for pid in "${PIDS[@]}"; do
      if kill -0 "$pid" >/dev/null 2>&1; then
        kill "$pid" 2>/dev/null || true
      fi
    done
    sleep 1
    for pid in "${PIDS[@]}"; do
      if kill -0 "$pid" >/dev/null 2>&1; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    done
  fi
  exit 0
}
trap terminate SIGINT SIGTERM EXIT

while IFS= read -r ch; do
    NAME=$(echo "$ch" | jq -r '.name')
    TYPE=$(echo "$ch" | jq -r '.type' | tr '[:upper:]' '[:lower:]')
    URL=$(echo "$ch" | jq -r '.url')
    KEY=$(echo "$ch" | jq -r '.key // empty')
    HDR_JSON=$(echo "$ch" | jq -r '.headers // empty')

    if [ -z "$NAME" ] || [ -z "$TYPE" ] || [ -z "$URL" ]; then
      echo "[WARN] Skipping invalid channel entry: $ch" | tee -a "$LOGFILE"
      continue
    fi

    echo "[CHANNEL] $NAME ($TYPE)" | tee -a "$LOGFILE"
    mkdir -p "$HLS_DIR/$NAME"

    # build headers string for ffmpeg "-headers" option if provided
    FF_HEADERS=""
    if [ "$HDR_JSON" != "empty" ]; then
      FF_HEADERS=$(echo "$HDR_JSON" | jq -r 'to_entries | map("\(.key): \(.value)\\r\\n") | .[]' | tr -d '\n')
      echo "[INFO] Using custom headers for $NAME" | tee -a "$LOGFILE"
    fi

    case "$TYPE" in
      mpd)
        if [[ "$KEY" == *:* ]]; then
          if [ "$DECRYPTION_SUPPORTED" = "false" ]; then
            echo "[WARN] ffmpeg may not support -decryption_key; MPD decryption could fail for $NAME" | tee -a "$LOGFILE"
          fi
          echo "[MPD] ClearKey for $NAME" | tee -a "$LOGFILE"

          if [ -n "$FF_HEADERS" ]; then
            ffmpeg \
              -loglevel warning \
              -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
              -decryption_key "$KEY" \
              $INPUT_OPTS \
              -headers "$FF_HEADERS" \
              -i "$URL" \
              -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list \
              "$HLS_DIR/$NAME/index.m3u8" >> "$LOGFILE" 2>&1 &
          else
            ffmpeg \
              -loglevel warning \
              -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
              -decryption_key "$KEY" \
              $INPUT_OPTS \
              -i "$URL" \
              -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list \
              "$HLS_DIR/$NAME/index.m3u8" >> "$LOGFILE" 2>&1 &
          fi

          PIDS+=("$!")
        else
          echo "[ERROR] MPD key missing or invalid for $NAME" | tee -a "$LOGFILE"
        fi
        ;;
      m3u8)
        echo "[STREAM] M3U8 $NAME" | tee -a "$LOGFILE"
        if [ -n "$FF_HEADERS" ]; then
          ffmpeg \
            -loglevel warning \
            -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
            $INPUT_OPTS \
            -headers "$FF_HEADERS" \
            -i "$URL" \
            -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list \
            "$HLS_DIR/$NAME/index.m3u8" >> "$LOGFILE" 2>&1 &
        else
          ffmpeg \
            -loglevel warning \
            -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
            $INPUT_OPTS \
            -i "$URL" \
            -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list \
            "$HLS_DIR/$NAME/index.m3u8" >> "$LOGFILE" 2>&1 &
        fi
        PIDS+=("$!")
        ;;
      ts|mpegts)
        echo "[STREAM] TS $NAME" | tee -a "$LOGFILE"
        if [ -n "$FF_HEADERS" ]; then
          ffmpeg \
            -loglevel warning \
            -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
            $INPUT_OPTS \
            -headers "$FF_HEADERS" \
            -i "$URL" \
            -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list \
            "$HLS_DIR/$NAME/index.m3u8" >> "$LOGFILE" 2>&1 &
        else
          ffmpeg \
            -loglevel warning \
            -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
            $INPUT_OPTS \
            -i "$URL" \
            -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list \
            "$HLS_DIR/$NAME/index.m3u8" >> "$LOGFILE" 2>&1 &
        fi
        PIDS+=("$!")
        ;;
      *)
        echo "[WARN] Unknown channel type '$TYPE' for $NAME — skipping" | tee -a "$LOGFILE"
        ;;
    esac

done < <(jq -c '.channels[]' "$CHANNELS")

echo "[INFO] Spawned ${#PIDS[@]} ffmpeg workers" | tee -a "$LOGFILE"

tail -F "$LOGFILE" &

wait
