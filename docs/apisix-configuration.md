# APISIX Configuration Guide

This guide covers the configuration for Apache APISIX in the CIVITAS Core deployment.

## Overview

This deployment uses:

- **Apache APISIX** - Cloud-native API Gateway via official Helm chart
- **Etcd storage** - External etcd cluster for configuration persistence
- **Ingress Controller** - Kubernetes Ingress resource management

## Architecture

The deployment consists of two main components:

1. **APISIX Gateway** - API Gateway handling traffic routing and policies
2. **APISIX Ingress Controller** - Manages Kubernetes Ingress resources

APISIX connects to:

- **Etcd** - Configuration and route storage
- **Upstream Services** - Backend APIs being proxied

**Key difference from typical deployments:** Uses external etcd cluster with RBAC authentication instead of embedded etcd.

## Configuration Files

### Environment Configuration (`environments/`)

**`apisix.yaml`** - Main configuration:

- Namespace: `local-civitas2` (local) / `main-civitas2` (default)
- Domain: `<APISIX_DOMAIN>` for admin API access
- Image: Apache APISIX official images
- Chart version and repository
- Admin credentials secret names

### Values Configuration (`values/apisix/`)

**`apisix.yaml.gotmpl`** - Helm values:

- Resource limits and requests
- Timezone configuration
- Admin API credentials and ingress
- External etcd connection details
- Metrics and monitoring settings
- Ingress controller enablement

## Etcd Integration

### Connection Configuration

APISIX connects to the external etcd cluster:

```yaml
etcd:
  enabled: false # Disable embedded etcd

externalEtcd:
  host:
    - http://etcd-client.<namespace>.svc.cluster.local:2379
  user: 'apisix'
  existingSecret: 'etcd-apisix-password'
  secretPasswordKey: 'apisix-password'
```

### Authentication

APISIX authenticates to etcd using:

- **Username**: `apisix` (dedicated etcd user)
- **Password**: From secret `etcd-apisix-password`
- **Permissions**: Read/write access to `/apisix/` prefix only

The `apisix` user is created by the etcd auth-init-job with scoped permissions.

## Admin API

### Access Configuration

The Admin API is exposed via Ingress:

- **Path**: `/` (configurable in environment values)
- **Domain**: Configured per environment
- **Authentication**: API key-based (secrets)

### Credentials

Admin credentials are auto-generated during deployment:

- **Admin key**: Full administrative access
- **Viewer key**: Read-only access

Secrets are created via pre-sync hook in `helmfile.d/05-apisix.yaml.gotmpl` if they don't exist.

### Usage

Access the Admin API:

```bash
# Get admin key
ADMIN_KEY=$(kubectl get secret apisix-admin-credentials \
  -n local-civitas2 -o jsonpath='{.data.admin-key}' | base64 -d)

# List routes
curl -H "X-API-KEY: $ADMIN_KEY" \
  https://<APISIX_DOMAIN>/apisix/admin/routes
```

## Ingress Controller

The APISIX Ingress Controller is enabled by default and manages Kubernetes Ingress resources.

### Features

- **Automatic route creation** from Ingress resources
- **Native Kubernetes integration** via CRDs
- **Advanced routing** capabilities beyond standard Ingress

### Configuration

Ingress controller settings in `values/apisix/apisix.yaml.gotmpl`:

```yaml
ingress-controller:
  enabled: true # Can be disabled per environment
```

## Route Management

### Via Admin API

Create routes using the Admin API:

```bash
curl -H "X-API-KEY: $ADMIN_KEY" -X PUT \
  https://<APISIX_DOMAIN>/apisix/admin/routes/1 \
  -d '{
    "uri": "/api/*",
    "upstream": {
      "nodes": {
        "backend-service:8080": 1
      },
      "type": "roundrobin"
    }
  }'
```

### Via Ingress Resources

Create standard Kubernetes Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-api
  annotations:
    kubernetes.io/ingress.class: apisix
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 8080
```

## Troubleshooting

### Common Issues

**APISIX not connecting to etcd:**

```bash
kubectl logs -n local-civitas2 deployment/apisix | grep -i etcd
```

Common causes:

- Etcd not ready or authentication not enabled
- Incorrect user credentials
- Network connectivity issues
- Wrong etcd endpoint

**Admin API not accessible:**

```bash
kubectl get secret -n local-civitas2 apisix-admin-credentials
kubectl get ingress -n local-civitas2 apisix-admin
```

Check: Ingress configuration, secret existence, domain DNS resolution

**Routes not working:**

```bash
# Check route configuration
curl -H "X-API-KEY: $ADMIN_KEY" \
  https://<APISIX_DOMAIN>/apisix/admin/routes

# Check upstream health
curl -H "X-API-KEY: $ADMIN_KEY" \
  https://<APISIX_DOMAIN>/apisix/admin/upstreams
```

### Debug Mode

Enable debug logging by checking APISIX logs:

```bash
kubectl logs -n local-civitas2 deployment/apisix --tail=100 -f
```

For detailed debugging, access the pod directly:

```bash
kubectl exec -n local-civitas2 deployment/apisix -it -- /bin/sh
```

### Etcd Connection Testing

Verify etcd connectivity from APISIX pod:

```bash
kubectl exec -n local-civitas2 deployment/apisix -- \
  curl -u apisix:<password> \
  http://etcd-client.local-civitas2.svc.cluster.local:2379/version
```

## Configuration Updates

### Updating Admin Credentials

To regenerate admin credentials:

1. Delete the existing secret:

```bash
kubectl delete secret -n local-civitas2 apisix-admin-credentials
```

2. Set force recreate flag in environment values:

```yaml
apisix:
  admin:
    credentials:
      forceRecreateSecret: true
```

3. Redeploy - new credentials will be generated

### Updating Etcd Connection

To change etcd connection settings:

1. Update `values/apisix/apisix.yaml.gotmpl`
2. Ensure etcd user has proper permissions
3. Redeploy APISIX

Routes and configuration will be preserved in etcd.

## Production Checklist

- ✅ Multiple replicas for high availability
- ✅ Resource limits configured appropriately
- ✅ Etcd authentication enabled and working
- ✅ Admin API access restricted (Ingress auth/allowlist)
- ✅ Monitoring and metrics collection enabled
- ✅ Rolling update strategy configured
- ✅ Health checks and readiness probes working
- ✅ TLS/SSL certificates configured for exposed routes

## Security Considerations

**Current state:**

- Admin API: Protected by API keys
- Etcd connection: Authenticated with dedicated user
- Route access: Controlled via route configuration

**Production recommendations:**

- Restrict Admin API ingress to internal networks only
- Use TLS for Admin API access
- Implement rate limiting on routes
- Regular credential rotation
- Enable audit logging
- Use mTLS for sensitive upstream services

## References

- [Apache APISIX Documentation](https://apisix.apache.org/docs/)
- [APISIX Helm Chart](https://github.com/apache/apisix-helm-chart)
- [APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/)
- [Etcd Configuration Guide](./etcd-configuration.md)
- [CIVITAS Deployment Standards](./deployment-standards.md)
