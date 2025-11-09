# summary
Summing things up to make my crewmates' lives easier &lt;3

## Folders

### cluster-crd
Contains a chart that installs a CRD that overrides the configuration of a cluster.
Needs to be installed on `local` cluster.

### cluster-nodes-chart
A chart of `xMachines` (crossplane custom CRD) - nodes of a cluster.

### design
Contains an image and excalidraw graph.

### example
A vision of how a cluster config file should look like, and how SRE's `ApplicationSet` looks like.

### kyverno-requirements
RBAC for kyverno (needs to be installed on a cluster so every usage of kyverno will work.

### local-env-setup
Everything we did to mimic the rancher + argo environment online. Added in case it will be handy.

### node-taints
A chart that gives nodes taints based on their names (matches a role).

### vault
Everything related to the vault K8s authentication.

