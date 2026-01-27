FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ffmpeg \
    nginx \
    curl \
    wget \
    jq \
    ca-certificates \
    tini \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Shaka Packager (ClearKey support)
RUN wget -O /usr/local/bin/shaka-packager \
    https://github.com/shaka-project/shaka-packager/releases/latest/download/packager-linux-x64 \
    && chmod +x /usr/local/bin/shaka-packager

WORKDIR /app
COPY . /app

RUN chmod +x *.sh && rm -f /etc/nginx/sites-enabled/default

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/app/start.sh"]
