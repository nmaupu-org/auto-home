FROM alpine

ARG GONAOMI_VERSION

RUN apk update && \
    apk add curl jq && \
    curl -sfLo /gonaomi https://github.com/nmaupu/gonaomi/releases/download/${GONAOMI_VERSION}/gonaomi_linux-amd64 && \
    chmod +x /gonaomi

ENTRYPOINT ["/gonaomi"]
