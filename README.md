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

## Adding a new component

To add a new component to the deployment, [copier](https://copier.readthedocs.io/en/stable/) is used to scaffold the necessary files.
Ensure you have `copier` installed in your environment.

To add a new component run the following command, and after you filled in the prompts, follow the instructions printed in the end.

```bash
make new-component
```

## Updating components to the latest template versions

To update existing components to the latest template versions, use the following command:

```bash
make update-components
```

## Local Deployment

To deploy the entire infrastructure locally using Minikube, run the following commands:

```bash
minikube start
minikube addons enable ingress
# in the deployment directory
helmfile -f helmile.yaml sync -e local
# or (when CRDs are already installed)
helmfile -f helmile.yaml apply -e local
```
