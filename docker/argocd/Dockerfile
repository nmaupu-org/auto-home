ARG ARGOCD_VERSION
FROM argoproj/argocd:v${ARGOCD_VERSION}

ARG JB_VERSION

USER root
ADD https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v${JB_VERSION}/jb-linux-amd64 /usr/bin/jb
RUN chmod +x /usr/bin/jb

USER argocd
