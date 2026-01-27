FROM bitnami/minideb:bookworm

ARG KUBECTL_VERSION

RUN install_packages \
      ca-certificates \
      ansible \
      python3 \
      python3-venv \
      python3-pip \
      python3-urllib3 \
      openssh-client \
      bash \
      bash-completion \
      git \
      wget \
      gcc \
      python-is-python3

# Create a dedicated venv and install non-Debian Python deps there
RUN python3 -m venv /opt/venv \
  && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
  && /opt/venv/bin/pip install --no-cache-dir paramiko

# Make the venv the default python/pip at runtime
ENV PATH="/opt/venv/bin:${PATH}"

RUN wget -O /usr/bin/kubectl \
      "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  && chmod +x /usr/bin/kubectl \
  && echo 'alias kubectl="kubectl --kubeconfig=/root/.kube/kubeconfig-home"' >> /root/.bashrc

RUN useradd -u 1000 -m builder \
  && mkdir -p /workspace \
  && chown -R builder: /workspace

USER 1000
ENV KUBECONFIG=/root/.kube/kubeconfig-home
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
