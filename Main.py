import os
import time
import requests
import re
import threading
import subprocess
from flask import Flask, Response

# ================= AUTO INSTALL =================
def auto_install():
    try:
        import flask, requests
    except:
        os.system("pip install flask requests")

    if os.system("which ffmpeg > /dev/null 2>&1") != 0:
        os.system("pkg install ffmpeg -y")

auto_install()

# ================= CONFIG =================
PORTAL = "http://datahub11.com/portal.php"
BASE = PORTAL.replace("/portal.php", "")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp",
    "Referer": f"{BASE}/c/",
    "X-User-Agent": "Model: MAG270; Link: WiFi",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "Keep-Alive",
    "Cache-Control": "no-cache"
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
session.headers.update(HEADERS)
session.cookies.update(COOKIES)

CHANNELS = [
    ("Dangal 2", "355278"),
    ("Dangal", "53107"),
    ("Sony TV 4K", "98854"),
    ("Sab TV 4K", "98853"),
    ("SET HD", "9365"),
    ("Star Bharat 4K", "199"),
]

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

        r = session.get(PORTAL, params=params, timeout=10)
        TOKEN = r.json().get("js", {}).get("token")
        TOKEN_TIME = time.time()

        print("✅ TOKEN UPDATED")
        return TOKEN

    except Exception as e:
        print("❌ TOKEN ERROR:", e)
        return None

# ================= PROFILE =================
def prepare(token):
    try:
        headers = session.headers.copy()
        headers["Authorization"] = f"Bearer {token}"

        session.get(PORTAL, headers=headers, params={
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

        headers = session.headers.copy()
        headers["Authorization"] = f"Bearer {token}"

        r = session.get(PORTAL, headers=headers, params={
            "type": "itv",
            "action": "create_link",
            "cmd": f"ffmpeg http://localhost/ch/{ch_id}_",
            "JsHttpRequest": "1-xml"
        }, timeout=10)

        cmd = r.json().get("js", {}).get("cmd")
        if not cmd:
            print("❌ No stream cmd")
            return None

        url = re.search(r"(http.*)", cmd).group(1)

        # localhost fix
        url = url.replace("http://localhost", BASE)

        return url

    except Exception as e:
        print("❌ STREAM ERROR:", e)
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
                headers = session.headers.copy()

                with requests.get(
                    stream,
                    headers=headers,
                    cookies=COOKIES,
                    stream=True,
                    timeout=10
                ) as r:

                    if r.status_code != 200:
                        print("❌ BLOCK:", r.status_code)
                        time.sleep(2)
                        continue

                    for chunk in r.iter_content(1024 * 512):
                        if chunk:
                            yield chunk

                    time.sleep(1)

            except Exception as e:
                print("❌ Stream error:", e)
                time.sleep(2)

    return Response(generate(), content_type="video/mp2t")

# ================= PLAYLIST =================
@app.route("/playlist.m3u")
def playlist():
    host = "http://127.0.0.1:8090"

    m3u = "#EXTM3U\n"

    for name, ch_id in CHANNELS:
        m3u += f'#EXTINF:-1 group-title="LIVE",{name}\n'
        m3u += f'{host}/live/{ch_id}.ts\n'

    return Response(m3u, mimetype="application/x-mpegURL")

@app.route("/")
def home():
    return "🔥 IPTV SERVER RUNNING"

# ================= AUTO TOKEN =================
def token_refresher():
    while True:
        get_token(force=True)
        time.sleep(60)

threading.Thread(target=token_refresher, daemon=True).start()

# ================= START =================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8090, threaded=True)
