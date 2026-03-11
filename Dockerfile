# ---- Build stage ----
FROM hexpm/elixir:1.18.3-erlang-27.3-debian-bookworm-20250317-slim AS build

RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Fetch deps first — cached unless mix.exs/mix.lock changes
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Compile deps — cached unless deps change
RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

# Copy source and compile app (generates phoenix-colocated for esbuild)
COPY priv priv
COPY lib lib
COPY assets assets
RUN mix compile

# Build assets (needs phoenix-colocated from _build)
RUN mix assets.deploy

COPY config/runtime.exs config/
RUN mix release

# ---- Runtime stage ----
FROM debian:bookworm-slim AS app

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    PHX_SERVER=true

WORKDIR /app
RUN chown nobody /app

COPY --from=build --chown=nobody:root /app/_build/prod/rel/dnd ./

USER nobody

EXPOSE 8080

CMD ["/app/bin/dnd", "start"]
