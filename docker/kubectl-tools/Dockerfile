FROM debian:bookworm-slim

ARG KUBECTL_VERSION=v1.32.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      jq \
      ca-certificates \
 && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

CMD ["kubectl"]
