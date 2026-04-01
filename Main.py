import os
import sys
import time

# ================= AUTO INSTALL =================
def auto_install():
    print("🔄 Checking dependencies...")

    try:
        import flask
        import requests
    except ImportError:
        print("📦 Installing Python modules...")
        os.system("pip install flask requests")

    # ffmpeg check
    if os.system("which ffmpeg > /dev/null 2>&1") != 0:
        print("📦 Installing ffmpeg...")
        os.system("pkg install ffmpeg -y")

    # storage permission
    if not os.path.exists("/storage/emulated/0"):
        print("📂 Setting up storage...")
        os.system("termux-setup-storage")

auto_install()

# ================= IMPORTS =================
import requests
import re
import datetime
import threading
import subprocess
from flask import Flask, Response

# ================= CONFIG =================
PORTAL = "http://datahub11.com/portal.php"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp",
    "Referer": "http://datahub11.com/c/",
    "Accept": "*/*",
    "Connection": "keep-alive"
}

COOKIES = {
    "mac": "00:1A:79:7B:4C:50",
    "stb_lang": "en",
    "timezone": "Asia/Kolkata"
}

STB_PARAMS = {
    "sn": "1234567890",
    "device_id": "ABCDEF123456",
    "device_id2": "ABCDEF123456",
    "signature": "ABCDEF123456"
}

# ================= APP =================
app = Flask(__name__)
session = requests.Session()

BASE = "/storage/emulated/0/iptv"
os.makedirs(BASE, exist_ok=True)

CHANNELS = [
    ("Dangal 2", "355278"),
    ("Dangal", "53107"),
    ("Sony TV 4K", "98854"),
    ("Sab TV 4K", "98853"),
    ("SET HD", "9365"),
    ("Star Bharat 4K", "199"),
]

# SONY_ID = "98854"

TOKEN = None
TOKEN_TIME = 0


# ================= TOKEN =================
def get_token(force=False):
    global TOKEN, TOKEN_TIME

    if TOKEN and not force and (time.time() - TOKEN_TIME < 50):
        return TOKEN

    try:
        params = {
            "type": "stb",
            "action": "handshake",
            "token": "",
            "JsHttpRequest": "1-xml",
            **STB_PARAMS
        }

        r = session.get(PORTAL, headers=HEADERS, cookies=COOKIES, params=params, timeout=10)
        data = r.json()

        TOKEN = data.get("js", {}).get("token")
        TOKEN_TIME = time.time()

        print("✅ NEW TOKEN")

        return TOKEN

    except Exception as e:
        print("❌ TOKEN ERROR:", e)
        return None


# ================= AUTO TOKEN =================
def token_refresher():
    while True:
        try:
            print("🔄 Refreshing token...")
            get_token(force=True)
        except:
            pass
        time.sleep(60)


# ================= PREP =================
def prepare(token):
    try:
        headers = HEADERS.copy()
        headers["Authorization"] = f"Bearer {token}"

        session.get(PORTAL, headers=headers, cookies=COOKIES, params={
            "type": "stb",
            "action": "get_profile",
            "JsHttpRequest": "1-xml",
            **STB_PARAMS
        }, timeout=10)
    except:
        pass


# ================= STREAM =================
def get_stream(ch_id):
    try:
        token = get_token()

        if not token:
            return None

        prepare(token)

        headers = HEADERS.copy()
        headers["Authorization"] = f"Bearer {token}"

        r = session.get(PORTAL, headers=headers, cookies=COOKIES, params={
            "type": "itv",
            "action": "create_link",
            "cmd": f"ffmpeg http://localhost/ch/{ch_id}_",
            "JsHttpRequest": "1-xml"
        }, timeout=10)

        cmd = r.json().get("js", {}).get("cmd")

        if not cmd:
            return None

        return re.search(r"(http.*)", cmd).group(1)

    except:
        return None


# ================= LIVE =================
@app.route("/live/<ch_id>.ts")
def live(ch_id):

    def generate():
        while True:
            stream = get_stream(ch_id)

            if not stream:
                time.sleep(2)
                continue

            try:
                cmd = [
                    "ffmpeg",
                    "-loglevel", "error",
                    "-reconnect", "1",
                    "-reconnect_streamed", "1",
                    "-reconnect_delay_max", "2",
                    "-i", stream,
                    "-c", "copy",
                    "-f", "mpegts",
                    "-"
                ]

                p = subprocess.Popen(cmd, stdout=subprocess.PIPE)

                while True:
                    chunk = p.stdout.read(1024 * 512)
                    if not chunk:
                        break

                    yield chunk

                    if time.time() - TOKEN_TIME > 50:
                        get_token(force=True)
                        break

            except:
                time.sleep(1)

    return Response(generate(), content_type="video/mp2t")


# ================= RECORD =================
def record():
    while True:
        now = datetime.datetime.now()
        date = now.strftime("%Y-%m-%d")
        path = f"{BASE}/{date}"

        os.makedirs(path, exist_ok=True)

        stream = get_stream(SONY_ID)

        if not stream:
            time.sleep(5)
            continue

        print("🎥 Recording started")

        subprocess.run([
            "ffmpeg",
            "-loglevel", "error",
            "-reconnect", "1",
            "-reconnect_streamed", "1",
            "-reconnect_delay_max", "2",
            "-i", stream,
            "-c", "copy",
            "-f", "hls",
            "-hls_time", "4",
            "-hls_list_size", "0",
            f"{path}/index.m3u8"
        ])

        time.sleep(2)


# ================= PLAYLIST =================
@app.route("/playlist.m3u")
def playlist():
    host = "http://127.0.0.1:8080"

    m3u = "#EXTM3U\n"

    for name, ch_id in CHANNELS:
        m3u += f'#EXTINF:-1,{name}\n'
        m3u += f'{host}/live/{ch_id}.ts\n'

    return Response(m3u, mimetype="application/x-mpegURL")


@app.route("/")
def home():
    return "🔥 TERMUX IPTV AUTO SYSTEM RUNNING"


# ================= START =================
threading.Thread(target=token_refresher, daemon=True).start()
threading.Thread(target=record, daemon=True).start()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, threaded=True)
