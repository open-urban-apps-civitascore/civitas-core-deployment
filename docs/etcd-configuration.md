# Etcd Configuration Guide

This guide covers the configuration for etcd in the CIVITAS Core deployment.

## Overview

This deployment uses:

- **etcd v3.5.17** - Custom Helm chart deployment
- **RBAC Authentication** - Role-based access control with custom user management
- **StatefulSet** - Persistent data storage with quorum-based clustering

## Architecture

The deployment consists of:

1. **Etcd StatefulSet** - Clustered key-value store (1 or 3 replicas depending on profile)
2. **Headless Service** - Inter-pod communication for clustering
3. **Client Service** - External client access
4. **Auth Init Job** - Post-deployment authentication setup

Components connect to etcd:

- **APISIX** - API Gateway configuration storage
- Other services requiring distributed configuration

**Key difference from typical deployments:** Custom RBAC implementation with role-based access instead of simple username/password authentication.

## Configuration

## RBAC Authentication

### Authentication Model

The deployment uses a custom RBAC system with:

1. **Roles** - Define permission sets on key prefixes
2. **Users** - Assigned to roles for scoped access
3. **Root user** - Full administrative access

### Role Configuration

Roles are defined in `values/etcd/etcd-base.yaml`:

```yaml
roles:
  - name: apisix-readwrite
    permissions:
      - permission: readwrite # read, write, or readwrite
        key: /apisix/ # Key or prefix path
        prefix: true # true for prefix matching, false for single key
```

### User Configuration

Users reference role names:

```yaml
users:
  - username: apisix
    role: apisix-readwrite
    passwordSecret:
      name: etcd-apisix-password
      key: apisix-password
```

## Secrets Management

Required secrets must be created before deployment via `helmfile.d/00-secrets.yaml.gotmpl`:

- **`etcd-root-password`** - Root user password (32 characters)
- **`etcd-apisix-password`** - APISIX user password (32 characters)

Additional user secrets can be added following the same pattern.

## Deployment Workflow

### Prerequisites

1. Namespace created
2. Secrets generated and applied

### Deployment Steps

```bash
# Deploy etcd
helmfile -f ./helmfile.d/03b-etcd.yaml.gotmpl sync -e local

# Verify deployment
kubectl get pods -n local-civitas2 -l app.kubernetes.io/name=etcd
kubectl get pvc -n local-civitas2 | grep etcd

# Check auth init job
kubectl get jobs -n local-civitas2 -l app.kubernetes.io/component=auth-init
kubectl logs -n local-civitas2 job/etcd-auth-init
```

### Access Points

- **Client endpoint**: `http://etcd-client.<namespace>.svc.cluster.local:2379`
- **Headless endpoint** (pod 0): `http://etcd-0.etcd-headless.<namespace>.svc.cluster.local:2379`

## Adding New Users

To add a new user with custom permissions:

1. **Define the role** in `values/etcd/etcd-base.yaml`:

```yaml
roles:
  - name: myapp-readonly
    permissions:
      - permission: read
        key: /myapp/
        prefix: true
```

2. **Add the user**:

```yaml
users:
  - username: myapp
    role: myapp-readonly
    passwordSecret:
      name: etcd-myapp-password
      key: myapp-password
```

3. **Create the secret** in `values/secrets/all-secrets.yaml.gotmpl`:

```yaml
- name: etcd-myapp-password
  namespace: { { .Values.etcd.namespace } }
  keys:
    myapp-password: 32
```

4. **Redeploy**: The auth-init-job will create the role and user on next deployment.

## References

- [etcd Documentation](https://etcd.io/docs/)
- [etcd RBAC Guide](https://etcd.io/docs/v3.5/op-guide/authentication/rbac/)
- [CIVITAS Deployment Standards](./deployment-standards.md)
