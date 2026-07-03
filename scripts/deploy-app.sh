#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:?Error: NAMESPACE environment variable required. Example: NAMESPACE=kind-zero-to-cluster-cilium ./scripts/deploy-app.sh}"

printf 'Deploying KCD Lima 2026 demo app to namespace: %s\n' "$namespace"

# Generate namespace from template
printf 'Creating namespace: %s\n' "$namespace"
sed "s/__NAMESPACE__/$namespace/g" manifests/namespace.yaml.tmpl | kubectl apply -f -

# Generate app manifests from template
printf 'Deploying application\n'
sed "s/__NAMESPACE__/$namespace/g" manifests/app.yaml.tmpl | kubectl apply -f -

printf 'Waiting for MySQL to be ready\n'
kubectl rollout status deployment/mysql -n "$namespace" --timeout=180s

printf 'Waiting for webapp to be ready\n'
kubectl rollout status deployment/webapp -n "$namespace" --timeout=120s

printf '\nDeployed resources:\n'
kubectl get pods,svc -n "$namespace" -o wide

printf '\nAccess the KCD Lima 2026 demo app:\n'
printf '  NAMESPACE=%s ./scripts/demo-access.sh\n' "$namespace"
printf '  http://localhost:8080\n'
printf '\n(Auto-reconnects when pods are killed — no need to restart port-forward)\n'
