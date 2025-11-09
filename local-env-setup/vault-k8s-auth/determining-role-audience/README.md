### Setting the Audience for a Vault Role (Kubernetes Auth)

When creating a Vault role for the Kubernetes auth method, you need to set an **audience**. During login, Vault verifies the Service Account (SA) token by comparing its audience with the role’s audience. If they match, the login proceeds.

To retrieve the audience for your Kubernetes cluster (this only needs to be done once per infrastructure setup):

```bash
kubectl apply -f pod-for-token.yaml
kubectl logs pod-for-token | jq '.aud'
kubectl delete -f pod-for-token.yaml
```

Use the returned value for the `audience` field when configuring your Vault role.
