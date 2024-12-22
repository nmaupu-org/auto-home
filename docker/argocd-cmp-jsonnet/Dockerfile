FROM bitnami/minideb:bookworm

ARG JB_VERSION
ARG JSONNET_VERSION

USER root
# Adding rsync to be able to use the already pulled image for other stuff (gotomation git-refresher sidecar)
RUN apt update && apt install -y jq curl git rsync

RUN curl -L -o /tmp/jsonnet-go.deb https://github.com/google/go-jsonnet/releases/download/v${JSONNET_VERSION}/jsonnet-go_${JSONNET_VERSION}_linux_amd64.deb && \
    dpkg -i /tmp/jsonnet-go.deb

ADD https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v${JB_VERSION}/jb-linux-amd64 /usr/bin/jb
RUN chmod +x /usr/bin/jb

USER 999
