#!/bin/bash
set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to clean up background jobs
cleanup() {
    echo "Caught SIGINT, killing all jobs..."
    jobs -p | xargs -r kill
    exit 1
}

# Trap SIGINT
trap cleanup SIGINT

vault server -dev -dev-listen-address=0.0.0.0:8200 -log-level=debug &
export VAULT_ADDR=http://172.18.0.1:8200

while ! vault status 2>/dev/null; do
  echo "Waiting for Vault to be up"
  sleep 1
done

echo "Vault is up and running"

current_context="$(kubectx -c)"

RANCHER_CA_DATA="$(kubectl get secret -n cattle-system tls-rancher-ingress -o jsonpath='{@.data.ca\.crt}' | base64 -d)"
RANCHER_CLUSTER_URL="https://$(${SCRIPT_DIR}/../generate_hostname.sh rancher)/k8s/clusters/local"
VAULT_AUDIENCE="https://kubernetes.default.svc.cluster.local"

#######################################################################
# Define an auth method for the cluster chart install hooks.          #
# This allows them to define other auth methods, one per cluster      #
# that is being installed. It also allows them to add the cluster URL #
# to the cowman KV store in Vault.                                    #
#######################################################################

# Write a Vault policy that allows reading and listing the secret
vault policy write rancher-auth-policy "${SCRIPT_DIR}/assets/vault/rancher-cluster-vault-policy-hook.hcl"

# Define an auth method named myk8s. This should be done once per K8s cluster
vault auth enable -path=rancher-cluster kubernetes

# Setup the auth method with the downstream cluster details
vault write auth/rancher-cluster/config \
	kubernetes_host="${RANCHER_CLUSTER_URL}" \
	kubernetes_ca_cert="${RANCHER_CA_DATA}" \
	disable_local_ca_jwt=true

# Define a role for the auth method that bounds the specific SA by name and namespace,
# with the policy that allows it to read the specific secret that was created above.
# It also defines the audience key which will be required by future version of Vault.
# In order to determine the value for the `audience` parameter on your setup, refer
# to `determining-role-audience/README.md`
vault write auth/rancher-cluster/role/auth-creator \
	audience="${VAULT_AUDIENCE}" \
	bound_service_account_names="*-auth-serviceaccount" \
	bound_service_account_namespaces="*" \
	policies=rancher-auth-policy \
	ttl=1h

#######################################################################
# Define an auth method for the external secrets operator to be able  #
# to read secret data from the cowman kv store.                       #
# This is used for the SRE secrets.                                   #
#######################################################################

# A KV secrets engine for cowman-related secrets
vault secrets enable -path=cowman -version=2 kv

# Write a Vault policy that allows reading and listing the secret
vault policy write rancher-cowman-policy "${SCRIPT_DIR}/assets/vault/rancher-cluster-vault-policy-cowman.hcl"

# Define an auth method named myk8s. This should be done once per K8s cluster
vault auth enable -path=cowman kubernetes

# Setup the auth method with the downstream cluster details
vault write auth/cowman/config \
	kubernetes_host="${RANCHER_CLUSTER_URL}" \
	kubernetes_ca_cert="${RANCHER_CA_DATA}" \
	disable_local_ca_jwt=true

# Define a role for the auth method that bounds the specific SA by name and namespace,
# with the policy that allows it to read the specific secret that was created above.
# It also defines the audience key which will be required by future version of Vault.
# In order to determine the value for the `audience` parameter on your setup, refer
# to `determining-role-audience/README.md`
# Note: this role is bound for service accounts on the ArgoCD namespace: SRE cluster
# secrets should be there.
vault write auth/cowman/role/cowman \
	audience="${VAULT_AUDIENCE}" \
	bound_service_account_names="cowman-serviceaccount" \
	bound_service_account_namespaces="argocd" \
	policies=rancher-cowman-policy \
	ttl=1h

kubectx "$current_context"

wait "$(jobs -p)"
