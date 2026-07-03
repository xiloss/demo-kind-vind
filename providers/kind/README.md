# kind Provider

This provider creates a local Kubernetes cluster using Docker containers.

## Cluster Naming

Clusters are named using the convention: `kind-zero-to-cluster-{cni}`

| CNI | Cluster Name | Namespace |
|-----|--------------|-----------|
| flannel | `kind-zero-to-cluster-flannel` | `kind-zero-to-cluster-flannel` |
| cilium | `kind-zero-to-cluster-cilium` | `kind-zero-to-cluster-cilium` |
| cilium-kpr | `kind-zero-to-cluster-ciliumkpr` | `kind-zero-to-cluster-ciliumkpr` |
| calico | `kind-zero-to-cluster-calico` | `kind-zero-to-cluster-calico` |

## Single-Node vs Multi-Node

**Single-node** (default): 1 control-plane node only.

**Multi-node** (`--multi-node`): 1 control-plane + 3 workers (4 nodes total).

```bash
# Single-node
./scripts/create-cluster.sh kind

# Multi-node
./scripts/create-cluster.sh kind --multi-node
```

## Create

```bash
# Single-node with flannel
./scripts/create-cluster.sh kind

# Multi-node with Cilium
./scripts/create-cluster.sh kind --multi-node --cni cilium

# Multi-node with Cilium kube-proxy replacement
./scripts/create-cluster.sh kind --multi-node --cni cilium-kpr

# Multi-node with Calico
./scripts/create-cluster.sh kind --multi-node --cni calico
```

## Deploy App

```bash
# Set namespace to match cluster name
export NAMESPACE=kind-zero-to-cluster-cilium

# Deploy
./scripts/deploy-app.sh
```

## CNI Options

| CNI | Description |
|-----|-------------|
| `flannel` | Default kind networking (built-in) |
| `cilium` | Cilium CNI with Hubble observability |
| `cilium-kpr` | Cilium with kube-proxy replacement + Hubble |
| `calico` | Calico CNI |

### Hubble UI (Cilium Observability)

When using Cilium (`--cni cilium` or `--cni cilium-kpr`), Hubble is automatically
installed with the UI enabled. To access the Hubble UI:

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

Then open http://localhost:12000 in your browser.

## Fast Node Failure Detection

The kind templates are configured with fast eviction settings for demo purposes:

| Parameter | Production | Demo |
|-----------|------------|------|
| `node-monitor-grace-period` | 40s | 10s |
| `node-monitor-period` | 5s | 2s |
| `node-status-update-frequency` (kubelet) | 10s | 4s |

**Note:** `--pod-eviction-timeout`, `--default-not-ready-toleration-seconds`, and
`--default-unreachable-toleration-seconds` were **removed in Kubernetes 1.32**
and can no longer be tuned. Fast eviction now relies on
`node-monitor-grace-period` only; pods still use the default 300s toleration
seconds. This means actual pod eviction takes longer than the ~30s target
unless you also set `terminationGracePeriodSeconds` on your workloads.

**fs.inotify limits:** The default Linux `fs.inotify.max_user_instances=128`
can be hit when running kind with Cilium kube-proxy replacement (`cilium-kpr`),
because Cilium's operator, Hubble relay, and other agents create many inotify
watchers. However, kind typically stays under the limit because it does **not**
deploy a kube-proxy DaemonSet when Cilium replaces it (the script deletes it
after Cilium is ready). Multi-node vind clusters are more likely to hit this
limit since each worker node runs its own full kubelet + containerd stack.
If you see `failed to create fsnotify watcher: too many open files`, raise the
limits:

```bash
sudo sysctl fs.inotify.max_user_instances=1024 fs.inotify.max_user_watches=524288
```

Make it persistent:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-inotify.conf
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
EOF
sudo sysctl --system
```

**WARNING:** These settings are NOT suitable for production clusters. See the
template files for detailed explanations of why fast toleration is dangerous
in production environments.

## Verify The Layout

```bash
kubectl get nodes -o wide
docker ps --filter name=kind-zero-to-cluster
```

This is useful for showing:

- scheduler decisions across nodes (multi-node)
- pod deletion and reconciliation
- node failure and node recovery (multi-node)
- multi-node topology awareness in a local lab

## Failure Demo (Multi-Node Only)

Stop worker containers:

```bash
# Get the cluster name from kubectl context
CLUSTER_NAME=$(kubectl config current-context | sed 's/kind-//')

# Stop 2 workers
docker stop ${CLUSTER_NAME}-worker2
docker stop ${CLUSTER_NAME}-worker3

# Watch node status
kubectl get nodes -w

# Watch pod eviction (~30s with fast config)
kubectl get pods -n ${CLUSTER_NAME} -o wide -w
```

Restart workers:

```bash
docker start ${CLUSTER_NAME}-worker2
docker start ${CLUSTER_NAME}-worker3
kubectl get nodes
```

## Force Cleanup (Stuck Pods)

If pods get stuck in Terminating state during the demo:

```bash
# Using demo-flow.sh
NAMESPACE=kind-zero-to-cluster-cilium ./scripts/demo-flow.sh --force-cleanup

# Or standalone script
./scripts/force-cleanup.sh kind-zero-to-cluster-cilium

# Or manually
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

## Cleanup

```bash
# Clean up by provider and CNI
./scripts/cleanup.sh kind flannel
./scripts/cleanup.sh kind cilium
./scripts/cleanup.sh kind cilium-kpr
./scripts/cleanup.sh kind calico
```
