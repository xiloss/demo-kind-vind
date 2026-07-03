# From Zero to Cluster Demo

Reusable demo repository for the talk **From Zero to Cluster**.

This repository is designed to support two local Kubernetes paths:

- `vind`: preferred path for vCluster Ambassador-oriented demos.
- `kind`: reproducible fallback for local multi-node Kubernetes.

## Cluster Naming Convention

Clusters are named using the convention: `{provider}-zero-to-cluster-{cni}`

| Provider | CNI | Cluster Name | Namespace |
|----------|-----|--------------|-----------|
| kind | flannel | `kind-zero-to-cluster-flannel` | `kind-zero-to-cluster-flannel` |
| kind | cilium | `kind-zero-to-cluster-cilium` | `kind-zero-to-cluster-cilium` |
| kind | cilium-kpr | `kind-zero-to-cluster-ciliumkpr` | `kind-zero-to-cluster-ciliumkpr` |
| kind | calico | `kind-zero-to-cluster-calico` | `kind-zero-to-cluster-calico` |
| vind | flannel | `vind-zero-to-cluster-flannel` | `vind-zero-to-cluster-flannel` |
| vind | cilium | `vind-zero-to-cluster-cilium` | `vind-zero-to-cluster-cilium` |
| vind | cilium-kpr | `vind-zero-to-cluster-ciliumkpr` | `vind-zero-to-cluster-ciliumkpr` |
| vind | calico | `vind-zero-to-cluster-calico` | `vind-zero-to-cluster-calico` |

## Quick Start

### With scripts directly

Create a cluster:

```bash
# Single-node kind with flannel
./scripts/create-cluster.sh kind

# Multi-node kind with Cilium
./scripts/create-cluster.sh kind --multi-node --cni cilium

# Multi-node vind with Cilium
./scripts/create-cluster.sh vind --multi-node --cni cilium
```

Deploy the app (namespace must match cluster name):

```bash
export NAMESPACE=kind-zero-to-cluster-cilium
./scripts/deploy-app.sh
```

Run the demo:

```bash
./scripts/demo-flow.sh
```

If pods get stuck in Terminating state:

```bash
./scripts/demo-flow.sh --force-cleanup
```

Clean up:

```bash
./scripts/cleanup.sh kind cilium
```

Show all options:

```bash
./scripts/create-cluster.sh --help
./scripts/cleanup.sh --help
```

### With make

```bash
make install                          # see prerequisites & install guides
make check                            # validate environment
make create PROVIDER=kind             # create cluster (kind/vind)
make deploy                           # deploy the demo app
make demo                             # guided demo flow
make cleanup PROVIDER=kind            # tear down
make all                              # full workflow: check → create → deploy → demo
```

### With Task

```bash
task install                          # see prerequisites & install guides
task check                            # validate environment
task create PROVIDER=kind             # create cluster (kind/vind)
task deploy                           # deploy the demo app
task demo                             # guided demo flow
task cleanup PROVIDER=kind            # tear down
task all                              # full workflow: check → create → deploy → demo
```

## Create Options

### Kind

```bash
# Single-node (1 control-plane)
./scripts/create-cluster.sh kind

# Multi-node (1 control-plane + 3 workers)
./scripts/create-cluster.sh kind --multi-node

# With CNI options
./scripts/create-cluster.sh kind --multi-node --cni flannel
./scripts/create-cluster.sh kind --multi-node --cni cilium
./scripts/create-cluster.sh kind --multi-node --cni cilium-kpr
./scripts/create-cluster.sh kind --multi-node --cni calico
```

### Vind

```bash
# Single-node
./scripts/create-cluster.sh vind

# Multi-node (1 control-plane + 3 workers)
./scripts/create-cluster.sh vind --multi-node

# With CNI options
./scripts/create-cluster.sh vind --multi-node --cni flannel
./scripts/create-cluster.sh vind --multi-node --cni cilium
./scripts/create-cluster.sh vind --multi-node --cni cilium-kpr
  ./scripts/create-cluster.sh vind --multi-node --cni calico
```

## Demo Application

The demo deploys a **KCD Lima 2026 "From Zero to Cluster" visitor counter** — a
multi-tier web application:

- **MySQL 8.0**: Database backend with pre-seeded messages and visit tracking
- **Webapp (Python/Flask)**: Live visitor counter showing cluster info, node name,
  pod name, and a self-healing demo button

### Access the Web App

After deploying, access the visitor counter with the auto-reconnect script:

```bash
export NAMESPACE=kind-zero-to-cluster-cilium
./scripts/demo-access.sh
```

Open http://localhost:8080 to see:
- Live visit counter
- Which node is serving the request
- Cluster and pod information
- Recent messages from the database
- A "Kill This Pod" button for the self-healing demo

The port-forward auto-reconnects when pods are killed — no need to restart it.

### Demo Flow

The demo script (`scripts/demo-flow.sh`) shows:
1. Current context and nodes
2. Docker containers backing the cluster
3. System pods
4. Deployed workload (webapp + MySQL)
5. Visit counter via webapp API
6. Database content (messages table)
7. Pod deletion and self-healing reconciliation
8. Force cleanup option for stuck pods

## Fast Node Failure Detection

The kind templates and vind configs are configured with fast eviction settings
for demo purposes (~30s total detection + eviction time).

**WARNING:** These settings are NOT suitable for production clusters. See the
template files for detailed explanations of why fast toleration is dangerous
in production environments.

## Cleanup

```bash
# Clean up by provider and CNI
./scripts/cleanup.sh kind flannel
./scripts/cleanup.sh kind cilium
./scripts/cleanup.sh kind cilium-kpr
./scripts/cleanup.sh kind calico
./scripts/cleanup.sh vind flannel
./scripts/cleanup.sh vind cilium
./scripts/cleanup.sh vind cilium-kpr
  ./scripts/cleanup.sh vind calico
```

## Installation

### Docker

| Platform  | Command |
|-----------|---------|
| Linux     | `sudo apt install docker.io` (Debian/Ubuntu) |
|           | `sudo dnf install docker` (Fedora) |
|           | `sudo pacman -S docker` (Arch) |
| macOS     | `brew install --cask docker` |
| Windows   | `winget install Docker.DockerDesktop` |
| **Docs**  | https://docs.docker.com/engine/install/ |

### kubectl

| Platform  | Command |
|-----------|---------|
| Linux     | `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"` |
|           | `sudo install -m 0755 kubectl /usr/local/bin/kubectl` |
| macOS     | `brew install kubernetes-cli` |
| Windows   | `winget install Kubernetes.kubectl` |
| **Docs**  | https://kubernetes.io/docs/tasks/tools/ |

### kind (for kind provider)

| Platform  | Command |
|-----------|---------|
| Linux     | `curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-amd64` |
|           | `chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind` |
| macOS     | `brew install kind` |
| Windows   | `winget install Kubernetes.kind` |
| **Docs**  | https://kind.sigs.k8s.io/docs/user/quick-start/#installation |

### vcluster / vind (for vind provider)

**vind = vCluster CLI (v0.35.0+) with Docker driver. No separate binary.**

| Platform  | Command |
|-----------|---------|
| Linux     | `curl -sSL https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64 -o /tmp/vcluster` |
|           | `sudo install -m 0755 /tmp/vcluster /usr/local/bin/vcluster` |
| macOS     | `brew install vcluster` |
| Windows   | `winget install LoftLabs.vcluster` |

After install, enable the Docker driver once:

```bash
vcluster use driver docker
```

| **Docs**  | https://github.com/loft-sh/vind |

## Provider Choices

### vind

Use this when the goal is to emphasize fast, local Kubernetes experimentation and vCluster ecosystem alignment.

**vind = vCluster CLI (v0.35.0+) with Docker driver.** Install `vcluster` and run
`vcluster use driver docker`. No separate binary.

See `providers/vind/README.md`.

### kind

Use this when the goal is repeatability across Linux/macOS machines with Docker.

See `providers/kind/README.md`.

## Demo Story

1. Create a local cluster.
2. Show Kubernetes nodes.
3. Show the runtime reality with Docker.
4. Deploy the KCD Lima 2026 visitor counter app (webapp + MySQL).
5. Observe scheduling across nodes and service discovery.
6. Show the live visitor counter and database content.
7. Delete a pod and watch self-healing reconciliation.
8. Disrupt a node where the provider supports it.
9. Discuss networking, storage, and ingress as the real production decisions.

## Requirements

- Docker or Docker Desktop.
- `kubectl`.
- One provider: `kind` or `vcluster` (v0.35.0+, for vind).
- On Linux, validate the host environment before running the demo.

### Linux prerequisites for local Kubernetes labs

On Ubuntu and other Linux hosts, local multi-node Kubernetes depends on cgroup behavior, bridge networking, and inotify limits. Before creating a cluster:

1. Confirm cgroup v2 is active.

```bash
docker info | grep -i cgroup
stat -fc %T /sys/fs/cgroup/
```

2. Load the bridge netfilter module.

```bash
sudo modprobe br_netfilter
printf 'br_netfilter\n' | sudo tee /etc/modules-load.d/vcluster.conf
```

3. Enable the required sysctl settings.

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/vcluster.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
EOF

sudo sysctl --system
```

Why this matters:

- `cgroup v2`: modern Kubernetes and modern container runtimes increasingly expect cgroup v2. On cgroup v1 hosts, node components may fail or behave unexpectedly.
- `br_netfilter`: required for transparent bridge visibility so iptables/nftables can enforce Kubernetes networking behavior.
- `bridge-nf-call-iptables=1`: keeps bridged traffic visible to iptables, which is necessary for kube-proxy and common CNI patterns.
- `ip_forward=1`: required for pod routing and service forwarding across local network namespaces.
- `fs.inotify.max_user_instances`: default is 128, which is too low for multi-node vind clusters (each node container spawns many inotify watchers). Raised to 1024 to support 4+ vind nodes. Also affects kind when running Cilium with kube-proxy replacement, though kind typically stays under the limit because it does not deploy a kube-proxy DaemonSet when Cilium replaces it.
- `fs.inotify.max_user_watches`: default is 65536, which can be exhausted by vind multi-node setups where each worker node runs its own kubelet, containerd, and CNI agents that all watch filesystem paths. Raised to 524288.

See `providers/vind/README.md` for provider-specific prerequisites.
