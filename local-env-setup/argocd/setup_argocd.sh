#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

current_context="$(kubectx -c)"
kubectx kind-main

helm repo add argo https://argoproj.github.io/argo-helm
helm repo add external-secrets https://charts.external-secrets.io

helm repo update
helm upgrade --install argocd argo/argo-cd \
	--namespace argocd \
       	--create-namespace \
	--set server.ingress.enabled=true \
	--set server.ingress.ingressClassName=nginx \
	--set server.ingress.annotations."nginx\\.ingress\\.kubernetes\\.io/ssl-redirect"="false" \
	--set configs.params.server\\.insecure=true \
	--set global.domain="$(${SCRIPT_DIR}/../generate_hostname.sh nginx)" \
    --wait


echo "Installing external-secrets operator"
helm upgrade --install external-secrets \
    external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true \
    --wait


# Apply the service account, cluster role binding, secret store and external secret resources
for asset in serviceaccount.yaml \
    clusterrolebinding.yaml \
    secretstore.yaml; do
        kubectl apply -f "${SCRIPT_DIR}/assets/${asset}"
done

while [[ "$(kubectl get -n argocd secretstore cowman-backend -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" != "True" ]]; do
  echo "Waiting for SecretStore to be ready"
  sleep 1
done

echo "SRE secret store is ready"

kubectx "$current_context"
