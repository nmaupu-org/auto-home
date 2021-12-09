FROM centos

ARG KUBECTL_VERSION

RUN yum update -y
RUN yum install -y epel-release
RUN yum install -y ansible python3-pip openssh-clients bash git bash-completion wget
RUN pip3 install paramiko
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN wget -O /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
	chmod +x /usr/bin/kubectl && \
	echo "alias kubectl=\"kubectl --kubeconfig=/root/.kube/kubeconfig-home\"" >> /root/.bashrc

RUN useradd -u 1000 builder && \
    mkdir -p /workspace && chown -R builder: /workspace

USER 1000
ENV KUBECONFIG=/root/.kube/kubeconfig-home
