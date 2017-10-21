#!/bin/bash

kubectl apply -f /workspace/kubernetes/admin

# kube-system tools
kubectl apply -Rf /workspace/kubernetes/kube-system/

