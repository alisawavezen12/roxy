ARG GLEAM_VERSION=v1.18.1
ARG BUN_VERSION=1.2.22

FROM oven/bun:${BUN_VERSION}-alpine AS bun

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS frontend-build

COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

WORKDIR /build

COPY ./shared/gleam.toml ./shared/manifest.toml ./shared/
COPY ./frontend/gleam.toml ./frontend/manifest.toml ./frontend/

RUN cd /build/shared && gleam deps download
RUN cd /build/frontend && gleam deps download

COPY ./shared/src ./shared/src
COPY ./frontend/src ./frontend/src
COPY ./frontend/assets ./frontend/assets

RUN cd /build/frontend \
  && gleam run -m lustre/dev build --minify --outdir=dist \
  && rm -f dist/.gitkeep

FROM nginxinc/nginx-unprivileged:1.29-alpine AS frontend-runtime

COPY ./frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=frontend-build /build/frontend/dist /usr/share/nginx/html

EXPOSE 8080

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS backend-build

WORKDIR /build

COPY ./shared/gleam.toml ./shared/manifest.toml ./shared/
COPY ./backend/gleam.toml ./backend/manifest.toml ./backend/

RUN cd /build/shared && gleam deps download
RUN cd /build/backend && gleam deps download

COPY ./shared/src ./shared/src
COPY ./backend/src ./backend/src

RUN cd /build/backend && gleam export erlang-shipment

FROM erlang:28-alpine AS backend-runtime

RUN addgroup -S roxy \
  && adduser -S -D -H -G roxy roxy

WORKDIR /app

COPY --from=backend-build --chown=roxy:roxy /build/backend/build/erlang-shipment /app

USER roxy

EXPOSE 8080

CMD ["sh", "./entrypoint.sh", "run"]
