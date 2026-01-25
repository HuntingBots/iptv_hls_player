FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    nginx \
    jq \
    curl \
    wget \
    ca-certificates \
    unzip \
    xz-utils \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install a recent static ffmpeg build (includes dash decryption support)
RUN set -eux; \
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"; \
    wget -qO /tmp/ffmpeg.tar.xz "$FFMPEG_URL"; \
    mkdir -p /tmp/ffmpeg-tmp; \
    tar -xJf /tmp/ffmpeg.tar.xz -C /tmp/ffmpeg-tmp --strip-components=1; \
    mv /tmp/ffmpeg-tmp/ffmpeg /usr/local/bin/ffmpeg; \
    mv /tmp/ffmpeg-tmp/ffprobe /usr/local/bin/ffprobe; \
    chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe; \
    rm -rf /tmp/ffmpeg* /tmp/ffmpeg-tmp

# Try to install n_m3u8dl-re (optional). If release asset layout changes this may fail quietly.
RUN set -eux; \
    NM_URL="https://github.com/nilaoda/n_m3u8dl-re/releases/latest/download/n_m3u8dl-re_linux_amd64.tar.gz"; \
    wget -qO /tmp/nm.tar.gz "$NM_URL" || true; \
    if [ -f /tmp/nm.tar.gz ]; then \
      mkdir -p /tmp/nm && tar -xzf /tmp/nm.tar.gz -C /tmp/nm || true; \
      if [ -f /tmp/nm/n_m3u8dl-re ] ; then mv /tmp/nm/n_m3u8dl-re /usr/local/bin/n_m3u8dl-re; fi; \
      if [ -f /tmp/nm/n_m3u8dl ]; then mv /tmp/nm/n_m3u8dl /usr/local/bin/n_m3u8dl; fi; \
      chmod +x /usr/local/bin/n_m3u8dl-re /usr/local/bin/n_m3u8dl || true; \
    fi; \
    rm -rf /tmp/nm* || true

# Cloudflared (optional)
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared-linux-amd64.deb \
    && rm cloudflared-linux-amd64.deb || true

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
COPY nm3u8dl_worker.sh /app/nm3u8dl_worker.sh
COPY generate_m3u.sh /app/generate_m3u.sh
COPY channels.json /app/channels.json

RUN chmod +x /start.sh /app/nm3u8dl_worker.sh /app/generate_m3u.sh

EXPOSE 80

CMD nginx && /start.sh
