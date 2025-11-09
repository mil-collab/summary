# Allow reading secrets in cowman's KV secret store
path "cowman/data/*" {
  capabilities = ["read", "list"]
}

path "cowman/metadata/*" {
  capabilities = ["read", "list"]
}
