#!/usr/bin/env bash
set -euo pipefail

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait \
  --set controller.service.type=LoadBalancer \
  --set-string 'controller.service.annotations.service\.beta\.kubernetes\.io/oci-load-balancer-shape=flexible' \
  --set-string 'controller.service.annotations.service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-min=10' \
  --set-string 'controller.service.annotations.service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-max=10'
