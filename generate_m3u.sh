#!/bin/bash

OUT="/app/output/playlist.m3u"

echo "#EXTM3U" > "$OUT"

for d in /app/streams/*; do
    if [ -f "$d/index.m3u8" ]; then
        name=$(basename "$d" | tr '_' ' ')
        echo "#EXTINF:-1,$name" >> "$OUT"
        echo "http://localhost/streams/$(basename "$d")/index.m3u8" >> "$OUT"
    fi
done
