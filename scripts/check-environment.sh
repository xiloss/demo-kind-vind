#!/usr/bin/env bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_check() {
  printf '\n==> %s\n' "$1"
}

print_check "Required tools"

if command_exists docker; then
  docker --version
else
  printf 'docker: missing\n'
fi

if command_exists kubectl; then
  kubectl version --client=true
else
  printf 'kubectl: missing\n'
fi

print_check "Optional providers"

if command_exists vcluster; then
  vcluster version || true
  printf 'vind = vcluster v0.34+ with Docker driver. OK.\n'
else
  printf 'vcluster: missing (required for vind provider)\n'
fi

if command_exists kind; then
  kind_version=$(kind version | awk '{print $2}')
  printf 'kind: %s\n' "$kind_version"
  # Check if kind version is older than v0.27.0
  if [ "$(printf '%s\n' "v0.27.0" "$kind_version" | sort -V | head -n1)" = "v0.27.0" ]; then
    printf 'kind version is recent enough for Kubernetes 1.32+\n'
  else
    printf 'WARNING: kind %s may not support the latest Kubernetes versions.\n' "$kind_version"
    printf '  Consider upgrading: https://kind.sigs.k8s.io/docs/user/quick-start/\n'
  fi
else
  printf 'kind: missing\n'
fi

if command_exists vind; then
  vind version || true
else
  printf 'vind: missing (standalone; use vcluster CLI instead)\n'
fi

print_check "Docker status"

if command_exists docker && docker info >/dev/null 2>&1; then
  docker info --format 'Cgroup Driver: {{.CgroupDriver}}'
  docker info --format 'Cgroup Version: {{.CgroupVersion}}'
else
  printf 'Docker is not reachable. Start Docker or Docker Desktop.\n'
fi

print_check "Linux host prerequisites"

if command_exists docker && docker info >/dev/null 2>&1; then
  cgroup_version=$(docker info --format '{{.CgroupVersion}}')
  if [ "$cgroup_version" = "2" ]; then
    printf 'cgroup v2: OK\n'
  else
    printf 'cgroup v2: NOT DETECTED (modern local Kubernetes labs prefer cgroup v2)\n'
  fi
fi

if command_exists sysctl; then
  ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 'unknown')
  bridge_nf=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo 'unknown')
  printf 'net.ipv4.ip_forward=%s\n' "$ip_forward"
  printf 'net.bridge.bridge-nf-call-iptables=%s\n' "$bridge_nf"
else
  printf 'sysctl not available. Skipping kernel tuning checks.\n'
fi

print_check "Kubernetes context"

if command_exists kubectl; then
  kubectl config current-context || true
fi
