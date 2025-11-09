#!/bin/bash -e

err() {
    echo "$1" >&2
    exit 1
}

[[ ! -v CLUSTER_NAME ]] && err "CLUSTER_NAME must be provided"
[[ ! -v RANCHER_DOMAIN ]] && err "RANCHER_DOMAIN must be provided"
[[ ! -v VAULT_ADDR ]] && err "VAULT_ADDR must be provided"
[[ ! -v VAULT_AUDIENCE ]] && err "VAULT_AUDIENCE must be provided"

while true; do
  CLUSTER_ID="$(kubectl get cluster.provisioning.cattle.io -n fleet-default "${CLUSTER_NAME}" -o jsonpath='{@.status.clusterName}')"
  if [ -n "$CLUSTER_ID" ]; then
    echo "Cluster ID: $CLUSTER_ID"
    break
  fi
  sleep 1
done

# Enable JWT authentication to allow ServiceAccounts to authenticate with Vault.
# See https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/authentication-permissions-and-global-configuration/jwt-authentication
cat <<EOF | kubectl apply -f -
apiVersion: management.cattle.io/v3
enabled: true
kind: ClusterProxyConfig
metadata:
  name: clusterproxyconfig
  namespace: "${CLUSTER_ID}"
EOF

CA_DATA="$(kubectl get secret -n cattle-system tls-rancher-ingress -o jsonpath='{@.data.ca\.crt}' | base64 -d)"
CLUSTER_URL="https://${RANCHER_DOMAIN}/k8s/clusters/${CLUSTER_ID}"

# Login
export VAULT_TOKEN=$(vault write -field=token auth/rancher-cluster/login \
    role=auth-creator \
    jwt=$(cat /run/secrets/kubernetes.io/serviceaccount/token))

# Setup a Kubernetes auth method for the newly-created cluster.
# This ensures that the cluster would be able to authenticate with Vault
# when using the External Secrets Operator.
vault auth enable -path="$CLUSTER_NAME" kubernetes
vault write auth/${CLUSTER_NAME}/config \
    kubernetes_host="${CLUSTER_URL}" \
    kubernetes_ca_cert="${CA_DATA}" \
    disable_local_ca_jwt=true

cat <<EOF | vault policy write ${CLUSTER_NAME}-policy -
path "secret/data/trident" { 
    capabilities = ["read", "list"]
}

path "secret/metadata/trident" {
    capabilities = ["read", "list"]
}
EOF


# TODO: hardcoded trident. Allow values to be provided from
# outside the chart to generate roles/permissions to other paths.
vault write auth/${CLUSTER_NAME}/role/trident \
    audience="$VAULT_AUDIENCE" \
    bound_service_account_names="trident" \
    bound_service_account_namespaces="trident" \
    policies="${CLUSTER_NAME}-policy" \
    ttl=1h


# Create a Vault secret with the cluster URL
vault kv put "cowman/clusters/${CLUSTER_NAME}" cluster_url="${CLUSTER_URL}"
