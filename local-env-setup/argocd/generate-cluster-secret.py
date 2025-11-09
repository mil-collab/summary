import json

import argparse
import yaml
import subprocess

class LiteralString(str):
    pass

def literal_str_representer(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cluster-name", help="KIND cluster name to generate a secret for", required=True)
    parser.add_argument("--argocd-namespace", help="destination namespace on the ArgoCD cluster for the cluster secret", required=True)
    return parser.parse_args()

def get_kind_cluster_kubeconfig(cluster_name: str) -> dict:
    kubeconfig = subprocess.run([
        "kind",
        "get",
        "kubeconfig",
        "-n",
        cluster_name
    ], capture_output=True)
    return yaml.safe_load(kubeconfig.stdout)

def generate_cluster_secret_manifest(cluster_name: str, namespace: str) -> dict:
    kubeconfig = get_kind_cluster_kubeconfig(cluster_name)
    return {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": cluster_name,
            "namespace": namespace,
            "labels": {
                "argocd.argoproj.io/secret-type": "cluster"
            }
        },
        "type": "Opaque",
        "stringData": {
            "name": cluster_name,
            "server": f"https://{cluster_name}-control-plane:6443",
            "config": LiteralString(json.dumps({
                "tlsClientConfig": {
                    "caData": kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"],
                    "certData": kubeconfig["users"][0]["user"]["client-certificate-data"],
                    "keyData": kubeconfig["users"][0]["user"]["client-key-data"]
                }
            }, indent=2))
        }
    }

def main():
    args = parse_args()
    yaml.add_representer(LiteralString, literal_str_representer, Dumper=yaml.SafeDumper)
    print(yaml.safe_dump(generate_cluster_secret_manifest(args.cluster_name, args.argocd_namespace)))

if __name__ == "__main__":
    main()