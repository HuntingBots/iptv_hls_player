```markdown
# IPTV HLS Restreamer

This image restreams configured channel sources into HLS (m3u8) files served by nginx.

Highlights:
- MPD (ClearKey) → HLS conversion using ffmpeg dash demuxer with `-decryption_key` (requires ffmpeg build with dash decryption support).
- Direct HLS (m3u8) and TS/MPEG-TS inputs supported.
- Per-channel HTTP header support for sources that require custom headers.

Build:
docker build -t iptv .

Run:
docker run -d \
  --name iptv \
  --restart unless-stopped \
  -p 80:80 \
  -v $(pwd)/hls:/app/hls \
  iptv

Logs:
docker logs -f iptv
cat /var/log/iptv.log

Channels definition:
Edit /app/channels.json (the container ships a sample). If you already have ClearKey keys, put them in "key" as "KID:KEY".

Example channels.json entry:
{
  "name": "dangal-SD",
  "type": "mpd",
  "url": "https://.../index.mpd",
  "key": "KID:KEY",
  "headers": {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
    "Referer": "https://example.com/"
  }
}

Notes:
- Because you already have KID:KEY in channels.json, you do NOT need the pywidevine or decrypt helper scripts.
- The Dockerfile includes a static ffmpeg build with dash demuxer that supports `-decryption_key`. If you build and still see decryption errors, verify ffmpeg supports `decryption_key`:
  docker exec -it iptv ffmpeg -h demuxer=dash | grep decryption_key
- If MPD URLs return 4xx/403/450 errors, add appropriate headers to the channel's "headers" object or use a proxy/tunnel.
```
