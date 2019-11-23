all: create
.PHONY: create

create:
	# This needs a root token
	vault write sys/policy/all-policy rules=@all-policy.hcl
	vault write sys/policy/kube-ro-policy rules=@kube-ro-policy.hcl
