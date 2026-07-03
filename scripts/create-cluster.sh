#!/usr/bin/env bash
set -euo pipefail

provider="${1:-}"
multi_node=""
cni="default"

usage() {
  cat <<EOF
Usage: $0 <provider> [--multi-node] [--cni flannel|cilium|cilium-kpr|calico]

Providers:
  kind            Create a local kind cluster
  vind            Create a vCluster cluster with the Docker driver

Options:
  --multi-node    Use the multi-node layout (1 control-plane + 3 workers)
  --cni NAME      Select a CNI preset: flannel, cilium, cilium-kpr, calico (default: flannel)
  -h, --help      Show this help message

Cluster naming convention:
  {provider}-zero-to-cluster-{cni}
  Examples: kind-zero-to-cluster-flannel, vind-zero-to-cluster-cilium

Examples:
  $0 kind
  $0 kind --multi-node
  $0 kind --multi-node --cni flannel
  $0 kind --multi-node --cni cilium
  $0 kind --multi-node --cni cilium-kpr
  $0 kind --multi-node --cni calico

  $0 vind
  $0 vind --multi-node
  $0 vind --multi-node --cni flannel
  $0 vind --multi-node --cni cilium
  $0 vind --multi-node --cni cilium-kpr
  $0 vind --multi-node --cni calico
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

if [ "$#" -gt 0 ]; then
  shift 1
fi

shift_provider=1
while [ "$#" -ge "$shift_provider" ]; do
  arg="${!shift_provider}"
  case "$arg" in
    --multi-node)
      multi_node="true"
      shift_provider=$((shift_provider + 1))
      ;;
    --cni)
      cni_index=$((shift_provider + 1))
      if [ "$cni_index" -gt "$#" ]; then
        printf '--cni requires a value: flannel, cilium, cilium-kpr, calico\n'
        exit 1
      fi
      cni="${!cni_index}"
      shift_provider=$((shift_provider + 2))
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$provider" ]; then
  usage
  exit 1
fi

# Default CNI to flannel if not specified
if [ "$cni" = "default" ]; then
  cni="flannel"
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

printf 'Cluster name: %s\n' "$cluster_name"
printf 'Namespace:    %s\n' "$namespace"

case "$provider" in
  kind)
    command -v kind >/dev/null 2>&1 || { printf 'kind is required.\n'; exit 1; }

    # Select template based on multi-node flag
    if [ "$multi_node" = "true" ]; then
      template="providers/kind/templates/multi-node.yaml.tmpl"
      printf 'Using multi-node kind layout (1 control-plane + 3 workers)\n'
    else
      template="providers/kind/templates/single-node.yaml.tmpl"
      printf 'Using single-node kind layout\n'
    fi

    # Generate networking section based on CNI
    networking=""
    case "$cni" in
      flannel)
        networking=""
        ;;
      cilium|calico)
        networking='networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"'
        ;;
      cilium-kpr)
        networking='networking:
  disableDefaultCNI: true
  kubeProxyMode: none
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"'
        ;;
    esac

    # Generate final config from template (always replace __NETWORKING__)
    config_file="/tmp/kind-${cluster_name}.yaml"
    networking_file="/tmp/kind-${cluster_name}-networking.txt"
    printf '%s' "$networking" > "$networking_file"
    python3 -c "
with open('$template') as f:
    tmpl = f.read()
with open('$networking_file') as f:
    net = f.read()
result = tmpl.replace('__NETWORKING__', net)
with open('$config_file', 'w') as f:
    f.write(result)
"
    rm -f "$networking_file"
    printf 'Generated kind config: %s\n' "$config_file"

    # Create kind cluster
    printf 'Creating kind cluster: %s\n' "$cluster_name"
    kind create cluster --name "$cluster_name" --config "$config_file"
    kubectl cluster-info --context "kind-${cluster_name}"

    # Install CNI if not using default flannel
    case "$cni" in
      cilium)
        command -v helm >/dev/null 2>&1 || { printf 'helm is required for Cilium on kind.\n'; exit 1; }
        printf 'Installing Cilium with Hubble into kind cluster\n'
        helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
        helm repo update >/dev/null
        helm upgrade --install cilium cilium/cilium --namespace kube-system --wait \
          --set hubble.enabled=true \
          --set hubble.relay.enabled=true \
          --set hubble.ui.enabled=true
        kubectl -n kube-system rollout status ds/cilium --timeout=180s
        printf '\nHubble UI available at:\n'
        printf '  kubectl port-forward -n kube-system svc/hubble-ui 12000:80\n'
        printf '  http://localhost:12000\n\n'
        ;;
      cilium-kpr)
        command -v helm >/dev/null 2>&1 || { printf 'helm is required for Cilium on kind.\n'; exit 1; }
        printf 'Installing Cilium with kube-proxy replacement and Hubble into kind cluster\n'
        k8s_service_host=$(docker inspect "${cluster_name}-control-plane" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
        helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
        helm repo update >/dev/null
        helm upgrade --install cilium cilium/cilium --namespace kube-system --wait \
          --set kubeProxyReplacement=true \
          --set k8sServiceHost="$k8s_service_host" \
          --set k8sServicePort=6443 \
          --set hubble.enabled=true \
          --set hubble.relay.enabled=true \
          --set hubble.ui.enabled=true
        kubectl -n kube-system rollout status ds/cilium --timeout=180s
        printf 'Removing kube-proxy DaemonSet (Cilium replaces it)\n'
        kubectl -n kube-system delete ds kube-proxy --ignore-not-found
        printf '\nHubble UI available at:\n'
        printf '  kubectl port-forward -n kube-system svc/hubble-ui 12000:80\n'
        printf '  http://localhost:12000\n\n'
        ;;
      calico)
        printf 'Installing Calico into kind cluster\n'
        kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
        kubectl -n kube-system rollout status ds/calico-node --timeout=240s
        ;;
    esac

    kubectl get nodes -o wide
    ;;

  vind)
    command -v vcluster >/dev/null 2>&1 || {
      printf 'vcluster CLI (v0.35.0+) is required. vind = vcluster with Docker driver.\n'
      printf 'Linux:   curl -sSL https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64 -o /tmp/vcluster\n'
      printf '         sudo install -m 0755 /tmp/vcluster /usr/local/bin/vcluster\n'
      printf 'macOS:   brew install vcluster\n'
      printf 'Windows: winget install LoftLabs.vcluster\n'
      printf 'Docs:    https://github.com/loft-sh/vind\n'
      exit 1
    }

    cni_file='providers/vind/cni/flannel.yaml'
    case "$cni" in
      flannel)    cni_file='providers/vind/cni/flannel.yaml' ;;
      cilium)     cni_file='providers/vind/cni/cilium.yaml' ;;
      cilium-kpr) cni_file='providers/vind/cni/cilium-kpr.yaml' ;;
      calico)     cni_file='providers/vind/cni/calico.yaml' ;;
    esac

    if [ "$multi_node" = "true" ]; then
      values='providers/vind/vcluster-multi-node.yaml'
      printf 'Using multi-node vind layout (1 control-plane + 3 workers)\n'
    else
      values='providers/vind/values.yaml'
      printf 'Using single-node vind layout\n'
    fi

    printf 'Using vind CNI preset: %s\n' "$cni_file"
    printf 'Setting vcluster to use Docker driver\n'
    vcluster use driver docker
    printf 'Creating vcluster in Docker (vind): %s\n' "$cluster_name"
    vcluster create "$cluster_name" --namespace "$namespace" -f "$values" -f "$cni_file"
    vcluster connect "$cluster_name" --namespace "$namespace" --update-current=false

    case "$cni" in
      cilium)
        printf 'Installing Cilium with Hubble into vind cluster\n'
        helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
        helm repo update >/dev/null
        helm upgrade --install cilium cilium/cilium --namespace kube-system --wait \
          --set hubble.enabled=true \
          --set hubble.relay.enabled=true \
          --set hubble.ui.enabled=true
        kubectl -n kube-system rollout status ds/cilium --timeout=180s
        printf '\nHubble UI available at:\n'
        printf '  kubectl port-forward -n kube-system svc/hubble-ui 12000:80\n'
        printf '  http://localhost:12000\n\n'
        ;;
      cilium-kpr)
        printf 'Installing Cilium with kube-proxy replacement and Hubble into vind cluster\n'
        k8s_service_host=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.clusterIP}')
        helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
        helm repo update >/dev/null
        helm upgrade --install cilium cilium/cilium --namespace kube-system --wait \
          --set kubeProxyReplacement=true \
          --set k8sServiceHost="$k8s_service_host" \
          --set k8sServicePort=443 \
          --set hubble.enabled=true \
          --set hubble.relay.enabled=true \
          --set hubble.ui.enabled=true
        kubectl -n kube-system rollout status ds/cilium --timeout=180s
        printf 'Removing kube-proxy DaemonSet (Cilium replaces it)\n'
        kubectl -n kube-system delete ds kube-proxy --ignore-not-found
        printf '\nHubble UI available at:\n'
        printf '  kubectl port-forward -n kube-system svc/hubble-ui 12000:80\n'
        printf '  http://localhost:12000\n\n'
        ;;
      calico)
        printf 'Installing Calico into vind cluster\n'
        kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
        kubectl -n kube-system rollout status ds/calico-node --timeout=240s
        ;;
    esac

    kubectl get nodes -o wide
    ;;

  *)
    usage
    exit 1
    ;;
esac

printf '\nCluster created successfully: %s\n' "$cluster_name"
printf 'Namespace: %s\n' "$namespace"
printf '\nTo deploy the app:\n'
printf '  NAMESPACE=%s ./scripts/deploy-app.sh\n' "$namespace"
printf '\nTo clean up:\n'
printf '  ./scripts/cleanup.sh %s %s\n' "$provider" "$cni"
