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

# -------------------------------
# Install N_m3u8DL-RE (PINNED)
# -------------------------------
RUN wget -O /tmp/nm.tar.gz \
    https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v1.7.1/N_m3u8DL-RE_Linux_x64.tar.gz \
 && tar -xzf /tmp/nm.tar.gz -C /tmp \
 && mv /tmp/N_m3u8DL-RE /usr/local/bin/N_m3u8DL-RE \
 && chmod +x /usr/local/bin/N_m3u8DL-RE \
 && rm -rf /tmp/nm.tar.gz /tmp/N_m3u8DL-RE

WORKDIR /app
COPY . /app

RUN chmod +x /app/*.sh

EXPOSE 80

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/app/start.sh"]
