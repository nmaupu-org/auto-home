GOOGLE_PROJECT_ID ?= my-project
EMAIL_ADDRESS     ?= $(USER)@example.com

.PHONY: cert-manager-iot
cert-manager-iot:
	sed -e 's/@@EMAIL_ADDRESS@@/$(EMAIL_ADDRESS)/' \
	    -e 's/@@GOOGLE_PROJECT_ID@@/$(GOOGLE_PROJECT_ID)/' \
	    bootstrap/cert-manager-application.yaml | \
	    kubectl --context home-nas -n argocd apply -f -
