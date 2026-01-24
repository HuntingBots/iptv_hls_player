FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    ffmpeg \
    nginx \
    jq \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared-linux-amd64.deb \
    && rm cloudflared-linux-amd64.deb

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
COPY channels.json /app/channels.json

RUN chmod +x /start.sh

EXPOSE 80

CMD nginx && /start.sh
