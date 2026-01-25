#!/bin/bash

# Start script for IPTV restreamer
# - Uses n_m3u8dl_worker.sh for MPD (ClearKey) channels (if available)
# - Uses ffmpeg for m3u8/ts channels
# - Supports per-channel headers and graceful shutdown

set -u

LOGFILE="/var/log/iptv.log"
HLS_DIR="/app/hls"
CHANNELS="/app/channels.json"
CLEAR_ON_START="${CLEAR_ON_START:-true}"

# input probe options to improve stream detection and avoid mis-probing
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

PIDS=()

terminate() {
  echo "[STOP] IPTV service shutting down" | tee -a "$LOGFILE"
  if [ ${#PIDS[@]} -gt 0 ]; then
    echo "[STOP] Stopping workers: ${PIDS[*]}" | tee -a "$LOGFILE"
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

    # build headers string presence check
    FF_HEADERS=""
    if [ "$HDR_JSON" != "empty" ]; then
      FF_HEADERS="$HDR_JSON"
      echo "[INFO] Using custom headers for $NAME" | tee -a "$LOGFILE"
    fi

    case "$TYPE" in
      mpd)
        if [[ "$KEY" == *:* ]]; then
          # Use nm3u8dl worker if available; else fallback to ffmpeg -decryption_key
          if command -v n_m3u8dl-re >/dev/null 2>&1 && [ -x /app/nm3u8dl_worker.sh ]; then
            echo "[MPD] Starting n_m3u8dl-re worker for $NAME" | tee -a "$LOGFILE"
            /app/nm3u8dl_worker.sh "$NAME" "$URL" "$KEY" "$FF_HEADERS" >> "$LOGFILE" 2>&1 &
            PIDS+=("$!")
          else
            echo "[MPD] n_m3u8dl-re not found — falling back to ffmpeg (requires dash decryption support)" | tee -a "$LOGFILE"
            # Place headers before -i if provided
            if [ "$FF_HEADERS" != "" ]; then
              # convert JSON headers to ffmpeg -headers string
              HDR_STR=$(echo "$FF_HEADERS" | jq -r 'to_entries | map("\(.key): \(.value)\\r\\n") | .[]' | tr -d '\n')
              ffmpeg -loglevel warning -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 -decryption_key "$KEY" $INPUT_OPTS -headers "$HDR_STR" -i "$URL" -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 &
            else
              ffmpeg -loglevel warning -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 -decryption_key "$KEY" $INPUT_OPTS -i "$URL" -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 &
            fi
            PIDS+=("$!")
          fi
        else
          echo "[ERROR] MPD key missing or invalid for $NAME" | tee -a "$LOGFILE"
        fi
        ;;
      m3u8)
        echo "[STREAM] M3U8 $NAME" | tee -a "$LOGFILE"
        if [ "$FF_HEADERS" != "" ]; then
          HDR_STR=$(echo "$FF_HEADERS" | jq -r 'to_entries | map("\(.key): \(.value)\\r\\n") | .[]' | tr -d '\n')
          ffmpeg -loglevel warning -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 $INPUT_OPTS -headers "$HDR_STR" -i "$URL" -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 &
        else
          ffmpeg -loglevel warning -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 $INPUT_OPTS -i "$URL" -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 &
        fi
        PIDS+=("$!")
        ;;
      ts|mpegts)
        echo "[STREAM] TS $NAME" | tee -a "$LOGFILE"
        if [ "$FF_HEADERS" != "" ]; then
          HDR_STR=$(echo "$FF_HEADERS" | jq -r 'to_entries | map("\(.key): \(.value)\\r\\n") | .[]' | tr -d '\n')
          ffmpeg -loglevel warning -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 $INPUT_OPTS -headers "$HDR_STR" -i "$URL" -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 &
        else
          ffmpeg -loglevel warning -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 $INPUT_OPTS -i "$URL" -c copy -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 &
        fi
        PIDS+=("$!")
        ;;
      *)
        echo "[WARN] Unknown channel type '$TYPE' for $NAME — skipping" | tee -a "$LOGFILE"
        ;;
    esac

done < <(jq -c '.channels[]' "$CHANNELS")

echo "[INFO] Spawned ${#PIDS[@]} workers" | tee -a "$LOGFILE"

tail -F "$LOGFILE" &

wait
