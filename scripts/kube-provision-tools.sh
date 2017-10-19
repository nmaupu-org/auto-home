#!/bin/bash

kubectl apply -f /workspace/kubernetes/admin

# kube-ops-view
git clone https://github.com/hjacobs/kube-ops-view.git /tmp/kov && \
	kubectl apply -f /tmp/kov/deploy && \
	rm -rf /tmp/kov

# kube-system tools
kubectl apply -f /workspace/kubernetes/kube-system
