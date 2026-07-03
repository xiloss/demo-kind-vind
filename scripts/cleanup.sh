#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <provider> <cni>

Providers:
  kind            Delete a kind cluster
  vind            Delete a vCluster cluster and namespace

CNIs:
  flannel         Default CNI
  cilium          Cilium CNI
  cilium-kpr      Cilium with kube-proxy replacement
  calico          Calico CNI

Options:
  -h, --help      Show this help message

Examples:
  $0 kind flannel
  $0 kind cilium
  $0 kind cilium-kpr
  $0 kind calico
  $0 vind flannel
  $0 vind cilium
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

provider="${1:-}"
cni="${2:-}"

if [ -z "$provider" ]; then
  printf 'Error: provider argument required.\n'
  usage
  exit 1
fi

if [ -z "$cni" ]; then
  printf 'Error: cni argument required.\n'
  usage
  exit 1
fi

# Validate CNI
case "$cni" in
  flannel|cilium|cilium-kpr|calico) ;;
  *)
    printf 'Unknown CNI: %s\n' "$cni"
    printf 'Supported: flannel, cilium, cilium-kpr, calico\n'
    exit 1
    ;;
esac

# Construct cluster name and namespace
if [ "$cni" = "cilium-kpr" ]; then
  cni_suffix="ciliumkpr"
else
  cni_suffix="$cni"
fi
cluster_name="${provider}-zero-to-cluster-${cni_suffix}"
namespace="$cluster_name"

printf 'Cleaning up cluster: %s\n' "$cluster_name"
printf 'Namespace: %s\n' "$namespace"

case "$provider" in
  kind)
    command -v kind >/dev/null 2>&1 || { printf 'kind is required.\n'; exit 1; }
    printf 'Deleting kind cluster: %s\n' "$cluster_name"
    kind delete cluster --name "$cluster_name" || true
    ;;
  vind)
    if command -v vcluster >/dev/null 2>&1; then
      printf 'Deleting vcluster: %s\n' "$cluster_name"
      vcluster delete "$cluster_name" --namespace "$namespace" || true
    else
      printf 'vcluster CLI not found. Skipping vcluster delete.\n'
    fi
    kubectl delete namespace "$namespace" --ignore-not-found=true || true
    ;;
  *)
    printf 'Unknown provider: %s\n' "$provider"
    usage
    exit 1
    ;;
esac

printf '\nCleanup complete: %s\n' "$cluster_name"
