# Deployment Standards

This document outlines the deployment standards for the CIVITAS Core deployment repository.
All deployments must adhere to these requirements.

## Development tools

- [helm](https://helm.sh/docs/intro/install/)
- [helmfile](https://helmfile.readthedocs.io/en/latest/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download)
- [pre-commit](https://pre-commit.com/#install)
- [k9s](https://k9scli.io/topics/install/) (optional)

## Kubernetes Clusters

For deployment and staging deployments, we can use Frachtwerk's Development Kubernetes cluster.
Access is maintained by Tobias Dillig (tobias.dillig@frachtwerk.de)

Staging environment domains:
`*.main.civitas2.fw-web.space`: Staging environment for CIVITAS Core V2

Development environment domains:
`*.dev1.civitas2.fw-web.space`: Used by Andreas Linneweber (linneweber@kernblick.de) for development and testing
`*.dev2.civitas2.fw-web.space`: Used by Florian Graßmann (fg@codestryke.com) for development and testing
`*.dev3.civitas2.fw-web.space`: Used by Patrick Kopp (pk@codestryke.com) for development and testing
`*.dev4.civitas2.fw-web.space`: Used by Julian Sobott (julian.sobott@frachtwerk.de) for development and testing
`*.dev5.civitas2.fw-web.space`: Used by Tobias Dillig (tobias.dillig@frachtwerk.de) for development and testing

For local development, use the provided Makefile commands:

```bash
# Deploy minikube with local environment (starts minikube, enables addons, creates namespace and secrets, syncs helmfile)
make deploy-local

# On MacOS
# Port-forward to access services locally
sudo kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 443:443
# Optional: Add host entries to /etc/hosts for easier access
make add-hosts-macos

# On Linux
# Optional: Add host entries to /etc/hosts for easier access
make add-hosts-linux

# Now you can access services on https://<service name>.civitas.test

# Login to keycloak on https://keycloak.civitas.test to create user accounts (username: environments/default/keycloak.yaml > keycloak.admin.user, password: from k8s secrets, see below)
kubectl get secret keycloak-admin-user -n local-civitas2 -o jsonpath='{.data.admin-password}' | base64 --decode
```

## Repository Structure

- **Helmfile-based**: All infrastructure deployed via Helmfile
- **Environment configs**: Customer facing `environments/` directory for environment-specific values
- **Shared values**: Default `values/` defined by CIVITAS team to ensure comprehensive defaults
- **Helm charts**: Custom charts in `charts/` directory

## Code Quality

All code changes are validated automatically via pre-commit hooks:

```bash
make validate # Test all files with pre-commit
```

Pre-commit hooks enforce:

- Naming conventions
  - kebab-case
    - for files and directories
  - camelCase
    - Inside all yaml files (values, helm charts)
  - PascalCase
    - For some Helm chart specific variables (like Environment, Values)
- YAML/JSON formatting and linting
- Markdown linting
- Helm chart validation

**Pre-commit hooks also run in pipelines to ensure a system-wide standard.**

## Naming Conventions

All files and directories follow **kebab-case** naming:

- **Files**: `my-config-file.yaml` (3-50 characters)
- **Directories**: `my-directory-name` (3-50 characters)
- **No uppercase, underscores, or unicode**
- **No empty files or duplicates**

Exceptions: Helm-specific files (`.helmignore`, `NOTES.txt`, `_helpers.tpl`, `Chart.yaml`)

Enforced by pre-commit hooks - run `make validate` to check.

## Deployment Requirements

Use the [Checklist](.gitlab/merge_request_templates/deployment.md) to verify compliance before merging.

### Version Management

- **All chart versions pinned** (no `latest`)
- **All image tags pinned** (no `latest`)
- Keep customizations minimal and only override values that are essential for your deployment

### High Availability

For production environments:

- **Replicas**: Use HorizontalPodAutoscaler (HPA) for dynamic scaling, or set minimum 2 replicas for stateless applications
- **Rolling updates** (where accessible): Configure `maxUnavailable: 0`, `maxSurge: 25%`
- **PodDisruptionBudget** (where accessible): Ensure at least 1 pod available during updates

For development environments, scale down resources and replicas as needed. Consider using a profile flag (`profile: dev|prod` or `enable_ha`) in Helm charts to manage environment-specific configurations.

### Resource Management

- **Set CPU & memory requests** (for scheduling)
- **Set CPU & memory limits** (prevent resource exhaustion)
- Make resource configuration environment-aware (production vs. development)

### Security & Code Review

Follow these security guidelines when working with Kubernetes manifests, Helm charts, and infrastructure code. Based on our [SSDLC](https://docs.core.civitasconnect.digital/docs_v2/Development/Development%20Process/SSDLC_Distilled).

#### Container Security

- Run all containers as non-root user (`runAsNonRoot: true`)
- Use read-only root filesystem (`readOnlyRootFilesystem: true`)
- Drop all capabilities and add only what's needed
- No privileged containers unless absolutely necessary (document why)
- Pin all image tags (never use `latest` or mutable tags)

```yaml
❌ Insecure container
securityContext:
  privileged: true

✅ Secure container
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

#### Secrets Management

- No plaintext secrets in Git (use Kubernetes Secrets or external secret managers)
- No secrets in ConfigMaps or environment variables visible in pod specs
- Use `stringData` for creating secrets, not base64 in manifests
- Document secret rotation procedures
- Reference secrets via `secretKeyRef` or volume mounts

#### Network Security

- Implement NetworkPolicies (default-deny, then allow specific traffic)
- All external endpoints use TLS (ingress with cert-manager)
- Internal service-to-service communication over TLS where possible
- Minimize exposed ports and services

#### RBAC & Access Control

- Use ServiceAccounts with least privilege principle
- Never use `cluster-admin` for applications
- Create specific Roles/ClusterRoles for each component
- Document why each permission is needed

#### Resource Management

- Set both requests and limits for CPU and memory
- Use ResourceQuotas for namespaces in multi-tenant setups
- Implement PodDisruptionBudgets for production workloads
- Configure appropriate `terminationGracePeriodSeconds`

#### Configuration & Defaults

- Use secure defaults in Helm charts
- Make security features opt-out, not opt-in
- Validate all user-provided values in Helm templates
- Document security implications of configuration options

#### Observability

- Configure health probes (startup, liveness, readiness)
- Ensure logs don't contain secrets or PII
- Use structured logging where possible
- Enable audit logging for security-relevant events

---

See also: [SSDLC Guidelines](../../documentation/docs_v2/Development/Development%20Process/SSDLC_Distilled.md) for comprehensive security requirements.

### Observability & Reliability

- **Health probes** (where accessible): Configure startup, readiness, and liveness probes for long-running applications (exclude jobs and init containers)
- **Graceful shutdown** (where accessible): Set `terminationGracePeriodSeconds` + `preStop` hook
- **Standard labels**: For custom Helm charts, implement [Kubernetes recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)

### Networking

- **Named ports** in Services (where accessible)
- **Ingress with TLS** via cert-manager

## Validation Workflow

1. Make changes to Helm charts or values
2. Run `make validate` to check compliance
3. Review [Checklist](.gitlab/merge_request_templates/deployment.md)
4. Commit & Push changes
5. Create merge request if pipeline passes

## Questions?

Refer to:

- [Checklist](.gitlab/merge_request_templates/deployment.md) for detailed checklist
- [README.md](README.md) for setup and usage
- `.pre-commit-config.yaml` for validation rules
