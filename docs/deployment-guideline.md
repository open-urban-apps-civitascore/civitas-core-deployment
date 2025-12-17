# Deployment Guideline

This documentation guides you through the deployment process of Civitas Core V2.

# Cluster Prerequisites

Ensure the following are installed and configured:

- **NGINX Ingress Controller** - `kubectl get ingressclass nginx`
- **cert-manager** with at least one ClusterIssuer (e.g., `letsencrypt-prod`) - `kubectl get clusterissuer`
- **Storage Class** with RWO support for PostgreSQL
- **DNS records** pointing to ingress endpoint for all configured domains
- **Metrics Server** (optional, required only if autoscaling enabled)

# Preparation

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

This projects allows to deploying to multiple environments like `testing`, `staging` or `production` or one environment per city.
Put all your configs in the directory `deployment` which is not tracked by this repo, so you can track your deployment configurations separately.
To deploy civitas core v2, follow the steps below.

## Setting up the Deployment Directory

1. Clone this repository to your local machine.
2. Navigate to the project directory
3. Add the `deployment` directory to your local copy of the repository.
4. Create a `helmfile.yaml` file in the `deployment` directory with the following content:

```yaml
---
environments:
  # empty environments must exist. When no environments are defined and one is set via CLI,
  # helmfile will error out.
  default:
    values: []
  local:
    values: []
  testing:
    values: []
---
helmfiles:
  - path: "../helmfile-root.yaml.gotmpl"
    values:
      - environments:
          - local
          - testing
```

Adjust the environments as needed.
For each environment you want:
1. create a folder inside `deployment/environments/` with the name of the environment
2. add an empty `global.yaml` file inside the environment folder.
3. Add it to the `helmfile.yaml` created in step 4. in the `environments` section with empty values.
4. Add it to the `helmfiles` section in the `values` list under `environments`.

## Configuring the Environment

Everything you don't overwrite in the environment config files will be taken from the default values defined in `defaults/environments/`.
1. For configuration start with the `defaults/environments/global.yaml` file and copy any values you want to overwrite into the `global.yaml` file of your environment.
2. If you want to configure component specific settings:
   - Create a new file named `<component-name>.yaml` in the environment folder and copy all values from the default-environment file you want to overwrite into it.
     - Now you have two options to adjust the values:
     - Adjusting values in the components default config file located at `components/<components>/default-environment.yaml.gotmpl` by overwriting them in the environment specific `<component-name>.yaml` file.
       ```yaml
       keycloak:
         app:
           enabled: false
       ```
     - Overwriting helm values directly in the environment specific `<component-name>.yaml` file, by adding them under `<component>/<release>/rawValues`.
        Example:
        ```yaml
        keycloak:
          app:
            rawValues:
              replicas: 3
        ```

## Deploying Civitas Core V2

To deploy Civitas Core V2, use the following command inside the `deployment` directory:

```bash
helmfile apply -i -e <ENVIRONMENT>
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
