# Deployment Checklist

Short description of changes being merged:

Link to gitlab issue:

## Security Review

Before requesting review, ensure your changes follow the security guidelines:
- [ ] [DevOps/Infrastructure Security Guidelines](../../docs/deplyoment-standards.md#security--code-review)
- [ ] [SSDLC Requirements](../../../documentation/docs_v2/Development/Development%20Process/SSDLC_Distilled.md) (for Medium/High sensitivity changes)
- [ ] CI security checks pass

To ensure our deployments meet the required standards, please verify the following checklist before merging any changes:

## Required for All Deployments

- [ ] All chart versions are pinned (no `latest`)
- [ ] All image tags are pinned (no `latest`)
- [ ] CPU & memory requests and limits set
- [ ] Naming conventions followed (kebab-case for files/directories, camelCase for variables) - run `pre-commit run --all-files`
- [ ] Minimal customizations of helm charts - only override essential values
- [ ] Containers run as non-root with `readOnlyRootFilesystem`
- [ ] Secrets managed securely (no plaintext)
- [ ] Ingress with TLS via cert-manager (if applicable)

## Environment-Specific Requirements

### Production Environment

- [ ] Replicas: HorizontalPodAutoscaler (HPA) configured OR minimum 2 replicas set for stateless apps
- [ ] Resource configuration appropriate for production workload
- [ ] Rolling update strategy configured (where accessible): `maxUnavailable: 0`, `maxSurge: 25%`
- [ ] PodDisruptionBudget configured (where accessible): at least 1 pod available
- [ ] Graceful shutdown configured (where accessible): `terminationGracePeriodSeconds` + `preStop` hook
- [ ] Health probes configured (where accessible): startup, readiness, liveness for long-running apps (exclude jobs/init containers)
- [ ] RBAC/ServiceAccount with least privilege (if applicable)
- [ ] NetworkPolicy with default-deny and minimal allowed traffic (where accessible)
- [ ] Named ports in Services (where accessible)

### Development Environment

- [ ] Resources scaled down appropriately for development
- [ ] Replica count reduced as needed
- [ ] Consider using profile flag (`profile: dev`) in Helm charts for environment-specific configuration

## Custom Helm Charts Only

- [ ] Standard Kubernetes labels implemented: https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/

## Notes

- Items marked "(where accessible)" should be implemented when configuration access is available
- Items marked "(if applicable)" should be evaluated on a case-by-case basis
- Jobs and init containers are excluded from health probe requirements
