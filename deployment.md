Below is a **complete `deployment.md`** you can directly put in your repo.
This is written like a **real production deployment guide**, step-by-step, no confusion.

You can copy–paste exactly as it is.

---

# 📘 deployment.md

## IPTV HLS Rebroadcast Server – Deployment Guide

This guide explains how to deploy the IPTV rebroadcast system that converts:

* MPD ClearKey → HLS (m3u8)
* m3u8 → HLS
* TS → HLS

into **your own 24/7 IPTV stream links**.

---

## ✅ Requirements

### VPS

* Ubuntu 20.04 / 22.04
* Minimum 2 GB RAM
* 2 vCPU recommended
* Public IP or Cloudflare Tunnel

### Supported runtimes

* Docker
* Podman (recommended for Oracle / NAT VPS)

---

## 📁 Project Structure

```
iptv-hls-m3u8/
├── Dockerfile
├── start.sh
├── worker.sh
├── generate_m3u.sh
├── nginx.conf
├── channels.json
└── streams/
```

---

## 🔧 Step 1 – Install Podman (recommended)

### Ubuntu 20.04 / 22.04

```bash
sudo apt update
sudo apt install -y podman
```

Check:

```bash
podman --version
```

---

## 🧱 Step 2 – Build image

Go to project directory:

```bash
cd iptv-hls-m3u8
```

Build:

```bash
podman build -t iptv .
```

You should see:

```
Successfully tagged localhost/iptv:latest
```

---

## 🚀 Step 3 – Run container

Use **host network** (important for IPTV):

```bash
sudo podman run -d \
  --name iptv \
  --network host \
  --restart=always \
  iptv
```

Check status:

```bash
podman ps
```

---

## 🌐 Step 4 – Open ports

Make sure port **80** is open.

### Check listening

```bash
ss -tulnp | grep :80
```

You should see nginx listening.

---

## 📡 Step 5 – Access streams

### Single channel

```
http://YOUR-IP/CHANNEL_NAME/index.m3u8
```

Example:

```
http://92.4.78.203/Dangal_HD/index.m3u8
```

---

### Playlist

```
http://YOUR-IP/playlist.m3u
```

Example:

```
http://92.4.78.203/playlist.m3u
```

---

## 🎬 Supported players

Works perfectly with:

* VLC
* Tivimate
* IPTV Smarters
* OTT Navigator
* Kodi

---

## 🔁 24/7 Auto Running

This system automatically:

* restarts dead streams
* keeps playlist updated
* runs permanently
* survives VPS reboot

Because:

```bash
--restart=always
```

is enabled.

---

## 🔐 MPD ClearKey Notes

For MPD streams:

```json
"type": "mpd-clearkey",
"key": "KID:KEY"
```

Only ClearKey DRM is supported.

❌ Widevine not supported
❌ PlayReady not supported

---

## ⚠️ Channel naming rules

Use only:

```
A–Z
a–z
0–9
_
```

❌ spaces
❌ symbols
❌ emojis

Correct:

```
Sony_Max
Dangal_HD
Zee_Anmol
```

---

## ☁️ Cloudflare Tunnel (optional)

If your VPS has NAT or blocked ports:

```bash
cloudflared tunnel --url http://localhost:80
```

Then use tunnel URL in playlist:

```
https://xxxx.trycloudflare.com
```

Edit in `generate_m3u.sh`:

```bash
BASE_URL="https://xxxx.trycloudflare.com"
```

Rebuild container after change.

---

## 🔄 Updating channels

Edit:

```bash
channels.json
```

Then rebuild:

```bash
podman stop iptv
podman rm iptv
podman build -t iptv .
podman run -d --name iptv --network host --restart=always iptv
```

Playlist updates automatically.

---

## 🧪 Debugging

### Check logs

```bash
podman logs -f iptv
```

### Enter container

```bash
podman exec -it iptv bash
```

### Check streams

```bash
ls /app/streams
```

---

## 📊 Performance Tips

* Use `-c copy` only (already configured)
* Avoid transcoding
* Each channel ≈ 1 connection
* 2GB RAM supports ~10 channels safely

---

## 🔥 Summary

You now have:

✅ IPTV rebroadcast server
✅ ClearKey MPD support
✅ auto playlist generation
✅ 24/7 stable operation
✅ Docker / Podman compatible
✅ works on Oracle & NAT VPS

---

## ⚠️ Legal Notice

This project is for **educational and personal use only**.
You are responsible for how you use it.

---

## 🧠 Next upgrades (optional)

* EPG XMLTV
* tvg-logo support
* Group categories
* Web dashboard
* Telegram control bot
* Stream health alerts

---

✅ Deployment complete
Enjoy your IPTV system 🚀
