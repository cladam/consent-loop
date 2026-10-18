FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl \
        libcurl4-openssl-dev libmicrohttpd-dev libsqlite3-dev \
    && curl -sSL https://github.com/koka-lang/koka/releases/download/v3.2.3/install.sh | sh \
    && curl -fsSL https://www.hica.dev/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/root/.local/bin:$PATH
WORKDIR /src

COPY hica.hml hica.lock ./
RUN sed -i \
      -e 's| --ccincdir=/opt/homebrew/include||g' \
      -e 's| --cclinkopts=-L/opt/homebrew/lib||g' \
      hica.hml \
        && hica fetch \
        && test -n "$(find /root/.hica/cache/pkg.hica.dev/http -name http_server_inline.c -print -quit)" \
        && test -n "$(find /root/.hica/cache/pkg.hica.dev/sqlite -name sqlite-inline.c -print -quit)"

COPY src ./src
RUN hica build -o consent-loop \
    && test -x /src/consent-loop

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl \
        libcurl4 libmicrohttpd12 libsqlite3-0 \
    && adduser --system --no-create-home --group hica \
    && mkdir -p /app/data \
    && chown -R hica:hica /app \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/consent-loop /usr/local/bin/consent-loop

WORKDIR /app
VOLUME ["/app/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:8080/health | grep '"status": "ok"' || exit 1

EXPOSE 8080
ENV CONSENT_LOOP_DB_PATH=/app/data/consent-loop.db

USER hica
CMD ["/usr/local/bin/consent-loop"]
