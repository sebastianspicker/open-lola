# Build a pinned UltraGrid `uv` image for repeatable Open LoLa transport checks.
FROM debian:bookworm-slim@sha256:67b30a61dc87758f0caf819646104f29ecbda97d920aaf5edc834128ac8493d3 AS build

ARG ULTRAGRID_VERSION=1.10.4
ARG ULTRAGRID_SOURCE_URL=https://github.com/CESNET/UltraGrid/archive/v${ULTRAGRID_VERSION}.tar.gz
ARG ULTRAGRID_SOURCE_SHA256=fb58372879b49e9e996835f0b335873406cfe60bf34cd501afb40665f22c6ef0

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        curl \
        libtool \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "$ULTRAGRID_SOURCE_URL" -o /tmp/ultragrid.tar.gz \
    && echo "$ULTRAGRID_SOURCE_SHA256  /tmp/ultragrid.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/ultragrid.tar.gz -C /tmp

WORKDIR /tmp/UltraGrid-${ULTRAGRID_VERSION}
RUN ./autogen.sh --enable-all=no --disable-dependency-tracking --prefix=/opt/ultragrid \
    && make -j"$(nproc)" bin/uv \
    && install -Dm755 bin/uv /opt/ultragrid/bin/uv

FROM debian:bookworm-slim@sha256:67b30a61dc87758f0caf819646104f29ecbda97d920aaf5edc834128ac8493d3

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system openlola \
    && useradd --system --gid openlola --home-dir /nonexistent --shell /usr/sbin/nologin openlola

COPY --from=build /opt/ultragrid/bin/uv /usr/local/bin/uv
USER openlola
HEALTHCHECK CMD uv --version >/dev/null || exit 1
ENTRYPOINT ["tini", "--", "uv"]
CMD ["--help"]
