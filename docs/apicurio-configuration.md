# Apicurio Registry Configuration Guide

This guide covers the configuration for Apicurio Registry 3 in the CIVITAS Core deployment.

## Overview

This deployment uses:

- **Apicurio Registry 3.1.3** - Direct Helm deployment (no operator)
- **KafkaSQL storage** - Kafka-based persistent storage
- **Keycloak integration** - OAuth2/OIDC authentication enabled

## Architecture

The deployment consists of two components:

1. **Registry Backend (API)** - REST API on port 8080, path `/apis/registry/v3`
2. **Registry UI** - Web interface on port 8080, root path `/`

Both components connect to:

- **Kafka Cluster** (KafkaSQL storage backend)
- **Keycloak** (optional authentication)

**Key difference from typical deployments:** This uses KafkaSQL storage instead of PostgreSQL, and direct Helm charts instead of the Apicurio Operator.

## Configuration Files

### Environment Configuration (`environments/default/`)

**`apicurio.yaml`** - Main configuration:

- Namespace: `main-civitas2`
- Domain: `<APICURIO_DOMAIN>` (shared for API and UI)
- Images: `quay.io/apicurio/apicurio-registry:3.1.3` and `apicurio-registry-ui:3.1.3`
- Kafka bootstrap: `kafka-cluster-kafka-bootstrap.main-civitas2.svc.cluster.local:9092`
- Auth: Enabled with Keycloak integration

**`keycloak.yaml`** - OAuth2 clients configuration:

- Backend client: `apicurioRegistry`
- UI client: `apicurio-ui`
- Redirect URIs: `https://<APICURIO_DOMAIN>/*`

## KafkaSQL Storage Backend

### Critical Configuration

Storage type is set to `kafkasql` in `values/apicurio/apicurio.yaml.gotmpl`:

- Bootstrap servers: Kafka cluster service DNS
- Authentication: Currently disabled (TODO for production)
- Topic auto-create: **Disabled** - topics must be pre-created

### Required Kafka Topics

Must be created before deployment:

- **`kafkasql-journal`** - Main storage topic
- **`storage-topic`** - Additional artifact storage

**Topic requirements:**

- Replication factor: ≥ 3 (production)
- Partitions: 10 (adjust based on load)
- Retention: Infinite (-1)
- Cleanup policy: Compact

## Authentication with Keycloak

Authentication is enabled via Keycloak OAuth2/OIDC integration with `apicurio.auth.enabled: true` in `environments/default/apicurio.yaml`.

Keycloak clients configured in `environments/default/keycloak.yaml`:

- **apicurioRegistry** - Backend API client with client-secret authentication
- **apicurio-ui** - UI client with client-secret authentication
- Both use redirect URIs: `https://<APICURIO_DOMAIN>/*`

The registry connects to Keycloak at `https://keycloak.main.civitas2.fw-web.space/realms/civitas`.

To disable authentication (e.g., for development), set `apicurio.auth.enabled: false`.

## Ingress Configuration

**Unique setup:** Both API and UI share the same domain with different paths.

- **API**: `https://<APICURIO_DOMAIN>/apis/registry/v3`
- **UI**: `https://<APICURIO_DOMAIN>/`

API ingress includes `path: "/apis/registry/v3"` configuration.

## Registry Features

Key feature flags set in `values/apicurio/apicurio.yaml.gotmpl`:

- `resourceDeleteEnabled: false` - Prevents accidental schema deletion
- `versionMutabilityEnabled: false` - Ensures version immutability

For development, these can be set to `true` in `charts/apicurio/values.yaml`.

## Deployment Workflow

### Prerequisites

1. Kafka cluster running
2. Kafka topics created (see KafkaSQL section)
3. Keycloak running (if authentication enabled)

### Deployment Steps

```bash
# Deploy Apicurio
helmfile -f ./helmfile.d/04-apicurio.yaml.gotmpl sync -e default

# Verify deployment
kubectl get pods -n main-civitas2 -l app.kubernetes.io/name=apicurio
kubectl get ingress -n main-civitas2 | grep apicurio

# Check logs
kubectl logs -n main-civitas2 deployment/apicurio-app --tail=50
```

### Access Points

- **API**: `https://<APICURIO_DOMAIN>/apis/registry/v3`
- **UI**: `https://<APICURIO_DOMAIN>/`
- **Health**: `https://<APICURIO_DOMAIN>/apis/registry/v3/health`

## Troubleshooting

### Common Issues

**Pods not starting:**

```bash
kubectl logs -n main-civitas2 deployment/apicurio-app --tail=100
kubectl describe pod -n main-civitas2 -l app.kubernetes.io/name=apicurio
```

Common causes: Kafka not accessible, missing topics, image pull errors

**Kafka connection errors:**

```bash
kubectl logs -n main-civitas2 deployment/apicurio-app | grep -i kafka
```

Check: Kafka cluster status, bootstrap servers configuration, topic existence

**Data not persisting:**

```bash
kubectl exec -n main-civitas2 kafka-cluster-kafka-0 -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep kafkasql
```

Verify: Topics exist, correct replication/retention settings, topic auto-create is disabled

### Debug Mode

Enable debug logging by setting `apicurio.debug.enabled: true` in `environments/default/apicurio.yaml`. This adds DEBUG level logging for troubleshooting.

### Health Monitoring

```bash
kubectl exec -n main-civitas2 deployment/apicurio-app -- \
  curl -s http://localhost:8080/health/ready | jq
```

## Production Checklist

- ✅ Kafka cluster with replication factor ≥ 3
- ✅ Kafka topics pre-created with correct configuration
- ✅ Multiple replicas for app and UI (configured in chart values)
- ✅ Authentication enabled via Keycloak
- ✅ Resource limits configured (in chart values)
- ✅ `resourceDeleteEnabled: false` and `versionMutabilityEnabled: false`
- ✅ Pod disruption budgets configured
- ✅ Monitoring and health checks configured

## References

- [Apicurio Registry Documentation](https://www.apicur.io/registry/docs/)
- [KafkaSQL Storage Documentation](https://www.apicur.io/registry/docs/apicurio-registry/3.0.x/getting-started/assembly-using-kafka-streams.html)
- [CIVITAS Deployment Standards](./deployment-standards.md)
