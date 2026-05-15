FROM python:3.12-slim@sha256:401f6e1a67dad31a1bd78e9ad22d0ee0a3b52154e6bd30e90be696bb6a3d7461

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
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /work --shell /usr/sbin/nologin openlola

WORKDIR /work
COPY . /work
RUN chown -R openlola:openlola /work
USER openlola

CMD ["python", "-m", "linux_connector.lola_connector.cli", "--local-ip", "127.0.0.1", "selftest"]
