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
`*.dev3.civitas2.fw-web.space`: Not yet in use
`*.dev4.civitas2.fw-web.space`: Not yet in use
`*.dev5.civitas2.fw-web.space`: Not yet in use

## Repository Structure

> Relevant folders and files in the repository:

- `components/`: All files required for an individual component
  - `<component>/charts.yaml`: version and source of Helm charts
  - `<component>/images.yaml`: version and source of container images
  - `<component>/civitas-component.yaml`: High level definition of the component and its individual parts
  - `<component>/default-environment.yaml.gotmpl`: Default environment values for the component
  - `<component>/helmfile.yaml.gotmpl`: Helmfile template definition which renders `civitas-component.yaml` and `charts.yaml` into a Helmfile
  - `<component>/values/`: Helm values per component part
  - `<component>/charts/`: Custom Helm charts for the component (if any)
  - `<component>/databases.yaml.gotmpl/`: Required database definitions for the component (if any)
- `defaults/`: Default values for helm, global settings and the collection of component default environments
- `deployment/`: Folder where deployments can be defined (not part of this repository because they are deployment specific)
  - `addons/`: Additional not in the core included components for the deployment
  - `environments/`: Environment specific configuration for every environment
  - `helmfile.yaml`: Entry Helmfile for the deployment
- `docs/`: Documentation
- `template-component/`: Template for new components
- `tests/`: Test cases for components and deployments

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

### Security

- **Containers run as non-root** with `readOnlyRootFilesystem`
- **Secrets**: No plaintext secrets, use secure secret management
- **RBAC** (if applicable): ServiceAccount with least privilege where required
- **NetworkPolicy** (where accessible): Default-deny with minimal allowed traffic

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
