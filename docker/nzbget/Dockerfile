# syntax=docker/dockerfile:1
ARG NZBGET_IMAGE_VERSION

FROM alpine/git:2.45.2 as build
ARG EXT_UNRAR_VERSION
WORKDIR /tmp
RUN git clone --depth 1 --branch "$EXT_UNRAR_VERSION" -- https://github.com/nzbgetcom/Extension-ExtendedUnrar.git

FROM ghcr.io/geek-cookbook/nzbget:$NZBGET_IMAGE_VERSION
COPY --from=build /tmp/Extension-ExtendedUnrar /app/scripts/Extension-ExtendedUnrar/
