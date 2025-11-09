# Local Multi-Cluster Setup (POC / Development)

This repository provides a **local multi-cluster Kubernetes setup** for development and proof-of-concept purposes. It uses `kind` to create a main cluster and downstream clusters, and integrates **ArgoCD**, **Rancher**, and **Vault + External Secrets Operator (ESO)**.

> **Note:** This setup is for local testing only. You can always use `make teardown` to reset everything and start from scratch.

---

## Quick Overview

* **Main cluster**: created with `kind`, includes a **cloud-controller-manager (CCM)** running as a local Docker container. The CCM exposes `LoadBalancer` services from the main cluster to your host.
* **Downstream clusters**: multiple `kind` clusters that can be managed by ArgoCD and Rancher.
* **ArgoCD**: installed via Helm on the main cluster; downstream clusters are registered using generated secrets.
* **Rancher**: installed on the main cluster; downstream clusters can be imported and managed through the Rancher UI.
* **Vault + ESO**: local Vault instance for Kubernetes authentication; ESO installed on downstream clusters to retrieve secrets from Vault.

---

## Make sure the environment is clean

```bash
make teardown
```

---

## Setup Rancher

Run the following to bring up the ArgoCD and Rancher environment:

```bash
make install-rancher
```

That target:
   * Installs Rancher on the main cluster (`make install-rancher`).
   * Downstream clusters are **not** automatically registered (done below).

Once that finishes, access the printed Rancher URL and **finish initialization** by inputting an admin password. **DO NOT** update the Rancher URL.


---

## Running Vault

In another terminal session, run:

```bash
make run-vault
```

This will run Vault locally. In order to access Vault, run the following command in order to retrieve the local gateway IP:

```bash
docker network inspect kind --format '{{ (index .IPAM.Config 0).Gateway }}'
```

The Vault url will then be: **http://<gateway_ip>:8200**.
Use that wherever Vault URL or address is needed.
**Keep the terminal session for Vault open**.

---

## Setup ArgoCD

```bash
make install-argocd
```

This executes:
   * Creates main cluster (`make create-main-cluster`) with CCM.
   * Installs ArgoCD via Helm (`make install-argocd`).

---

## Accessing Vault

Visit the Vault URL from the **Running Vault** section, in your browser.
Use Vault's root token from `~/.vault-token` as the token for authentication.

---

## Accessing ArgoCD

Retrieve the default admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Ensure you are using the **main cluster kubeconfig** when accessing ArgoCD.

When running the install-argocd target, a URL will be printed out. Visit that URL. For example: [https://nginx.172.18.0.5.sslip.io](https://nginx.172.18.0.5.sslip.io)

---

## Accessing Rancher

When running the install-rancher target, a URL will be printed out. Visit that URL. For example: [https://rancher.172.18.0.5.sslip.io](https://rancher.172.18.0.5.sslip.io)

---

## Prepare required secrets in Vault

### Rancher bearer token
A Rancher bearer token is expected to exist in Vault. It will be used by ArgoCD to access all clusters.

**First**, in Rancher, create a token by clicking on the user on the top right corner → Account & API Keys → Create API Key. Copy the **Bearer Token**.

**Second**, in Vault, create a secret `cowman/sre-token` (`cowman` here refers to the secrets engine with that name). Put a `config` key in it, and fill the value with:
```json
{"bearerToken": "token", "tlsClientConfig": {"insecure": true}}
```
Make sure to replace **token** with the actual bearer token from Rancher.

### trident secret
In Vault, create a secret  `secrets/trident` (`secrets` here refers to the KV engine called `secrets`). Put a key `data` with the trident token (or any content for the sake of this POC).

---

## Ensure the `rancher-cluster-setup` chart is deployed

Deploy the `rancher-cluster-setup` chart to the `main` cluster.
That chart will ensure there's a cluster within Rancher for the clusters we create, and that Vault is configured to allow them to access it for pulling secrets (e.g., trident token).

* Build the [rancher-cluster-setup-hook](https://github.com/mil-collab/images/tree/main/rancher-cluster-setup-hook) image.
* Make sure to load it to the `kind-main` cluster with the `kind load image` command.
* Use `main` cluster:
	```bash
	kubectx kind-main
	```
* Install the chart on `kind-main` according to the chart's README instuctions. Make sure that:
	* You use the `imported=true` value for `kind` clusters to be registered correctly.
	* You install it **twice**: first with `clusterName=cluster1` and second with `clusterName=cluster2`.
	```bash
	helm install --set imported=true --set clusterName=cluster1 --generate-name .
	```

If the Helm installation is stuck, check the `post-install` / `pre-delete` job statuses:
```bash
kubectl get job
```

If you want to uninstall the chart and the hook can't be triggered for some reason (e.g., if Vault is down), use (**note**: this will remove the chart without deleting cluster leftovers from Vault):
```bash
helm uninstall --no-hooks <release>
```

---

## Enable JWT authentication for the newly created clusters in Rancher

**TODO**: this needs to be automated.

* Visit Rancher → Hamburger Menu → Cluster Management → Advanced → JWT Authentication
* Click the three dots near each cluster, and choose **Enable**.

---

## Register the kind clusters into Rancher

* Visit Rancher → Hamburger Menu → Cluster Management
* For each cluster:
	* Click on the cluster name
	* Copy the registration command (use the **insecure** one for the POC `kind` setup)
	* On your machine, change to the cluster context with `kubectx`
	* Run the registration command 

**Wait for all clusters to be _Active_**.

---

## Setup downstream clusters to pull secrets from Vault (e.g., trident)

```bash
make downstream-setup-vault-auth
```
This currently only supports `cluster1`. Refer to the target comment in the Makefile for more details.
* Check for the `secret` resource in `trident` namespace.
* If there is no such secret, check the external secret status:
   ```bash
   kubectl describe externalsecret -n trident
   ```

---

## Deploy the SRE secret to ArgoCD

This step will effectively register the downstream clusters to ArgoCD in a secure manner through Vault.
The `examples/sre-external-secret.yaml` file contains a manifest for registering `cluster1`. Deploy it:
* Make sure you use the `main` cluster's kubeconfig context.
* Deploy:
  ```bash
  kubectl apply -f examples/sre-external-secret.yaml
  ```
* Check the secret exists:
  ```bash
  kubectl get secret -n argocd cluster1
  ```
* Check the cluster is showing up in ArgoCD settings page.
* Create an Application that targets the cluster.


---

## Teardown

Remove all clusters, stop CCM, and clean temporary files:

```bash
make teardown
```

This deletes all `kind` clusters, stops the CCM container, and removes temporary files.

---

## Notes

* **Cloud-Controller-Manager (CCM)**: runs as a Docker container on your host; allows exposing `LoadBalancer` services from the `kind` clusters to your local machine.
* There are some *utility targets* in the Makefile for:
	* Registering the clusters to ArgoCD directly (not through Rancher). That's probably not needed since we register through Rancher and it's redundant, however it is kept for reference - `register-clusters-argocd`
	* Registering the GitHub repository to ArgoCD - `generate-repo-secret`

---

This README is designed as a **quick start for local development**—follow the steps in order and use `teardown` if you need a fresh environment.

