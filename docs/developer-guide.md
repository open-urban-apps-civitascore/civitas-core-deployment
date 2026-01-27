# Developer Guide

Guide to work in this repository and maintain components.

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

## Configuring values

We work with Helm charts and therefore must primarily configure the components via Helm values.
These values are set `components/<component>/values/<part>-values.yaml.gotmpl` files.

### Connecting to Kafka Cluster

```yaml
bootstrapServers: "{{ .Values.kafka.cluster.bootstrapService }}:{{ .Values.kafka.cluster.bootstrapPort }}"
# TODO: auth, and tls config
```

### Connecting to Database

Create a file in `components/<component>/databases.yaml.gotmpl` with the following content:

```yaml
keycloak:
  name: 'keycloak'
  embedded: true  # set to false, if an external database is used
  user: 'keycloak'
  secret:
    name: 'db-keycloak'
    key: 'password'
  # TODO: different namespace does not yet work. Namespace of the cluster is not known, when rendering this.
  host: 'postgres-cluster-rw' # set to external hostname, if an external database is used
  port: 5432
```

You can access the credentials and connection details via the `.Values.databases.<component>` object like this:

```yaml
database:
  vendor: postgres
  hostname: {{ .Values.databases.keycloak.host }}
  port: {{ .Values.databases.keycloak.port }}
  database: {{ .Values.databases.keycloak.name }}
  username: {{ .Values.databases.keycloak.user }}
  existingSecret: {{ .Values.databases.keycloak.secret.name }}
  existingSecretKey: "password"
```

### Setting Docker Images

To adjust/set where a docker image is pulled from and which version is used, create a file in `components/<component>/images.yaml.gotmpl` with content like this:

```yaml
keycloak:
  app:
    repository: 'quay.io/keycloak/keycloak'
    tag: '26.4.0'
  configCli:
    repository: 'docker.io/adorsys/keycloak-config-cli'
    tag: '6.4.0-26'
```

You can access these values via the `.Values.images.<component>.<imageKey>` object like this:

```yaml
image:
  repository: {{ .Values.images.keycloak.app.repository }}
  tag: {{ .Values.images.keycloak.app.tag }}
```

### Generating Secrets

For generating and using secrets in a component, create a file in `components/<component>/secrets.yaml` with content like this:

```yaml
---
keycloak:
  app:
    keycloak-admin-user:  # name of the secret in kubernetes
      password: # key in the secret
        length: 16
        generate: true  # indicates that this value should be generated
```

Currently, you have to ensure that the secret name and key match what the component expects or is set in the values files.

### Exposing UIs and APIs

In the `components/<component>/default-environment.yaml.gotmpl` file add two new values under the part which is exposed:

```gotemplate
kafka:
  ui:
    enabled: true
    namespace: {{ include "civitas.namespace" (dict "global" .Values.global "suffix" "kafka") }}
    # subdomain to use for accessing the UI. Can be null/empty to use the base domain with path
    # pathPrefix is expected to start and end with /
    subdomain: kafka-ui
    pathPrefix: /
```

You can access these values via the `.Values.<component>.<part>` object like this:

```gotemplate
ingress:
  enabled: {{ $global.ingress.enabled }}
  annotations:
    cert-manager.io/cluster-issuer: {{ $global.ingress.clusterIssuer }}
  {{- $host := printf "%s.%s" (default "" $this.subdomain) $global.domain | trimPrefix "." }}
  host: {{ $host }}
  path: '{{ $this.pathPrefix }}'
  ingressClassName: {{ $global.ingress.ingressClass }}
```

### Connect with Keycloak

You can configure other components to connect to Keycloak by constructing the Keycloak URL based on the configured subdomain and path prefix.

```gotemplate
{{- $keycloakHost := printf "%s.%s" (default "" .Values.keycloak.app.subdomain) $global.domain | trimPrefix "." }}
{{- $keycloakPath := .Values.keycloak.app.pathPrefix -}}
{{- $keycloakUrl := printf "https://%s%s" $keycloakHost $keycloakPath -}}
{{- $realmName := $global.instanceSlug }}
authServerUrl: "{{ $keycloakUrl }}realms/{{ $realmName }}"
```

> TODO: Define how to create clients, roles etc. in Keycloak for other components.

### Configuring Resources

> TODO: This needs to be refined and account for different environments (dev, prod, ...).

For now: Set resource requests and limits directly in the `<part>-values.yaml.gotmpl` file of the component with sensible defaults.
Defaults should be appropriate for a development and test environment and not much more.

### Setting other values

Here some guidelines which should help setting other values:
- Prefer sensible defaults directly in the `<part>-values.yaml.gotmpl` file over setting many values in the `default-environment.yaml.gotmpl`
    These values can be overridden in the environment via `<component>.<part>.rawValues` if needed.
    We want to avoid too many values being set in the environment files to keep them clean and easy to read.
- Security relevant values must be secure by default. E.g. if TLS can be enabled/disabled, it must be enabled by default.
- Use the `global` values for settings which are relevant for multiple components.
