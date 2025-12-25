# Custom Ofelia Image

This directory contains a custom Docker image that extends the [Ofelia](https://github.com/mcuadros/ofelia) job scheduler with additional tools.

## What This Image Adds

This custom image is based on `mcuadros/ofelia:0.3.18` and adds the following custom tools:

- **iptables**: Network packet filtering and NAT functionality for advanced networking operations

## Why This Image Exists

The base Ofelia image is a lightweight Alpine Linux container that doesn't include networking tools by default. This custom image ensures that scheduled jobs have access to `iptables` commands for network configuration and firewall management tasks.

## Building the Image

### Prerequisites

- Docker installed and running
- Access to pull the base `mcuadros/ofelia:0.3.18` image

### Build Command

From the `image/` directory, run:

```bash
TAG=$(awk '/^FROM/ { split($2,a,":"); print (a[2]?a[2]:"latest") }' Dockerfile)
docker build -t custom-ofelia:$TAG
```

If you want the image to be accessible by minikube, run:
```bash
TAG=$(awk '/^FROM/ { split($2,a,":"); print (a[2]?a[2]:"latest") }' Dockerfile)
minikube image build -t custom-ofelia:$TAG .
```
