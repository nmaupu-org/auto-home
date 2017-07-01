FROM alpine

RUN apk update && \
    apk upgrade && \
    apk add ansible py-pip && \
    pip install paramiko

COPY tmp/terraform /usr/bin/terraform
