# IPTV HLS Restreamer

## Build
docker build -t iptv .

## Run
docker run -d \
--name iptv \
--restart unless-stopped \
-p 80:80 \
-v $(pwd)/hls:/app/hls \
iptv

## Channel URLs
http://SERVER_IP/hls/dangal-SD/index.m3u8
http://SERVER_IP/hls/SonyMax/index.m3u8
http://SERVER_IP/hls/zee-anmol/index.m3u8
http://SERVER_IP/hls/Dangal-HD/index.m3u8

## Cloudflare
https://YOUR_TUNNEL.trycloudflare.com/hls/dangal-SD/index.m3u8

## Logs
docker logs -f iptv
cat /var/log/iptv.log
