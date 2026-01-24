#!/bin/bash

PLAYLIST="/app/playlist.m3u"

BASE_URL="https://cloudflare-managed-url"

echo "#EXTM3U" > $PLAYLIST

jq -c '.[]' /app/channels.json | while read ch; do
  NAME=$(echo "$ch" | jq -r '.name')

  echo "#EXTINF:-1 tvg-id=\"$NAME\" tvg-name=\"$NAME\" group-title=\"Live\",$NAME" >> $PLAYLIST
  echo "$BASE_URL/hls/$NAME/stream.m3u8" >> $PLAYLIST
done
