FROM alpine

RUN apk update && \
    apk upgrade && \
    apk add ansible py-pip openssh-client openssl bash && \
    pip install paramiko && \
    wget -O /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    echo "alias kubectl=\"kubectl --kubeconfig=/workspace/terraform/matchbox-home/bootkube-install/assets/auth/kubeconfig\"" >> /root/.bashrc
    
