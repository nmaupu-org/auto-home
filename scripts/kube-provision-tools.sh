#!/bin/bash

kubectl apply -f /workspace/kubernetes/home/kube-system

kubectl apply -f /workspace/kubernetes/home/namespaces.yml
kubectl apply -f /workspace/kubernetes/home/minio

kubectl apply -f /workspace/kubernetes/home/photoweb.yml
