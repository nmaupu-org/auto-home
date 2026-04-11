GOOGLE_PROJECT_ID ?= my-project
EMAIL_ADDRESS     ?= $(USER)@gmail.com

.PHONY: all
all: argocd

google-key.json:
	# The google service account "home-dns01-solver" needs to exist beforehand
	# Check nix/README.md to know how to create it
	gcloud iam service-accounts keys create google-key.json \
		--iam-account home-dns01-solver@$(GOOGLE_PROJECT_ID).iam.gserviceaccount.com
	kubectl create ns cert-manager || true
	kubectl create secret generic google-dns01-solver \
		--from-file=google-key.json --namespace cert-manager

.PHONY: cert-manager
cert-manager: google-key.json
	helm repo add jetstack https://charts.jetstack.io --force-update
	helm upgrade --install --namespace cert-manager --create-namespace cert-manager jetstack/cert-manager \
		--set crds.enabled=true --values cert-manager-values.yaml
	sed -e 's/@@EMAIL_ADDRESS@@/$(EMAIL_ADDRESS)/' \
	    -e 's/@@GOOGLE_PROJECT_ID@@/$(GOOGLE_PROJECT_ID)/' \
	    cert-manager-issuers-application.yaml | \
	    kubectl -n argocd apply -f -

.PHONY: argocd
argocd: cert-manager
	helm repo add argo https://argoproj.github.io/argo-helm --force-update
	helm repo update argo
	helm upgrade --install --namespace argocd --create-namespace argocd argo/argo-cd \
		--version 9.5.0 \
		--values home/infra/argocd/argocd-values.yaml
	kubectl apply -f bootstrap.yaml
