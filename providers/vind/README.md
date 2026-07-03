# vind Provider

This is the preferred path for the talk when the goal is to emphasise fast, local
Kubernetes experimentation and vCluster ecosystem alignment.

**vind = vCluster in Docker** — the vCluster CLI (v0.35.0+) with the Docker
driver. There is no separate `vind` binary. You install `vcluster` and run
`vcluster use driver docker`.

## Cluster Naming

Clusters are named using the convention: `vind-zero-to-cluster-{cni}`

| CNI | Cluster Name | Namespace |
|-----|--------------|-----------|
| flannel | `vind-zero-to-cluster-flannel` | `vind-zero-to-cluster-flannel` |
| cilium | `vind-zero-to-cluster-cilium` | `vind-zero-to-cluster-cilium` |
| cilium-kpr | `vind-zero-to-cluster-ciliumkpr` | `vind-zero-to-cluster-ciliumkpr` |
| calico | `vind-zero-to-cluster-calico` | `vind-zero-to-cluster-calico` |

## Linux Prerequisites

On Linux, validate the host before creating a cluster.

1. Confirm cgroup v2 is active:

```bash
docker info | grep -i cgroup
stat -fc %T /sys/fs/cgroup/
```

Modern `vind` expects cgroup v2 behavior. If the host is cgroup v1 only, the control plane or node components may fail.

2. Load the bridge netfilter module:

```bash
sudo modprobe br_netfilter
lsmod | grep br_netfilter
```

To make this persistent:

```bash
printf 'br_netfilter\n' | sudo tee /etc/modules-load.d/vcluster.conf
```

3. Enable the required sysctl settings:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/vcluster.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
EOF

sudo sysctl --system
```

These values are needed because local Kubernetes networking depends on bridge traffic visibility and IP forwarding. Without them, pod networking, service routing, and node join flows can behave unexpectedly on Linux hosts such as Ubuntu 22.

**Important: `fs.inotify` limits for multi-node vind**

The default Linux inotify limits (`max_user_instances=128`, `max_user_watches=65536`) are too low for multi-node vind clusters. Each vind node container runs its own kubelet, containerd, CNI agents, and etcd/kine, all of which create inotify watchers. With 4 nodes (1 control-plane + 3 workers), the default limits are quickly exhausted, causing `failed to create fsnotify watcher: too many open files` errors that prevent nodes from starting.

```bash
# Check current limits
sysctl fs.inotify.max_user_instances
sysctl fs.inotify.max_user_watches

# Raise limits (persistent via /etc/sysctl.d/)
sudo sysctl fs.inotify.max_user_instances=1024
sudo sysctl fs.inotify.max_user_watches=524288
```

## Prerequisites

- Docker (or Docker Desktop) running and reachable.
- `vcluster` CLI v0.35.0 or later (required for Docker driver and multi-node support).
- Linux host prepared with cgroup v2, `br_netfilter`, and the sysctl settings above.

Validation:

```bash
vcluster version
kubectl version --client
docker info | grep -i cgroup
cat /proc/sys/net/bridge/bridge-nf-call-iptables
cat /proc/sys/net/ipv4/ip_forward
```

## Single-Node vs Multi-Node

**Single-node** (default): 1 control-plane node only.

**Multi-node** (`--multi-node`): 1 control-plane + 3 workers (4 nodes total).

```bash
# Single-node
./scripts/create-cluster.sh vind

# Multi-node
./scripts/create-cluster.sh vind --multi-node
```

## Create

```bash
# Single-node with flannel
./scripts/create-cluster.sh vind

# Multi-node with Cilium
./scripts/create-cluster.sh vind --multi-node --cni cilium

# Multi-node with Cilium kube-proxy replacement
./scripts/create-cluster.sh vind --multi-node --cni cilium-kpr

# Multi-node with Calico
./scripts/create-cluster.sh vind --multi-node --cni calico
```

## Deploy App

```bash
# Set namespace to match cluster name
export NAMESPACE=vind-zero-to-cluster-cilium

# Deploy
./scripts/deploy-app.sh
```

## CNI Options

| CNI | Description |
|-----|-------------|
| `flannel` | Default vind networking (built-in) |
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

The vind configs are configured with fast eviction settings for demo purposes:

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

**WARNING:** These settings are NOT suitable for production clusters. See the
config files for detailed explanations of why fast toleration is dangerous
in production environments.

## Verify The Layout

```bash
kubectl get nodes -o wide
```

Expected shape (multi-node):

```text
<vind-name>   Ready   control-plane
worker-1      Ready   <none>
worker-2      Ready   <none>
worker-3      Ready   <none>
```

## Multi-Node Failure Demo

vind supports multiple nodes via vcluster's Docker driver:

```bash
# Show the Docker containers backing the cluster
docker ps --filter name=vcluster

# Stop worker containers shown by docker ps
docker stop <worker-container-1>
docker stop <worker-container-2>

# Watch node status
kubectl get nodes -w

# Watch pod eviction (~30s with fast config)
kubectl get pods -n <namespace> -o wide -w
```

## Force Cleanup (Stuck Pods)

If pods get stuck in Terminating state during the demo:

```bash
# Using demo-flow.sh
NAMESPACE=vind-zero-to-cluster-cilium ./scripts/demo-flow.sh --force-cleanup

# Or standalone script
./scripts/force-cleanup.sh vind-zero-to-cluster-cilium

# Or manually
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

## Cleanup

```bash
# Clean up by provider and CNI
./scripts/cleanup.sh vind flannel
./scripts/cleanup.sh vind cilium
./scripts/cleanup.sh vind cilium-kpr
./scripts/cleanup.sh vind calico
```

## Notes

- If pod sandbox creation fails with `cpu.weight`, validate cgroup mode. That
  error usually indicates a cgroup v2 expectation running on a cgroup v1 host.
- The `values.yaml` in this directory keeps the virtual cluster lean. Add sync
  settings and policies as needed for richer demos.
