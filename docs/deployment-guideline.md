# Deployment Guideline

> TOOD: review and put into public docs

First of all, there are a few considerations to make before starting the deployment process.

### Mono vs. Multi-Namespace Deployment

You can either deploy Civitas Core V2 in a single namespace (mono-namespace) or in multiple namespaces (multi-namespace). The choice depends on your requirements regarding isolation, security, and management.

Requirements:

Mono-Namespace Deployment:

- **With cluster-wide permissions:**

  - Ability to create namespaces
  - Ability to install CRDs (Custom Resource Definitions)
  - Ability to create all Kubernetes resources (cluster-wide and namespace-scoped)
  - The deployment will automatically install CloudNativePG operator and CRDs

- **With namespace-only permissions:**
  - Pre-installed CloudNativePG CRDs (version 0.26.0 as specified in configuration)
  - Pre-installed CloudNativePG operator accessible to your namespace (can be installed cluster-wide by admin)
  - Permission to create namespace-scoped resources in your target namespace:
    - Pods, Services, Secrets, ConfigMaps
    - PersistentVolumeClaims (PVCs)
    - StatefulSets, Deployments
  - Sufficient resource quota allocated to your namespace
  - Note: CRDs are cluster-scoped resources and cannot be installed without cluster-admin privileges

**Multi-Namespace Deployment:**

- Full cluster-admin rights are required to create cluster-scoped resources (e.g., CloudNativePG operator + CRDs).
