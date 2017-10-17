FROM centos

ARG HTTP2BACK_VERSION

RUN yum -y update && \
    curl -sfLo /http2back https://github.com/nmaupu/http2back/releases/download/v${HTTP2BACK_VERSION}/http2back_linux-amd64 && \
    chmod +x /http2back

ENTRYPOINT ["/http2back"]
