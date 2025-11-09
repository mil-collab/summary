#!/bin/bash
set -e
#
# Get the Ingress Controller local IP address
ccm_container_id=""
while [[ -z "$ccm_container_id" ]]; do
    ccm_container_id="$(docker ps --format json | jq -r 'select(.Names | test("kindccm-.*")) | .Names')"
done

ccm_ip_address="$(docker inspect "$ccm_container_id" | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')"
echo "$ccm_ip_address rancher.cowman.local"
