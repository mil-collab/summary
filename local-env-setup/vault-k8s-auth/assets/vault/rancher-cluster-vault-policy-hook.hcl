# Required to list auth methods
path "sys/auth" {
  capabilities = ["read", "list", "sudo"]
}

# Allow enabling/disabling auth methods
path "sys/auth/*" {
  capabilities = ["create", "update", "delete", "read", "list", "sudo"]
}

# Allow creating policies
path "sys/policies/*" {
  capabilities = ["create", "update", "delete", "read", "list", "sudo"]
}

# Allow configuring auth methods
path "auth/+/config" {
  capabilities = ["create", "update", "read", "list"]
}

# Allow managing roles for auth methods (e.g., userpass, JWT, etc.)
path "auth/+/role/*" {
  capabilities = ["create", "update", "delete", "read", "list"]
}

# Allow defining secrets in cowman's KV secret store
path "cowman/*" {
  capabilities = ["create", "update", "delete", "read", "list"]
}
