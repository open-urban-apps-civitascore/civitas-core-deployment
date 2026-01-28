# CIVITAS Core Deployment

Helmfile-based deployment for CIVITAS infrastructure.

## Pre-commit Setup

**macOS:**

```bash
brew install pre-commit yamllint
```

**Linux:**

```bash
pip install pre-commit yamllint
```

## Usage

```bash
make validate         # Run all validations
```

## Deployment standards

Please refer to the [Deployment Standards](docs/deployment-standards.md) for the project standards and resulting [Checklist](docs/deployment-checklist.md) to be met before merging any changes.

## Local Deployment

To deploy the entire infrastructure locally using Minikube, run the following commands:

```bash
minikube start
minikube addons enable ingress

# copy the default deployment and adjust it if needed
# the deployment directory is in .gitignore and can be its own git repo
cp -r default/deployment deployment
cd deployment
# in the deployment directory
helmfile -f helmile.yaml sync -e local
# or (when CRDs are already installed)
helmfile -f helmile.yaml apply -e local
```
