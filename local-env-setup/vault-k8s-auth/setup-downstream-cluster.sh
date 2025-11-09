#!/bin/bash
set -e

current_context="$(kubectx -c)"
kubectx "$DOWNSTREAM_CLUSTER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/assets/downstream-cluster"

# Install the External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets \
    external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true \
    --wait


# Temporary
kubectl create ns trident || true

# Apply trident's service account, cluster role binding, secret store and external secret resources
for asset in sa.yaml \
    clusterrolebinding.yaml \
    secretstore.yaml; do
        kubectl apply -f "$asset"
done

kubectl apply -f external-secret.yaml

kubectx "$current_context"
