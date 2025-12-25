# Node Feature Discovery (NFD) POC

## Purpose

This Proof of Concept (POC) is designed to experiment with:

- **Easy Setup**: Testing simple installation methods for the Node Feature Discovery (NFD) Kubernetes addon
- **Local Features Exploration**: Discovering and testing the local node features that NFD can detect

## What is Node Feature Discovery (NFD)?

Node Feature Discovery is a Kubernetes addon that automatically detects hardware features available on each node in the cluster and advertises those features using node labels.

## Features Discovered

NFD can detect various local node features including:
- CPU features (e.g., AVX, SSE, virtualization extensions)
- Hardware topology (NUMA nodes, CPU sockets)
- Memory features and capacity
- Storage capabilities
- Network interface features
- GPU and accelerator information

## Steps For Basic Testing

### Install a Local Cluster
Can be done using [Minikube](https://minikube.sigs.k8s.io/docs/).
```bash
brew install minikube
minikube start
```

### Install the NFD Addon
There are several methods for installation, which are documented [here](https://kubernetes-sigs.github.io/node-feature-discovery/v0.17/deployment/).
For this experiment, I chose to install using Helm:
```bash
(⎈|minikube:default)➜  ~ export NFD_NS=node-feature-discovery
helm repo add nfd https://kubernetes-sigs.github.io/node-feature-discovery/charts
helm repo update
helm install nfd/node-feature-discovery --namespace $NFD_NS --create-namespace --generate-name
```

### Ensure the Addon Is Working
```bash
(⎈|minikube:default)➜  ~ kubectl get no -o json | jq '.items[].metadata.labels'
{
  "beta.kubernetes.io/arch": "arm64",
  "beta.kubernetes.io/os": "linux",
  "feature.node.kubernetes.io/cpu-cpuid.AES": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ASIMD": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ASIMDDP": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ASIMDFHM": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ASIMDHP": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ASIMDRDM": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ATOMICS": "true",
  "feature.node.kubernetes.io/cpu-cpuid.CPUID": "true",
  "feature.node.kubernetes.io/cpu-cpuid.CRC32": "true",
  "feature.node.kubernetes.io/cpu-cpuid.DCPODP": "true",
  "feature.node.kubernetes.io/cpu-cpuid.DCPOP": "true",
  "feature.node.kubernetes.io/cpu-cpuid.DIT": "true",
  "feature.node.kubernetes.io/cpu-cpuid.EVTSTRM": "true",
  "feature.node.kubernetes.io/cpu-cpuid.FCMA": "true",
  "feature.node.kubernetes.io/cpu-cpuid.FLAGM": "true",
  "feature.node.kubernetes.io/cpu-cpuid.FLAGM2": "true",
  "feature.node.kubernetes.io/cpu-cpuid.FP": "true",
  "feature.node.kubernetes.io/cpu-cpuid.FPHP": "true",
  "feature.node.kubernetes.io/cpu-cpuid.FRINT": "true",
  "feature.node.kubernetes.io/cpu-cpuid.ILRCPC": "true",
  "feature.node.kubernetes.io/cpu-cpuid.JSCVT": "true",
  "feature.node.kubernetes.io/cpu-cpuid.LRCPC": "true",
  "feature.node.kubernetes.io/cpu-cpuid.PACA": "true",
  "feature.node.kubernetes.io/cpu-cpuid.PACG": "true",
  "feature.node.kubernetes.io/cpu-cpuid.PMULL": "true",
  "feature.node.kubernetes.io/cpu-cpuid.SB": "true",
  "feature.node.kubernetes.io/cpu-cpuid.SHA1": "true",
  "feature.node.kubernetes.io/cpu-cpuid.SHA2": "true",
  "feature.node.kubernetes.io/cpu-cpuid.SHA3": "true",
  "feature.node.kubernetes.io/cpu-cpuid.SHA512": "true",
  "feature.node.kubernetes.io/cpu-cpuid.USCAT": "true",
  "feature.node.kubernetes.io/cpu-hardware_multithreading": "false",
  "feature.node.kubernetes.io/cpu-model.family": "15",
  "feature.node.kubernetes.io/cpu-model.id": "0",
  "feature.node.kubernetes.io/cpu-model.vendor_id": "VendorUnknown",
  "feature.node.kubernetes.io/kernel-config.NO_HZ": "true",
  "feature.node.kubernetes.io/kernel-config.NO_HZ_IDLE": "true",
  "feature.node.kubernetes.io/kernel-version.full": "6.12.5-linuxkit",
  "feature.node.kubernetes.io/kernel-version.major": "6",
  "feature.node.kubernetes.io/kernel-version.minor": "12",
  "feature.node.kubernetes.io/kernel-version.revision": "5",
  "feature.node.kubernetes.io/memory-swap": "true",
  "feature.node.kubernetes.io/storage-nonrotationaldisk": "true",
  "feature.node.kubernetes.io/system-os_release.ID": "ubuntu",
  "feature.node.kubernetes.io/system-os_release.VERSION_ID": "22.04",
  "feature.node.kubernetes.io/system-os_release.VERSION_ID.major": "22",
  "feature.node.kubernetes.io/system-os_release.VERSION_ID.minor": "04",
  "kubernetes.io/arch": "arm64",
  "kubernetes.io/hostname": "minikube",
  "kubernetes.io/os": "linux",
  "minikube.k8s.io/commit": "f8f52f5de11fc6ad8244afac475e1d0f96841df1",
  "minikube.k8s.io/name": "minikube",
  "minikube.k8s.io/primary": "true",
  "minikube.k8s.io/updated_at": "2025_08_21T13_17_27_0700",
  "minikube.k8s.io/version": "v1.36.0",
  "node-role.kubernetes.io/control-plane": "",
  "node.kubernetes.io/exclude-from-external-load-balancers": ""
}
```

### Create a Custom Label
```bash
(⎈|minikube:default)➜  ~ minikube ssh
docker@minikube:~$ sudo su -
root@minikube:~$ cat <<EOF > /etc/kubernetes/node-feature-discovery/features.d/myfeature
vendor.io/myfeature=myvalue
EOF
```

Then to ensure the label exists, exit the SSH session and run:
```bash
(⎈|minikube:default)➜  ~ kubectl get no -o json | jq '.items[].metadata.labels["vendor.io/myfeature"]'
"myvalue"
```

## Steps For Testing With The Helm Chart
### Set Features To Detect
Set the `.Values.customScripts.features` list, according to the structure:
```yaml
- name: myfeature
  script: "echo 'vendor.io/myfeature=myvalue'"
  schedule: "@every 1s"
```

## Install the Helm Chart
```bash
helm install node-feature-discovery . --namespace node-feature-discovery --create-namespace
```

- Ensure that the node-feature-discovery-custom-scripts pod is created, view its logs and you should see the following:
```
2025-08-21T11:40:38.917Z  scheduler.go:44 ▶ NOTICE New job registered "myfeature" - "/ofelia/myfeature.sh" - "@every 1s"
2025-08-21T11:40:38.917Z  scheduler.go:55 ▶ DEBUG Starting scheduler with 1 jobs
2025-08-21T11:40:39.002Z  common.go:125 ▶ NOTICE [Job "myfeature" (c3c893aaa5cf)] Started - /ofelia/myfeature.sh
2025-08-21T11:40:39.005Z  common.go:125 ▶ NOTICE [Job "myfeature" (c3c893aaa5cf)] Finished in "2.717208ms", failed: false, skipped: false, error: none
```

- Ensure the label is created by running:
```bash
(⎈|minikube:default)➜  nfd kubectl get no -o json | jq '.items[].metadata.labels["vendor.io/myfeature"]'
"myvalue"
```

### Garbage Collection

The NFD deployment includes a garbage collection script that cleans up old feature labels and annotations. This helps prevent accumulation of stale metadata on nodes.

**Location**: `scripts/garbage-collector.sh`

**Usage**: The script runs automatically as part of the NFD deployment and removes:
- Expired feature labels
- Outdated annotations
- Stale node metadata

**Configuration**: Garbage collection behavior can be controlled via the Helm chart values under the `garbageCollector` section.

### Running Privileged Commands

To run privileged commands that require elevated permissions (like `iptables`), you need to ensure the custom scripts container has the necessary security context:

```yaml
# In your values.yaml or Helm command
customScripts:
  hostNetwork: true
  securityContext:
    privileged: true
```

**Note**: Running privileged commands requires careful consideration of security implications. Only enable this for trusted environments and necessary operations.
