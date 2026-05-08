FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ffmpeg \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        tcpdump \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . /work

CMD ["python", "-m", "linux_connector.lola_connector.cli", "--local-ip", "127.0.0.1", "selftest"]
