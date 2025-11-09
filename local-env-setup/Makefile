# Colors for pretty output
BLUE := \033[34m
GREEN := \033[32m
RESET := \033[0m

# Variables
MAIN_CLUSTER := main
DOWNSTREAM_CLUSTERS := cluster1 cluster2
TMP_DIR := /tmp/argocd-kind
SECRETS_DIR := $(TMP_DIR)/secrets
REPO_URL := git@github.com:mil-collab/quick-iac.git
PRIVATE_KEY_FILE := ~/.ssh/id_ed25519
REPO_SECRET_FILE := $(TMP_DIR)/repo-secret.yaml

.SILENT:

# Default target
.PHONY: all
all: teardown register-clusters-argocd install-rancher
	echo -e "$(GREEN)Access ArgoCD via https://$$(./generate_hostname.sh nginx)$(RESET)"
	echo -e "$(GREEN)Access Rancher via: https://$$(./generate_hostname.sh rancher)$(RESET)"

# Create temporary directories
.PHONY: prepare-dirs
prepare-dirs:
	mkdir -p $(SECRETS_DIR)

# Create the main cluster using kind
.PHONY: create-main-cluster
create-main-cluster: prepare-dirs
	echo -e "$(GREEN)Creating the main cluster with kind$(RESET)"
	kind create cluster --name $(MAIN_CLUSTER) --config assets/cluster-config.yaml
	kind get kubeconfig --name $(MAIN_CLUSTER) > $(TMP_DIR)/$(MAIN_CLUSTER).kubeconfig
	echo -e "$(GREEN)Setting up local cloud-provider-manager to be able to access KIND LoadBalancer services$(RESET)"
	docker run --rm -d --network kind -v /var/run/docker.sock:/var/run/docker.sock registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.7.0


# Create downstream clusters using kind
.PHONY: create-downstream-clusters
create-downstream-clusters: prepare-dirs
	for cluster in $(DOWNSTREAM_CLUSTERS); do \
		echo -e "$(GREEN)Creating downstream cluster $$cluster with kind$(RESET)"; \
		kind create cluster --name $$cluster --config assets/cluster-config.yaml; \
		kind get kubeconfig --name $$cluster > $(TMP_DIR)/$$cluster.kubeconfig; \
	done

# Install nginx with Helm on the main cluster
.PHONY: install-nginx
install-nginx: create-main-cluster
	echo -e "$(GREEN)Installing NGINX with Helm$(RESET)"
	helm upgrade --install ingress-nginx ingress-nginx   --repo https://kubernetes.github.io/ingress-nginx   --namespace ingress-nginx --create-namespace

# Install ArgoCD with Helm on the main cluster
.PHONY: install-argocd
install-argocd: # create-main-cluster install-nginx
	echo -e "$(GREEN)Installing ArgoCD with Helm$(RESET)"
	bash argocd/setup_argocd.sh
	echo -e "$(GREEN)Access ArgoCD via https://$$(./generate_hostname.sh nginx)$(RESET)"

.PHONY: venv
venv:
	python3 -m venv $(TMP_DIR)/venv
	$(TMP_DIR)/venv/bin/pip install -r argocd/requirements.txt

# Generate secrets for downstream clusters using generate-cluster-secret.py
.PHONY: generate-secrets
generate-secrets: create-downstream-clusters prepare-dirs venv
	for cluster in $(DOWNSTREAM_CLUSTERS); do \
		echo -e "$(GREEN)Generating ArgoCD cluster secret for cluster $$cluster$(RESET)"; \
		$(TMP_DIR)/venv/bin/python3 argocd/generate-cluster-secret.py --argocd-namespace argocd --cluster-name $$cluster > $(SECRETS_DIR)/$$cluster.yaml; \
	done

# Register downstream clusters by applying generated secrets to ArgoCD cluster
.PHONY: register-clusters-argocd
register-clusters-argocd: install-argocd generate-secrets
	for secret in $(SECRETS_DIR)/*.yaml; do \
		echo -e "$(GREEN)Registering cluster $$cluster to ArgoCD$(RESET)"; \
		KUBECONFIG=$(TMP_DIR)/$(MAIN_CLUSTER).kubeconfig kubectl apply -f $$secret; \
	done

.PHONY: generate-repo-secret
generate-repo-secret: install-argocd venv
	echo -e "$(GREEN)Generating repository secret$(RESET)"
	$(TMP_DIR)/venv/bin/python3 argocd/generate-repository-secret.py \
		--repository-name repo \
		--argocd-namespace argocd \
		--repository-url $(REPO_URL) \
		--ssh-private-key $(PRIVATE_KEY_FILE) > $(REPO_SECRET_FILE)
	echo -e "$(GREEN)Applying repository secret to ArgoCD$(RESET)"
	KUBECONFIG=$(TMP_DIR)/$(MAIN_CLUSTER).kubeconfig kubectl apply -f $(REPO_SECRET_FILE)

.PHONY: run-vault
run-vault:
	bash vault-k8s-auth/setup-local-vault.sh

# TODO: this target currently sets things up on cluster1 only.
# The script which is executed by this target applies raw manifests with cluster1
# hardcoded in them. Those manifests should be turned into a templated Helm chart.
# When this happens, that target needs to install the chart with a proper value
# that will deploy the manifests with the correct cluster name strings.
.PHONY: downstream-setup-vault-auth
downstream-setup-vault-auth:
	@for cluster in cluster1; do \
	echo -e "$(GREEN)Setting up Vault auth POC$(RESET)"; \
	export DOWNSTREAM_CLUSTER="kind-$${cluster}"; \
	bash vault-k8s-auth/setup-downstream-cluster.sh; \
	echo -e "$(GREEN)Important! Make sure that JWT token authentication is \
	\nenabled on the downstream cluster, otherwise this will not work. \
	\nReference: \
	\nhttps://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/authentication-permissions-and-global-configuration/jwt-authentication$(RESET)"; \
	done

# Install Rancher with Helm on the main cluster
.PHONY: install-rancher
install-rancher: create-main-cluster install-nginx
	echo -e "$(GREEN)Installing Rancher$(RESET)"
	bash rancher/rancher-install.sh
	echo -e "$(GREEN)Access Rancher via: https://$$(./generate_hostname.sh rancher)$(RESET)"


# Show a nice message with instructions of how to use the setup
.PHONY: instructions
instructions:
	echo -e "$(BLUE)Follow the README.md file.$(RESET)"


.PHONY: teardown
teardown:
	echo -e "$(GREEN)Tearing down kind clusters$(RESET)"
	kind delete cluster --name $(MAIN_CLUSTER)
	for cluster in $(DOWNSTREAM_CLUSTERS); do \
		kind delete cluster --name $$cluster; \
	done
	echo -e "$(GREEN)Tearing down the ccm container$(RESET)"
	docker ps --format=json | jq -r 'select(.Image | test(".*cloud-controller-manager.*")) | .ID' | xargs docker kill || true
	docker ps --format=json | jq -r 'select(.Image | test(".*envoyproxy/envoy.*")) | .ID' | xargs docker kill || true
	rm -rf $(TMP_DIR)
