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
    parser.add_argument("--repository-name", help="Git repository same for the secret", required=True)
    parser.add_argument("--repository-url", help="Git repository SSH clone URL", required=True)
    parser.add_argument("--ssh-private-key", help="SSH private key file that can access the repository", required=True)
    parser.add_argument("--argocd-namespace", help="destination namespace on the ArgoCD cluster for the repository secret", required=True)
    return parser.parse_args()

def generate_repository_secret(repository_name: str, namespace: str, repository_url: str, ssh_private_key: str) -> dict:
    with open(ssh_private_key, "r") as f:
        key = f.read()

    return {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": repository_name,
            "namespace": namespace,
            "labels": {
                "argocd.argoproj.io/secret-type": "repository"
            }
        },
        "type": "Opaque",
        "stringData": {
            "type": "git",
            "url": repository_url,
            "sshPrivateKey": LiteralString(key)
        }
    }

def main():
    args = parse_args()
    yaml.add_representer(LiteralString, literal_str_representer, Dumper=yaml.SafeDumper)
    print(yaml.safe_dump(generate_repository_secret(args.repository_name, args.argocd_namespace, args.repository_url, args.ssh_private_key)))

if __name__ == "__main__":
    main()