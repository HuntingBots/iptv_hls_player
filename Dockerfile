FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y ffmpeg nginx curl wget jq ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# install cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

WORKDIR /app

COPY start.sh /start.sh
COPY generate_m3u.sh /app/generate_m3u.sh
COPY channels.json /app/channels.json
COPY nginx.conf /etc/nginx/nginx.conf
COPY cloudflared /etc/cloudflared

RUN chmod +x /start.sh /app/generate_m3u.sh

CMD ["/start.sh"]
