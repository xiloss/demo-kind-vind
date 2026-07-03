#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <namespace>

Force delete all Terminating pods in the specified namespace and kube-system.

Arguments:
  namespace    The Kubernetes namespace to clean up

Examples:
  $0 kind-zero-to-cluster-cilium
  \$NAMESPACE   Use the NAMESPACE environment variable
EOF
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
fi

namespace="${1:-${NAMESPACE:-}}"

if [ -z "$namespace" ]; then
  printf 'Error: namespace argument or NAMESPACE environment variable required.\n'
  usage
  exit 1
fi

printf 'Force cleaning up stuck pods in namespace: %s\n' "$namespace"

# Force delete Terminating pods in the specified namespace
terminating_ns=$(kubectl get pods -n "$namespace" 2>/dev/null | grep Terminating | awk '{print $1}' || true)
if [ -n "$terminating_ns" ]; then
  printf 'Found Terminating pods in %s:\n' "$namespace"
  echo "$terminating_ns"
  echo "$terminating_ns" | xargs -r kubectl delete pod -n "$namespace" --grace-period=0 --force 2>/dev/null || true
else
  printf 'No Terminating pods in %s\n' "$namespace"
fi

# Force delete Terminating pods in kube-system (for Cilium operator, etc.)
terminating_sys=$(kubectl get pods -n kube-system 2>/dev/null | grep Terminating | awk '{print $1}' || true)
if [ -n "$terminating_sys" ]; then
  printf '\nFound Terminating pods in kube-system:\n'
  echo "$terminating_sys"
  echo "$terminating_sys" | xargs -r kubectl delete pod -n kube-system --grace-period=0 --force 2>/dev/null || true
else
  printf '\nNo Terminating pods in kube-system\n'
fi

printf '\nDone. Current pods in %s:\n' "$namespace"
kubectl get pods -n "$namespace" -o wide 2>/dev/null || printf 'Namespace not found or empty\n'
