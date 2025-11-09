#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

current_context="$(kubectx -c)"
kubectx kind-main

echo "Installing cert-manager"
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.18.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait


echo "Installing Rancher. This might take a few minutes"
helm install rancher rancher-latest/rancher \
	--version 2.11.3 \
	--namespace cattle-system \
	--set hostname="$(${SCRIPT_DIR}/../generate_hostname.sh rancher)" \
	--set bootstrapPassword=admin \
	--set ingress.ingressClassName=nginx \
	--create-namespace \
	--wait

kubectx "$current_context"
