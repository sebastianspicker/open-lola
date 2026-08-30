# Build the WSL/Linux connector environment used for local UDP self-tests.
FROM python:3.14.6-slim@sha256:b877e50bd90de10af8d82c57a022fc2e0dc731c5320d762a27986facfc3355c1

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# hadolint ignore=DL3008
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

HEALTHCHECK CMD python -m linux_connector.lola_connector.cli --help >/dev/null || exit 1
CMD ["python", "-m", "linux_connector.lola_connector.cli", "--local-ip", "127.0.0.1", "selftest"]
