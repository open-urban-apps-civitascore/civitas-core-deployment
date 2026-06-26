# Infomaniak Kubernetes Deployment Guide

## Context & Goal
The goal is to deploy the CIVITAS/CORE V2 platform onto a managed Kubernetes cluster hosted by Infomaniak for the Prototype Fund project. This documentation serves as a runbook and captures specific learnings, prerequisites, and steps required that deviate from or complement the standard `minikube` / `k3d` local development setups.

## Prerequisites & Cluster Setup
Unlike local development environments (which use scripts like `startup.sh`), a managed Infomaniak cluster requires some manual bootstrapping.

### 1. Node Pool Requirements
Infomaniak's managed Kubernetes provides a control plane, but you must manually provision a node pool (Instance Group) to run workloads.
- **Minimum for Production Profile:** At least 8 vCPUs and 32 GB RAM in total.
- **Recommended Setup:** 2x `A4-Ram16-Disk50-Perf1` instances (or `Disk80`). This provides high availability and sufficient storage for container images.

### 2. Missing Core Components (Ingress & Cert-Manager)
The default Infomaniak Kubernetes cluster does not come with an Ingress Controller or Cert-Manager pre-installed. These are strict requirements for CIVITAS/CORE to expose services and secure them with SSL.

**Installation Steps:**

1. **Install Ingress-Nginx:**
   ```bash
   helm upgrade --install ingress-nginx ingress-nginx \
     --repo https://kubernetes.github.io/ingress-nginx \
     --namespace ingress-nginx --create-namespace
   ```

2. **Install Cert-Manager:**
   ```bash
   helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
     --version v1.19.2 \
     --namespace cert-manager \
     --create-namespace \
     --set crds.enabled=true
   ```

3. **Configure ClusterIssuer:**
   Create a `cluster-issuer.yaml` file to configure Let's Encrypt for automatic SSL certificates:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: <YOUR_EMAIL>
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             ingressClassName: nginx
   ```
   Apply with `kubectl apply -f cluster-issuer.yaml`.

## Environment Configuration
Once the cluster prerequisites are met, create the environment configuration in the deployment repository.

1. **Create the environment directory:**
   ```bash
   mkdir -p deployment/environments/infomaniak
   ```

2. **Create the global configuration file:**
   Create `deployment/environments/infomaniak/global.yaml.gotmpl` with the following configuration:
   ```yaml
   global:
     domain: <your-domain.com>
     instanceSlug: infomaniak
     profile: production
     initialUserEmail: <your-email>
     ingress:
       clusterIssuer: 'letsencrypt-prod'
       ingressClass: 'nginx'
   ```

*To be continued as the deployment progresses...*
