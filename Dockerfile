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
    && rm -rf /var/lib/apt/lists/*

# N_m3u8DL-RE (stable binary)
RUN wget -O /usr/local/bin/N_m3u8DL-RE \
    https://github.com/nilaoda/N_m3u8DL-RE/releases/latest/download/N_m3u8DL-RE_Linux_x64 \
 && chmod +x /usr/local/bin/N_m3u8DL-RE

WORKDIR /app
COPY . /app

RUN chmod +x /app/*.sh

EXPOSE 80

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/app/start.sh"]
