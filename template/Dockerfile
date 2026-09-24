# syntax=docker/dockerfile:1
# Build the bot with the MoonBit toolchain image, then run the native
# executable on a distroless base. The executable links only libc and libm.
# Runtime images: gcr.io/distroless/base-debian13 matches the Debian trixie
# builder; a `-bookworm` builder tag pairs with base-debian12.
ARG MOONBIT_IMAGE=ghcr.io/gaato/moonbit:0.10.14-7d59c7ec9

FROM ${MOONBIT_IMAGE} AS build
# The image carries Node.js for Moon's prebuild hooks; the Gateway package
# also compiles a C source that includes <zlib.h>.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*
COPY moon.mod ./
RUN moon update
COPY src ./src
RUN moon build --target native --release src/main

FROM gcr.io/distroless/base-debian13
COPY --from=build /work/_build/native/release/build/main/main.exe /bot
USER nonroot:nonroot
# DISCORD_TOKEN and optional GUILD_ID come from the environment at run time.
ENTRYPOINT ["/bot"]
