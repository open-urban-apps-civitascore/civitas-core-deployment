# Grafana

Analytics and visualization dashboards

## Prerequisites

- CIVITAS/CORE 2.0 or later (required for automatic Keycloak client role creation)

## Quickstart

Add the Grafana addon to your CIVITAS/CORE v2 repository as a submodule.

```bash
cd civitas-core-deployment/deployment/addons/
git submodule add https://gitlab.com/civitas-connect/civitas-core/civitas-core-v2/add-ons/grafana.git
```

Add the component to your

- global (`deployment/environments/global.yaml`) or
- environment-specific (`deployment/environments/<env>/global.yaml.gotmpl`)

list of components.

```yaml
components:
  - ...
  - grafana
```

Run Helmfile to apply the change to your deployment.

```bash
$ helmfile -f deployment/helmfile.yaml apply -e <env>
```

## Roles

Assign the desired roles to users or groups in Keycloak.

| Role | Description |
|------|-------------|
| `grafanaServerAdmin` | Full server administration access, including plugin installation |
| `grafanaAdmin` | Organization administrator access |
| `grafanaEditor` | Can create and edit dashboards |
| `grafanaViewer` | Read-only access to dashboards |
