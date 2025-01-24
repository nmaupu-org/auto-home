# syntax=docker/dockerfile:1
FROM bitnami/minideb:bookworm

ARG KUBECTL_VERSION
USER root

RUN apt-get update
RUN apt-get -y install bash curl git zip unzip
RUN curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && chmod +x /usr/local/bin/kubectl

user nobody
