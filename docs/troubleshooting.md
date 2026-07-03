# Troubleshooting

## `cpu.weight: no such file or directory`

This usually points to a cgroup mismatch.

`cpu.weight` is a cgroup v2 control file. If your host is running cgroup v1, a modern Kubernetes/container runtime stack may fail when it expects cgroup v2.

Check Docker:

```bash
docker info | grep -i cgroup
```

Expected modern path:

```text
Cgroup Version: 2
```

If you see cgroup v1, consider switching the demo machine to cgroup v2 before the conference.

## Docker Is Not Reachable

Check:

```bash
docker version
docker info
```

If using Docker Desktop, confirm it is running and that your shell can access the Docker socket.

## Wrong Kubernetes Context

Check:

```bash
kubectl config current-context
kubectl config get-contexts
```

Select the intended context:

```bash
kubectl config use-context <context-name>
```

Common contexts:

```text
kind-zero-to-cluster-flannel
kind-zero-to-cluster-cilium
vind-zero-to-cluster-flannel
```

## Pods Are Pending

Inspect events:

```bash
kubectl describe pod -n zero-to-cluster <pod-name>
kubectl get events -n zero-to-cluster --sort-by=.lastTimestamp
```

Common causes:

- No available nodes.
- Image pull issues.
- Runtime or cgroup errors.
- Resource constraints.

## Cilium on kind fails because helm is missing

If you run:

```bash
./scripts/create-cluster.sh kind --cni cilium
```

and Helm is not installed, the script exits because Cilium installation on `kind` uses Helm by default.

Install Helm first:

| Platform | Command |
|----------|---------|
| Linux    | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash` |
| macOS    | `brew install helm` |
| Windows  | `winget install Helm.Helm` |
| Docs     | https://helm.sh/docs/intro/install/ |
