# APISIX

Central API Gateway of the platform, providing traffic management, security, and observability features.

## Description

APISIX is a dynamic, real-time, high-performance API gateway. It provides rich traffic management features such as load balancing, dynamic upstream, canary release, circuit breaking, authentication, observability, and more.

This component deploys:
- **APISIX Gateway**: The core API gateway handling traffic routing and management
- **APISIX Ingress Controller**: Kubernetes-native ingress controller for managing APISIX routes via Kubernetes resources

## Requirements

### External Components (Required)

| Component | Description |
|-----------|-------------|
| **etcd** | External etcd cluster with RBAC enabled for storing APISIX configuration |

### Kubernetes Requirements

- Kubernetes 1.19+
- Helm 3.2.0+

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `apisix.apisix.enabled` | Enable/disable the component | `true` |
| `apisix.apisix.namespace` | Namespace for deployment | `<instance>-apisix` |
| `apisix.apisix.etcd.host` | External etcd host | `etcd.apisix.svc.cluster.local` |
| `apisix.apisix.etcd.port` | External etcd port | `2379` |
| `apisix.apisix.etcd.user` | etcd RBAC username | `root` |
| `apisix.apisix.etcd.existingSecret` | Secret containing etcd password | `apisix-etcd-secret` |
| `apisix.apisix.etcd.secretPasswordKey` | Key in secret for password | `etcd-root-password` |

## Deployment

Deploy the component with:

```bash
# navigate to `deployment/` and run:
helmfile apply -i --selector component=apisix
```

## Notes

- The built-in etcd is disabled; you must provide an external etcd cluster
- RBAC authentication is required for etcd access
- The ingress controller integrates with APISIX to manage routes via Kubernetes CRDs
