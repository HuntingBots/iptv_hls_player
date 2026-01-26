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

# n_m3u8DL-RE (working version)
RUN wget -O /tmp/nm.tar.gz \
    https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3u8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz \
    && tar -xzf /tmp/nm.tar.gz -C /tmp \
    && mv /tmp/N_m3u8DL-RE /usr/local/bin/n_m3u8dl-re \
    && chmod +x /usr/local/bin/n_m3u8dl-re \
    && rm -rf /tmp/*

WORKDIR /app

COPY . /app

RUN chmod +x /app/*.sh \
    && rm -f /etc/nginx/sites-enabled/default

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/app/start.sh"]
