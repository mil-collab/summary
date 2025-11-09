#!/bin/bash -e

err() {
    echo "$1" >&2
    exit 1
}

[[ ! -v CLUSTER_NAME ]] && err "CLUSTER_NAME must be provided"
[[ ! -v VAULT_ADDR ]] && err "VAULT_ADDR must be provided"

export VAULT_TOKEN=$(vault write -field=token auth/rancher-cluster/login \
    role=auth-creator \
    jwt=$(cat /run/secrets/kubernetes.io/serviceaccount/token))

# Use CA_DATA and CLUSTER_URL for Vault auth configuration
vault auth disable "$CLUSTER_NAME"

# Delete the cluster information from Vault
vault kv delete "cowman/clusters/${CLUSTER_NAME}"
