```markdown
# IPTV HLS Restreamer (with n_m3u8dl-re worker)

This repo runs per-channel workers to convert MPD (ClearKey) streams to HLS using either ffmpeg or n_m3u8dl-re (when configured).

Key points
- MPD (ClearKey) channels: start.sh launches a per-channel worker that runs `n_m3u8dl-re` (if available) to download/decrypt the stream using the KID:KEY from channels.json. If n_m3u8dl-re produces an MP4 the worker will repackage it to HLS with ffmpeg.
- m3u8 and ts channels: start.sh uses ffmpeg to restream them to HLS.
- Per-channel HTTP headers are supported via the `headers` object in channels.json.
- The image includes a static ffmpeg binary and attempts to download `n_m3u8dl-re` automatically (may fail if release assets change). If n_m3u8dl-re isn't available you can install it manually inside the container or adjust the worker.

Build
```
docker build -t iptv .
```

Run
```
docker run -d \
  --name iptv \
  --restart unless-stopped \
  -p 80:80 \
  -v $(pwd)/hls:/app/hls \
  iptv
```

If host port 80 is used, run on a different host port (example 8080):
```
docker run -d --name iptv --restart unless-stopped -p 8080:80 -v $(pwd)/hls:/app/hls iptv
```

Logs
```
docker logs -f iptv
docker logs --tail 200 iptv
```

Channels configuration
- Put your channels in /app/channels.json (example included).
- For MPD (ClearKey) channels include:
  `"key": "KID:KEY"`
- Optional per-channel headers:
  `"headers": { "User-Agent": "Mozilla/5.0", "Referer": "https://..." }`

Example MPD channel:
```json
{
  "name": "dangal-SD",
  "type": "mpd",
  "url": "https://example.com/index.mpd",
  "key": "KID:KEY",
  "headers": { "User-Agent": "Mozilla/5.0", "Referer": "https://example.com/" }
}
```


### ✅ FIX (2 commands only)

### 1️⃣ Remove old container (force)

```bash
podman rm -f iptv
```

You should see an ID printed — that means it’s deleted.

---

### 2️⃣ Run container again

```bash
podman run -d \
  --name iptv \
  --network host \
  --restart=always \
  -v /home/ubuntu/iptv-streams:/streams:Z \
  iptv
```

✅ This time it will start cleanly.

---

# ✅ Verify container is running

```bash
podman ps
```

You must see:

```
CONTAINER ID   IMAGE   STATUS      NAMES
xxxxxxx        iptv    Up ...       iptv
```

---

# ✅ Check logs (important)

```bash
podman logs -f iptv
```

You should see something like:

```
[+] IPTV system starting...
[+] Starting Dangal_SD
[+] Starting Sony_Max
[+] Starting Zee_Anmol
[+] Starting Dangal_HD
```

(no nginx bind errors)

---

# ✅ Test stream (after 30 seconds)

```bash
curl http://127.0.0.1:8080/Dangal_HD/index.m3u8
```

or browser:

```
http://YOUR_SERVER_IP:8080/Dangal_HD/index.m3u8
```

---

# 🔥 Important (Oracle / Podman rule)

Because you are using:

```
--network host
```

You must always use:

```
http://IP:8080/CHANNEL/index.m3u8
```

❌ not `/streams/`
❌ not `/playlist.m3u`
✅ direct folder name




Notes
- If your MPD host returns 4xx/403/450, add required headers or use a proxy/tunnel.
- If n_m3u8dl-re isn't installed automatically, install a compatible binary and place it in /usr/local/bin inside the container.
- Always ensure you are authorized to decrypt and restream protected content.
```
