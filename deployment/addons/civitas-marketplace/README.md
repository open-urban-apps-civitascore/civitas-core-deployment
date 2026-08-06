# Marketplace addon

Deploys the Open Urban Apps marketplace (a Next.js app) next to a CIVITAS/CORE
instance, using the deployment repo's addon mechanism: because this directory
exists, the aggregation in `defaults/environment/*.yaml.gotmpl` reads
`keycloak-clients.yaml`, `secrets.yaml`, `charts.yaml`, `images.yaml` and
`default-environment.yaml.gotmpl` from here instead of `components/`.

To activate it, add `civitas-marketplace` to the `components` list of an
environment (e.g. `deployment/environments/infomaniak/global.yaml.gotmpl`).

What the pipeline derives from these files:

- **Keycloak client** `marketplace` (confidential) with redirect URIs on
  `marketplace.<domain>` and the `apisix-validator` audience mapper, so APISIX
  token introspection accepts marketplace tokens.
- **Secrets**: `keycloak-client-marketplace` (client secret, auto-generated for
  every confidential client) and `marketplace-nextauth-secret` (session cookie
  encryption), both copied into the marketplace namespace.
- **APISIX route** `marketplace.<domain>` via the `apisix-routes.yaml` +
  `apisix-plugins.yaml` fragment pair (routes hard-reference a same-named
  plugin_config). The aggregated route also puts the host on the shared
  apisix ingress and into the apisix-tls certificate — the chart itself
  ships no ingress.

`charts/civitas-marketplace/` is vendored from the marketplace repo
(`civitas-marketplace/chart/`) — keep it in sync when the chart changes there.
