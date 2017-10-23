# Policies have to be applied when vault is up and running
# $ vault write sys/policy/my-policy rules=@my-policy.hcl
# See https://www.vaultproject.io/docs/concepts/policies.html

path "secret/*" {
	capabilities = ["create", "read", "update", "delete", "list"]
}
