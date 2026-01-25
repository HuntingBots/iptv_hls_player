#!/usr/bin/env bash
# /app/nm3u8dl_worker.sh
# Usage: nm3u8dl_worker.sh "<NAME>" "<URL>" "<KEY>" "<HEADERS_JSON>"
# Loops: runs n_m3u8dl-re to download/decrypt MPD then ensures an HLS index exists.

set -euo pipefail

NAME="$1"
URL="$2"
KEY="$3"
HEADERS_JSON="${4:-}"

HLS_DIR="/app/hls/$NAME"
LOGFILE="/var/log/iptv.log"

mkdir -p "$HLS_DIR"

# build repeated --add-header args for n_m3u8dl-re if headers provided
NM_HEADER_ARGS=()
if [ -n "$HEADERS_JSON" ] && [ "$HEADERS_JSON" != "null" ]; then
  mapfile -t _hdrs < <(echo "$HEADERS_JSON" | jq -r 'to_entries | map("\(.key): \(.value)") | .[]')
  for h in "${_hdrs[@]}"; do
    NM_HEADER_ARGS+=(--add-header "$h")
  done
fi

while true; do
  echo "[NM3U8DL] Worker starting for $NAME" | tee -a "$LOGFILE"
  RUN_DIR=$(mktemp -d "/tmp/nm3u8dl_${NAME}_XXXX")
  cd "$RUN_DIR" || exit 1

  # Run n_m3u8dl-re (pass key and headers); attempt to save outputs to HLS_DIR
  # Note: flags used here are common, but adjust if your binary uses different option names.
  if command -v n_m3u8dl-re >/dev/null 2>&1; then
    echo "[NM3U8DL] Running n_m3u8dl-re for $NAME" | tee -a "$LOGFILE"
    n_m3u8dl-re "$URL" --key "$KEY" --save-dir "$HLS_DIR" --save-name "$NAME" "${NM_HEADER_ARGS[@]}" >> "$LOGFILE" 2>&1 || {
      echo "[NM3U8DL] n_m3u8dl-re failed for $NAME (see logs)" | tee -a "$LOGFILE"
    }
  else
    echo "[NM3U8DL] n_m3u8dl-re not found in PATH; exiting worker for $NAME" | tee -a "$LOGFILE"
    rm -rf "$RUN_DIR"
    sleep 30
    continue
  fi

  # If n_m3u8dl-re produced an MP4, repackage it to HLS
  MP4=$(find "$HLS_DIR" -maxdepth 1 -type f -iname "*.mp4" -printf '%T@ %p\n' 2>/dev/null | sort -n -r | head -n1 | awk '{print $2}' || true)
  if [ -z "$MP4" ]; then
    MP4=$(ls -1t "$HLS_DIR"/*.mp4 2>/dev/null | head -n1 || true)
  fi

  if [ -n "$MP4" ] && [ -f "$MP4" ]; then
    echo "[NM3U8DL] Packaging MP4 to HLS for $NAME: $MP4" | tee -a "$LOGFILE"
    ffmpeg -y -nostats -loglevel warning -re -i "$MP4" -c copy -f hls -hls_time 4 -hls_list_size 6 -hls_flags delete_segments+append_list "$HLS_DIR/index.m3u8" >> "$LOGFILE" 2>&1 || {
      echo "[NM3U8DL] ffmpeg packaging failed for $NAME" | tee -a "$LOGFILE"
    }
  else
    # If index.m3u8 already exists, leave it; otherwise warn
    if [ -f "$HLS_DIR/index.m3u8" ]; then
      echo "[NM3U8DL] index.m3u8 exists for $NAME" | tee -a "$LOGFILE"
    else
      echo "[NM3U8DL] No MP4 or index.m3u8 produced for $NAME - check n_m3u8dl-re flags or server access" | tee -a "$LOGFILE"
    fi
  fi

  rm -rf "$RUN_DIR"
  sleep 5
done
