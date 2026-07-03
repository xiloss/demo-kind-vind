#!/usr/bin/env bash
set -uo pipefail

namespace="${NAMESPACE:?Error: NAMESPACE environment variable required. Example: NAMESPACE=kind-zero-to-cluster-cilium ./scripts/demo-access.sh}"

cleanup() {
  printf '\nStopping demo access.\n'
  exit 0
}

trap cleanup INT TERM

printf 'Starting persistent port-forward to webapp service in namespace: %s\n' "$namespace"
printf 'Access the demo app at: http://localhost:8080\n'
printf '(Auto-reconnects when pods are killed)\n\n'

while true; do
  kubectl port-forward -n "$namespace" svc/webapp 8080:8080 2>&1 | while IFS= read -r line; do
    case "$line" in
      *error*|*Error*|*refused*|*closed*)
        printf '[%s] %s\n' "$(date +%H:%M:%S)" "$line"
        ;;
      *Forwarding*)
        printf '[%s] %s\n' "$(date +%H:%M:%S)" "$line"
        ;;
    esac
  done

  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    printf '[%s] Connection lost. Waiting for new pod to be ready...\n' "$(date +%H:%M:%S)"

    # Wait for at least one ready pod before reconnecting
    while true; do
      ready=$(kubectl get deployment webapp -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      if [ "$ready" -gt 0 ] 2>/dev/null; then
        printf '[%s] Pod ready. Reconnecting...\n' "$(date +%H:%M:%S)"
        break
      fi
      sleep 2
    done
  else
    printf '[%s] Port-forward stopped. Reconnecting...\n' "$(date +%H:%M:%S)"
    sleep 2
  fi
done
