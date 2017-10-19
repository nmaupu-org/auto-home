FROM centos

RUN yum update -y && \
    yum install -y epel-release && \
	yum install -y ansible python-pip openssh-client bash git bash-completion wget && \
	pip install paramiko && \
	wget -O /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl && \
	chmod +x /usr/bin/kubectl && \
	echo "alias kubectl=\"kubectl --kubeconfig=/root/.kube/kubeconfig-home\"" >> /root/.bashrc

ENV KUBECONFIG=/root/.kube/kubeconfig-home
