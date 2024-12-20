TRUECHARTS_OCI ?= oci://tccr.io/truecharts
GOOGLE_PROJECT_ID ?= my-project
EMAIL_ADDRESS ?= $(USER)@gmail.com

.PHONY: all
all: argocd

google-key.json:
	# The google service account "home-dns01-solver" needs to exist beforehand
	# Check README to know how to create it
	gcloud iam service-accounts keys create google-key.json --iam-account home-dns01-solver@$(GOOGLE_PROJECT_ID).iam.gserviceaccount.com
	kubectl create ns cert-manager || true
	kubectl create secret generic google-dns01-solver --from-file=google-key.json --namespace cert-manager

.PHONY:cert-manager
cert-manager: google-key.json
	# This helm install takes up to 5 minutes ;-)
	helm upgrade --install --namespace cert-manager --create-namespace cert-manager $(TRUECHARTS_OCI)/cert-manager \
			--set certmanager.prometheus.enabled=false \
			--set certmanager.prometheus.servicemonitor.enabled=false
	sed -e 's/@@EMAIL_ADDRESS@@/$(EMAIL_ADDRESS)/' -e 's/@@GOOGLE_PROJECT_ID@@/$(GOOGLE_PROJECT_ID)/' letsencrypt-google-dns.yaml | \
    kubectl apply -f -

sealed-secrets.crt:
	$(error please create sealed-secrets.crt here)

sealed-secrets.key:
	$(error please create sealed-secrets.key here)

.PHONY: sealed-secrets
sealed-secrets: sealed-secrets.crt sealed-secrets.key
	kubectl create ns sealed-secrets
	kubectl -n sealed-secrets create secret tls mycustomkeys \
		--cert="sealed-secrets.crt" --key="sealed-secrets.key"
	kubectl -n sealed-secrets label secret mycustomkeys \
		sealedsecrets.bitnami.com/sealed-secrets-key=active


.PHONY: argocd
argocd: cert-manager sealed-secrets
	# Argo repo must first be added to the helm repo list
	# helm repo add argo https://argoproj.github.io/argo-helm
	# helm repo update
	helm upgrade --install --namespace argocd --create-namespace argocd argo/argo-cd --version 7.7.10 \
		--values argocd-values.yaml
	kubectl apply -f bootstrap.yaml
