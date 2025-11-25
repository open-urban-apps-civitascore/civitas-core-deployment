# Deployment Guideline

This docuemtation guides you throw the deployment process of Civitas Core V2.

# Preparation

First of all, there a few considerations to make before starting the deployment process.

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

# Secrets

Before deploying Civitas Core V2, you need to set up the following secrets:
(See "Managing Secrets" section below for instructions on creating and managing secrets.)

## Required Secrets

- **Keycloak SMTP Configuration**:
  - Secret Name: `keycloak-smtp`
  - Keys:
    - `host`: SMTP server host
    - `port`: SMTP server port
    - `from`: Email address for sending emails
    - `user`: SMTP username
    - `password`: SMTP password

# Deployment

## Environments

Last step before deploying is to configure your environment.

Update files inside environments/default or even create your own environment based on the default one.

## Deploying Civitas Core V2

To deploy Civitas Core V2, use the following command:

```bash
helmfile -f ./helmfile.d/ sync -e default
```

# Managing Secrets

### Create a Secret

To create a new secret:

```bash
kubectl create secret generic <SECRET_NAME> \
  --from-literal=<KEY_NAME>='<VALUE>' \
  -n <NAMESPACE>

# Example:
kubectl create secret generic keycloak-smtp \
  --from-literal=host='smtp.example.com' \
  --from-literal=port='587' \
  --from-literal=from='noreply@example.com' \
  --from-literal=user='noreply@example.com' \
  --from-literal=password='YOUR_SMTP_PASSWORD' \
  -n main-civitas-core-v2
```

**Parameters:**

- `<SECRET_NAME>`: Name of the Kubernetes secret
- `<KEY_NAME>`: Key within the secret
- `<VALUE>`: The actual secret value
- `<NAMESPACE>`: Target namespace for the secret

### Verify a Secret

To check if a secret exists:

```bash
kubectl get secret <SECRET_NAME> -n <NAMESPACE>
```

To view secret details (without revealing values):

```bash
kubectl describe secret <SECRET_NAME> -n <NAMESPACE>
```

### Update a Secret

To update an existing secret without deleting it:

```bash
kubectl create secret generic <SECRET_NAME> \
  --from-literal=<KEY_NAME>='<NEW_VALUE>' \
  -n <NAMESPACE> \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Delete a Secret

To delete a secret (e.g., to recreate it):

```bash
kubectl delete secret <SECRET_NAME> -n <NAMESPACE>
```

# Undeployment

## Mono-Namespace Undeployment

To undeploy Civitas Core V2 from a mono-namespace setup, use the following commands:

```bash
# Remove ressources
helmfile --environment <ENVIRONMENT> apply

# Delete namespace and CRDs (if applicable)
kubectl delete namespace <NAMESPACE>

# Remove CRDs manually:
kubectl delete crd $(kubectl get crd | grep cnpg.io | awk '{print $1}')
```
