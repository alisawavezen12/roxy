ARG GLEAM_VERSION=v1.18.1

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

RUN apk add --no-cache bash curl tar gzip

COPY ./shared /build/shared
COPY ./frontend /build/frontend
COPY ./backend /build/backend

RUN cd /build/shared && gleam deps download
RUN cd /build/frontend && gleam deps download
RUN cd /build/backend && gleam deps download

RUN cd /build/frontend \
  && gleam run -m lustre/dev build --minify --outdir=../backend/priv/static

RUN cd /build/backend \
  && gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine

WORKDIR /app
COPY --from=builder /build/backend/build/erlang-shipment /app

ENV HOST=0.0.0.0
ENV PORT=8080

EXPOSE 8080

CMD ["./entrypoint.sh", "run"]
