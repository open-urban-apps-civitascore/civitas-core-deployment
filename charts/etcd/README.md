# etcd Helm Chart

This Helm chart deploys a production-ready etcd cluster on Kubernetes.

## Overview

etcd is a distributed reliable key-value store for the most critical data of a distributed system. This chart provides:

- StatefulSet-based deployment for stable network identities
- Persistent storage for data durability
- Health checks (startup, readiness, liveness probes)
- High availability with configurable replicas
- Security features (TLS support, RBAC authentication)
- Resource management and pod disruption budgets
- Graceful shutdown and cluster member management

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- A StorageClass available in your cluster (for persistent storage)
- `kubectl` CLI tool
- `etcdctl` CLI tool (for cluster verification and management)

## Installation

### Basic Installation

Deploy etcd with default settings (3 replicas, 10Gi storage):

```bash
helm install etcd ./charts/etcd -n etcd --create-namespace
```

### Custom Installation

Create a custom values file (`my-values.yaml`):

```yaml
replicas: 3
persistence:
  size: 20Gi
  storageClass: fast-ssd
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

Install with custom values:

```bash
helm install etcd ./charts/etcd -n etcd --create-namespace -f my-values.yaml
```

### Development Installation

For development/testing with minimal resources:

```yaml
replicas: 1
persistence:
  size: 1Gi
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

```bash
helm install etcd ./charts/etcd -n etcd --create-namespace -f dev-values.yaml
```

## Upgrade

To upgrade an existing etcd deployment:

```bash
helm upgrade etcd ./charts/etcd -n etcd -f my-values.yaml
```

⚠️ **Important**: Upgrading etcd requires careful planning:

- Review the [etcd upgrade documentation](https://etcd.io/docs/latest/upgrades/)
- Test upgrades in a non-production environment first
- Ensure you have recent backups
- Use the `RollingUpdate` strategy (default)

## Security

### Enabling TLS

To enable TLS for client communication:

1. Create certificates (CA, server cert, and key)
2. Create a Kubernetes secret:

```bash
kubectl create secret generic etcd-tls \
  --from-file=ca.crt=ca.crt \
  --from-file=tls.crt=server.crt \
  --from-file=tls.key=server.key \
  -n etcd
```

3. Update values:

```yaml
tls:
  enabled: true
  existingSecret: etcd-tls
```

### Enabling Authentication

etcd RBAC authentication allows you to create multiple users with different access levels.

#### Basic Authentication (Root User Only)

1. Create a secret with the root password:

```bash
kubectl create secret generic etcd-root-password \
  --from-literal=etcd-root-password='your-secure-password' \
  -n etcd
```

2. Update values:

```yaml
auth:
  enabled: true
  rbac:
    rootPasswordSecret:
      name: etcd-root-password
      key: etcd-root-password
```

#### Multiple Users with Roles

To create additional users beyond root:

1. Create secrets for each user:

```bash
# Create APISIX user secret
kubectl create secret generic etcd-apisix-password \
  --from-literal=password='apisix-secure-password' \
  -n etcd

# Create read-only user secret
kubectl create secret generic etcd-readonly-password \
  --from-literal=password='readonly-secure-password' \
  -n etcd
```

2. Update values with user definitions:

```yaml
auth:
  enabled: true
  rbac:
    rootPasswordSecret:
      name: etcd-root-password
      key: etcd-root-password
    users:
      - username: apisix
        role: readwrite # built-in roles: root, readwrite, read
        passwordSecret:
          name: etcd-apisix-password
          key: apisix-password
      # - username: readonly-app
      #   role: read
      #   passwordSecret:
      #     name: etcd-readonly-password
      #     key: password
```

**Available Roles:**

- `root`: Full administrative access
- `readwrite`: Read and write access to all keys
- `read`: Read-only access to all keys

**Note:** Authentication is automatically configured on the first pod startup using a postStart lifecycle hook. The configuration only runs once and is idempotent.

#### Connecting with Authentication

When authentication is enabled, clients must provide credentials:

```bash
# Using etcdctl
etcdctl --endpoints=http://localhost:2379 \
  --user=apisix:apisix-secure-password \
  put mykey myvalue

# From applications
etcd-client.etcd.svc.cluster.local:2379
Username: apisix
Password: <from-secret>
```

## Verification

After installation, verify the cluster health:

### 1. Check Pod Status

```bash
kubectl get pods -n etcd -l app.kubernetes.io/name=etcd
```

All pods should be in `Running` state with `1/1` ready.

### 2. Check StatefulSet

```bash
kubectl get statefulset -n etcd
```

### 3. Verify Cluster Health with etcdctl

Set up port forwarding:

```bash
kubectl port-forward svc/etcd-client 2379:2379 -n etcd
```

In another terminal, check cluster health:

```bash
export ETCDCTL_API=3
etcdctl --endpoints=http://localhost:2379 endpoint health
etcdctl --endpoints=http://localhost:2379 endpoint status --write-out=table
etcdctl --endpoints=http://localhost:2379 member list --write-out=table
```

Expected output for health check:

```
http://localhost:2379 is healthy: successfully committed proposal: took = 2.567534ms
```

### 4. Test Read/Write Operations

Write a test key:

```bash
etcdctl --endpoints=http://localhost:2379 put test-key "Hello etcd"
```

Read the key back:

```bash
etcdctl --endpoints=http://localhost:2379 get test-key
```

Expected output:

```
test-key
Hello etcd
```

Delete the test key:

```bash
etcdctl --endpoints=http://localhost:2379 del test-key
```

## Usage

### Accessing etcd from Applications

Applications can connect to etcd using the client service:

**Service DNS Name:**

```
etcd-client.<namespace>.svc.cluster.local:2379
```

**Example (Go application):**

```go
import "go.etcd.io/etcd/client/v3"

client, err := clientv3.New(clientv3.Config{
    Endpoints:   []string{"etcd-client.etcd.svc.cluster.local:2379"},
    DialTimeout: 5 * time.Second,
})
```

### Backup and Restore

#### Creating a Backup

```bash
# Port forward to etcd
kubectl port-forward svc/etcd-client 2379:2379 -n etcd

# Create snapshot
etcdctl --endpoints=http://localhost:2379 snapshot save backup.db

# Verify snapshot
etcdctl --endpoints=http://localhost:2379 --write-out=table snapshot status backup.db
```

#### Restoring from Backup

⚠️ **Warning**: Restore operations should be carefully planned and tested.

1. Scale down the StatefulSet:

```bash
kubectl scale statefulset etcd -n etcd --replicas=0
```

2. Delete existing PVCs (after backing them up):

```bash
kubectl delete pvc -l app.kubernetes.io/name=etcd -n etcd
```

3. Restore the data (requires manual intervention on each pod)

4. Scale up the StatefulSet:

```bash
kubectl scale statefulset etcd -n etcd --replicas=3
```

For detailed restore procedures, refer to the [official etcd documentation](https://etcd.io/docs/latest/op-guide/recovery/).

## High Availability

For production deployments:

- **Use odd number of replicas**: 3, 5, or 7 (for quorum)
- **Enable PodDisruptionBudget**: Ensures minimum availability during updates
- **Configure pod anti-affinity**: Spreads replicas across nodes (enabled by default)
- **Set resource requests/limits**: Ensures predictable performance
- **Enable persistent storage**: Prevents data loss

### Recommended Production Configuration

```yaml
replicas: 3
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
podDisruptionBudget:
  enabled: true
  minAvailable: 2
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: etcd
        topologyKey: kubernetes.io/hostname
```

## Troubleshooting

### Pods Not Starting

Check pod events:

```bash
kubectl describe pod etcd-0 -n etcd
```

Common issues:

- **Insufficient resources**: Verify node has enough CPU/memory
- **Storage issues**: Check if PVC is bound and StorageClass exists
- **Image pull errors**: Verify image repository and credentials

### Cluster Not Forming

Check logs:

```bash
kubectl logs etcd-0 -n etcd
kubectl logs etcd-1 -n etcd
kubectl logs etcd-2 -n etcd
```

Common issues:

- **Network connectivity**: Verify pods can communicate
- **Incorrect initial cluster configuration**: Check `ETCD_INITIAL_CLUSTER` environment variable
- **Token mismatch**: Ensure all members use the same cluster token

### Performance Issues

Monitor etcd metrics:

```bash
# Check endpoint status
etcdctl --endpoints=http://localhost:2379 endpoint status --write-out=table

# Check backend database size
etcdctl --endpoints=http://localhost:2379 endpoint status --write-out=json | jq '.[] | .Status.dbSize'
```

Common causes:

- **Database size too large**: Enable auto-compaction
- **Insufficient resources**: Increase CPU/memory limits
- **Slow disk**: Use faster storage class (SSD)

### Cluster Member Issues

List cluster members:

```bash
etcdctl --endpoints=http://localhost:2379 member list
```

Remove unhealthy member:

```bash
etcdctl --endpoints=http://localhost:2379 member remove <member-id>
```

## Monitoring

To enable Prometheus monitoring:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
```

etcd exposes metrics at `/metrics` endpoint on the client port.

## Limitations

- This chart deploys etcd in a single Kubernetes cluster
- Cross-cluster replication is not supported
- Backup automation is not included (consider using external tools)
- Advanced monitoring dashboards are not included

## References

- [etcd Official Documentation](https://etcd.io/docs/)
- [etcd Operations Guide](https://etcd.io/docs/latest/op-guide/)
- [etcdctl Usage](https://etcd.io/docs/latest/dev-guide/interacting_v3/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## Support

For issues specific to this Helm chart, please refer to the repository issues.

For etcd-specific questions, consult the [etcd community](https://etcd.io/community/).
