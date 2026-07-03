# Docker Desktop Kubernetes Provider

> **Note:** This provider is retained as reference material for a future Docker
> Captain article. It is **not** included in the active demo scripts
> (`create-cluster.sh`, `cleanup.sh`). The demo focuses on `kind` and `vind`.
> See `social/docker_captain/` for the related article content.

This provider uses the Kubernetes cluster built into Docker Desktop.

## Install Docker Desktop

Install Docker Desktop first if it is not already installed.

| Platform | Resource |
|----------|----------|
| macOS    | https://docs.docker.com/desktop/install/mac-install/ |
| Windows  | https://docs.docker.com/desktop/install/windows-install/ |
| Linux    | https://docs.docker.com/desktop/install/linux-install/ |
| Overview | https://docs.docker.com/desktop/ |

Linux examples:

```bash
# Debian/Ubuntu (.deb)
sudo apt install ./docker-desktop-<version>-<arch>.deb

# Fedora/RHEL (.rpm)
sudo dnf install ./docker-desktop-<version>-<arch>.rpm
```

If you only need Docker Engine on Linux, see: https://docs.docker.com/engine/install/

## Enable Kubernetes

1. Open Docker Desktop.
2. Go to Settings > Kubernetes.
3. Enable Kubernetes.
4. Click "Apply & Restart".
5. Wait until Docker Desktop reports Kubernetes is running (green indicator).

## Select Context

```bash
kubectl config use-context docker-desktop
kubectl get nodes -o wide
```

## CNI Options

Docker Desktop uses its built-in CNI by default (similar to flannel). You can
replace it with Cilium or Calico manually using Helm or manifests.

### Default (built-in flannel)

No additional steps needed.

### Cilium

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium --namespace kube-system --wait \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

### Cilium with kube-proxy replacement

```bash
k8s_service_host=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.clusterIP}')
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium --namespace kube-system --wait \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$k8s_service_host" \
  --set k8sServicePort=443 \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
kubectl -n kube-system delete ds kube-proxy --ignore-not-found
```

### Calico

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

### Hubble UI (Cilium Observability)

When using Cilium (`--cni cilium` or `--cni cilium-kpr`), Hubble is automatically
installed with the UI enabled. To access the Hubble UI:

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

Then open http://localhost:12000 in your browser.

## Demo Limitation

Docker Desktop is usually single-node, so it is good for deployment and
reconciliation demos, but less useful for multi-node scheduling and node
failure scenarios.

## Cleanup

```bash
kubectl delete namespace <your-namespace>
```
