#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:?Error: NAMESPACE environment variable required. Example: NAMESPACE=kind-zero-to-cluster-cilium ./scripts/demo-flow.sh}"
force_cleanup="${1:-}"

# If --force-cleanup argument provided, just force delete and exit
if [ "$force_cleanup" = "--force-cleanup" ]; then
  printf 'Force cleaning up stuck pods in %s\n' "$namespace"

  terminating_ns=$(kubectl get pods -n "$namespace" 2>/dev/null | grep Terminating | awk '{print $1}' || true)
  if [ -n "$terminating_ns" ]; then
    printf 'Found Terminating pods in %s:\n' "$namespace"
    echo "$terminating_ns"
    echo "$terminating_ns" | xargs -r kubectl delete pod -n "$namespace" --grace-period=0 --force 2>/dev/null || true
  else
    printf 'No Terminating pods in %s\n' "$namespace"
  fi

  terminating_sys=$(kubectl get pods -n kube-system 2>/dev/null | grep Terminating | awk '{print $1}' || true)
  if [ -n "$terminating_sys" ]; then
    printf '\nFound Terminating pods in kube-system:\n'
    echo "$terminating_sys"
    echo "$terminating_sys" | xargs -r kubectl delete pod -n kube-system --grace-period=0 --force 2>/dev/null || true
  else
    printf '\nNo Terminating pods in kube-system\n'
  fi

  printf '\nDone. Current pods in %s:\n' "$namespace"
  kubectl get pods -n "$namespace" -o wide
  exit 0
fi

# Normal demo flow
printf '\n==> Current context\n'
kubectl config current-context

printf '\n==> Nodes\n'
kubectl get nodes -o wide

printf '\n==> Docker containers behind the local lab, if Docker is available\n'
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
else
  printf 'Docker is not reachable from this shell.\n'
fi

printf '\n==> System pods\n'
kubectl get pods -A

printf '\n==> Demo workload\n'
kubectl get deploy,svc,pods -n "$namespace" -o wide

# Check if app is deployed
webapp_ready=$(kubectl get deployment webapp -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$webapp_ready" = "0" ] || [ -z "$webapp_ready" ]; then
  printf '\nApp not deployed yet. Run:\n'
  printf '  NAMESPACE=%s ./scripts/deploy-app.sh\n' "$namespace"
  printf '\nSkipping app-specific checks.\n'
  printf '\nTo watch recovery in real time:\n'
  printf '  kubectl get pods -n %s -o wide -w\n' "$namespace"
  exit 0
fi

printf '\n==> Web app status\n'
webapp_pods=$(kubectl get pods -n "$namespace" -l app=webapp -o jsonpath='{range .items[*]}{.metadata.name}{" on "}{.spec.nodeName}{" ("}{.status.phase}{")\n"}{end}')
printf '%s' "$webapp_pods"

printf '\n==> Visit counter (via webapp API)\n'
webapp_pod=$(kubectl get pod -n "$namespace" -l app=webapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$webapp_pod" ]; then
  kubectl exec -n "$namespace" "$webapp_pod" -- python -c "import urllib.request, json; resp = urllib.request.urlopen('http://localhost:8080/api/visits'); data = json.loads(resp.read()); print(f'  Visits: {data[\"visits\"]}'); print(f'  Cluster: {data[\"cluster\"]}'); print(f'  Node: {data[\"node\"]}'); print(f'  Pod: {data[\"pod\"]}')" 2>/dev/null || printf '  Could not reach webapp API\n'
else
  printf '  Webapp pod not found\n'
fi

printf '\n==> Database content (messages table)\n'
mysql_pod=$(kubectl get pod -n "$namespace" -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$mysql_pod" ]; then
  kubectl exec -n "$namespace" "$mysql_pod" -- mysql -u kcd -pkcd2026 kcd -e "SELECT author, message, DATE_FORMAT(created_at, '%H:%i:%s') as time FROM messages ORDER BY id DESC LIMIT 5;" 2>/dev/null || printf 'Could not query database\n'
else
  printf 'MySQL pod not found\n'
fi

printf '\n==> Visit history (last 5)\n'
if [ -n "$mysql_pod" ]; then
  kubectl exec -n "$namespace" "$mysql_pod" -- mysql -u kcd -pkcd2026 kcd -e "SELECT node_name, pod_name, DATE_FORMAT(timestamp, '%H:%i:%s') as time FROM visits ORDER BY id DESC LIMIT 5;" 2>/dev/null || printf 'Could not query visits\n'
fi

printf '\n==> Self-healing demo (deleting a webapp pod)\n'
pod_name=$(kubectl get pod -n "$namespace" -l app=webapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$pod_name" ]; then
  printf 'Deleting pod: %s\n' "$pod_name"
  kubectl delete pod -n "$namespace" "$pod_name"
  printf 'Waiting 5 seconds for Kubernetes to reconcile...\n'
  sleep 5
  kubectl get pods -n "$namespace" -l app=webapp -o wide
else
  printf 'Webapp pod not found\n'
fi

printf '\n==> Stuck pods check\n'
terminating=$(kubectl get pods -n "$namespace" 2>/dev/null | grep -c Terminating || true)
terminating=$(echo "$terminating" | tr -d '[:space:]')
if [ -z "$terminating" ]; then
  terminating=0
fi
if [ "$terminating" -gt 0 ]; then
  printf 'WARNING: %s pod(s) stuck in Terminating state.\n' "$terminating"
  printf 'To force cleanup, run:\n'
  printf '  NAMESPACE=%s ./scripts/demo-flow.sh --force-cleanup\n' "$namespace"
  printf '\nOr use the standalone script:\n'
  printf '  ./scripts/force-cleanup.sh %s\n' "$namespace"
fi

printf '\nTo watch recovery in real time:\n'
printf '  kubectl get pods -n %s -o wide -w\n' "$namespace"

printf '\nTo access the demo app (auto-reconnects on pod kill):\n'
printf '  NAMESPACE=%s ./scripts/demo-access.sh\n' "$namespace"
printf '  http://localhost:8080\n'
