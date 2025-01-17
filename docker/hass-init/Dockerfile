# syntax=docker/dockerfile:1
ARG YQ_VERSION
FROM mikefarah/yq:${YQ_VERSION}

USER root

RUN apk update
RUN apk add curl git bash unzip rsync

USER yq
