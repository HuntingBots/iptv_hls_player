FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    ffmpeg \
    nginx \
    curl \
    jq \
    wget \
    ca-certificates

# Install Cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
 && dpkg -i cloudflared-linux-amd64.deb

WORKDIR /app

COPY channels.json /app/channels.json
COPY start.sh /start.sh
COPY nginx.conf /etc/nginx/nginx.conf

RUN chmod +x /start.sh

CMD ["/start.sh"]
