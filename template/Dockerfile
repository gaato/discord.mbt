# syntax=docker/dockerfile:1
# Build the bot with the MoonBit toolchain image, then run the native
# executable on a distroless base. The executable links only libc and libm.
# Runtime images: gcr.io/distroless/base-debian13 matches the Debian trixie
# builder; a `-bookworm` builder tag pairs with base-debian12.
ARG MOONBIT_IMAGE=ghcr.io/gaato/moonbit:0.10.16-b1a0e846e

FROM ${MOONBIT_IMAGE} AS build
# The image also carries Node.js, which the prebuild hooks of
# gaato/discord_voice need.
RUN moon update
# The whole context, so a workspace (`moon.work` and its members) builds too.
COPY . ./
# Inside a workspace the output directory carries the module name, so take
# the executable from wherever the build put it.
RUN moon build --target native --release src/main && \
    install -D "$(find _build/native/release/build -path '*/main/main.exe' -print -quit)" /out/bot

FROM gcr.io/distroless/base-debian13
COPY --from=build /out/bot /bot
USER nonroot:nonroot
# DISCORD_TOKEN and optional GUILD_ID come from the environment at run time.
ENTRYPOINT ["/bot"]
