# ================= PORTAL =================
PORTAL = "http://starshare.one/portal.php"


# ================= DEVICE =================
MAC = "00:1A:79:7B:4C:50"

SERIAL = "AB1E288F30A79"
DEVICE_ID = "E39225B45F48C9F87361EB470C19DEA746D124397243DBD0DDD79D1611D167D7"


# ================= HEADERS =================
HEADERS = {
    "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
    "Referer": "http://starshare.one/c/",
    "X-User-Agent": "Model: MAG270; Link: WiFi",
    "Accept": "*/*",
    "Connection": "Keep-Alive",
    "Cache-Control": "no-cache"
}


# ================= COOKIES =================
COOKIES = {
    "mac": MAC,
    "stb_lang": "en",
    "timezone": "Asia/Kolkata",
    "adid": "ebc7b048cb88af36f228619d0a511c14"
}


# ================= STB PARAMS =================
STB_PARAMS = {
    "sn": SERIAL,
    "device_id": DEVICE_ID,
    "device_id2": DEVICE_ID,
    "signature": DEVICE_ID   # 🔥 important fix (dummy हटाया)
}
