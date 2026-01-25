FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    ffmpeg \
    nginx \
    wget \
    curl \
    jq \
    ca-certificates \
    procps \
    tini \
    xz-utils \
    tar \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Install N_m3u8DL-RE (specific version)
# -----------------------------
RUN wget -O /tmp/nm.tar.gz \
    https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3u8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz \
 && mkdir -p /tmp/nm \
 && tar -xzf /tmp/nm.tar.gz -C /tmp/nm \
 && mv /tmp/nm/N_m3u8DL-RE /usr/local/bin/N_m3u8DL-RE \
 && chmod +x /usr/local/bin/N_m3u8DL-RE \
 && rm -rf /tmp/nm /tmp/nm.tar.gz

WORKDIR /app
COPY . /app

RUN chmod +x /app/*.sh

EXPOSE 80

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/app/start.sh"]
