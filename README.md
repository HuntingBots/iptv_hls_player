# Multi Channel IPTV Restream (iptv-hls-m3u8)

## Features
- MPD + ClearKey
- M3U8
- MPEGTS
- Multi channel
- Auto restart
- Cloudflare HTTPS
- No domain needed
- 24/7 Docker

---

## Build

docker build -t iptv .

---

## Run

docker run -d \
  --name iptv \
  --restart unless-stopped \
  -v $(pwd)/hls:/app/hls \
  iptv

---

## View logs

docker logs -f iptv

You will see:

https://xxxx.trycloudflare.com

---

## Stream URLs

https://xxxx.trycloudflare.com/hls/dangal/index.m3u8  
https://xxxx.trycloudflare.com/hls/news/index.m3u8  
https://xxxx.trycloudflare.com/hls/sports/index.m3u8
