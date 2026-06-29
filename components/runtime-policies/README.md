# Runtime Kyverno policies

In-cluster Kyverno `ClusterPolicy` resources that enforce/report on things that
**only exist at runtime** — injected sidecars, namespace annotations applied by
the `prepare` hook, opt-out markers, dynamically created operator Pods. They are
shipped as the `runtime-policies` helmfile component (a small Helm chart under
`charts/runtime-policies/`) and deployed alongside the rest of the platform.

## Why separate from `.ci/policies/`

`.ci/policies/` is a *shift-left* scan: `kyverno apply` runs against the static
`helmfile template` output (see `.ci/policies/README.md`). That output does
**not** contain the `linkerd-proxy` sidecar — Linkerd injects it at admission
time via its mutating webhook — nor the namespace annotations set by the
`prepare` hook. A "require sidecar" check therefore cannot live in the
shift-left pipeline; it has to run against **live** cluster state.

These policies are evaluated by Kyverno *in the cluster*:

- **Admission** — new Pods/Namespaces are checked on create/update. Linkerd's
  mutating injector runs before Kyverno's validating webhook, so the proxy is
  already present when these policies evaluate.
- **Background** (`background: true`) — existing resources are re-scanned and
  surfaced as `PolicyReport` / `ClusterPolicyReport` objects.

## Prerequisite

Kyverno must be running **in the cluster** — this chart only ships the
`ClusterPolicy` objects, not Kyverno itself. Both the smoke-test CI and the local
`just deploy` bootstrap it via `.ci/kyverno/helmfile.yaml.gotmpl`
(`scripts/ci/install-kyverno-if-missing.sh`, idempotent). To install it
standalone — e.g. on a cluster you sync into manually — run:

```sh
just kyverno   # or: helmfile -f .ci/kyverno/helmfile.yaml.gotmpl sync
```

## Deploy

The policies are deployed by the `runtime-policies` helmfile component (listed in
`components:` in `defaults/environment/global.yaml`). Two global knobs in
`global.runtimePolicies` control it:

```yaml
global:
  runtimePolicies:
    enabled: true        # set the release's `installed:` flag
    failureAction: Audit # Audit (report only) or Enforce (block at admission)
```

The Linkerd policies additionally switch on automatically only when the Linkerd
service mesh is enabled (`global.serviceMesh.type: linkerd`). It is deployed with
the rest of the platform:

```sh
helmfile -f ./deployment/ sync
```

Inspect what is being flagged:

```sh
kubectl get clusterpolicyreport,policyreport -A
kubectl describe clusterpolicyreport <name>
```

To deploy the raw policies outside helmfile (e.g. a GitOps controller or a quick
manual apply), render them through the chart first so the `failureAction`
placeholder is resolved — `kubectl apply` against the raw `files/` would apply
the literal `KYVERNO_FAILURE_ACTION` placeholder:

```sh
helm template ./charts/runtime-policies | kubectl apply -f -
```

## Enforcement level

Every policy ships with `validate.failureAction: Audit` — violations are
reported, nothing is blocked. Once a policy is clean in the reports, flip the
relevant rule to `Enforce` to block at admission.

> Caution with `Enforce` on `require-linkerd-sidecar`: if the Linkerd proxy
> injector is down, **no** Pod in a meshed namespace will admit. Keep it on
> `Audit` until injection is reliably healthy.

## Adding a policy

Drop a new `*.yaml` `ClusterPolicy` into `charts/runtime-policies/files/` and
reference it from the matching template so it is rendered into the release:

- `templates/linkerd-policies.yaml` (gated by `.Values.linkerd.enabled`), or
- `templates/operator-policies.yaml` (gated by `.Values.operators.enabled`).

Each template line wraps the file with the failure-action placeholder, e.g.:

```gotmpl
{{ .Files.Get "files/<policy>.yaml" | replace "KYVERNO_FAILURE_ACTION" .Values.failureAction }}
```

Conventions to keep the set consistent:

- Use `failureAction: KYVERNO_FAILURE_ACTION` (the template substitutes the
  configured value) rather than hard-coding `Audit`/`Enforce`.
- `background: true` so existing resources are scanned, not just new ones —
  unless the rule reads `request.userInfo` (admission-only → `background: false`).
- Fill in the `policies.kyverno.io/*` annotations (title, category, severity,
  subject, description) as the existing policies do.
- Validate before committing (see below).

## Validate locally

The `files/` policies carry the literal `KYVERNO_FAILURE_ACTION` placeholder, so
render them through the chart first (or substitute the placeholder) before
feeding them to the `kyverno` CLI:

```sh
helm template ./charts/runtime-policies --show-only templates/operator-policies.yaml > /tmp/policies.yaml

# offline: works for policies that only read request.object
kyverno apply /tmp/policies.yaml --resource <fixture>.yaml

# policies that read the creating identity (restrict-*-operator-pod-labels,
# protect-operator-owned-labels) need a mocked userInfo offline:
kyverno apply /tmp/policies.yaml \
  --resource pods.yaml --userinfo userinfo.yaml
# where userinfo.yaml is:
#   apiVersion: cli.kyverno.io/v1alpha1
#   kind: UserInfo
#   userInfo:
#     username: system:serviceaccount:<ns>:strimzi-cluster-operator

# policies using an apiCall context (e.g. require-linkerd-sidecar reads the
# namespace annotation) need a live cluster to resolve the context:
kyverno apply /tmp/policies.yaml --cluster -n <ns>
```

## Protecting against NetworkPolicy label spoofing

The cluster's NetworkPolicies authorize traffic by the `app.kubernetes.io/name`
label (e.g. only pods labelled `apisix` may reach the data plane). Any actor
able to create a Pod with an arbitrary label can therefore impersonate another
workload and inherit its network reachability. Statically deployed workloads are
reviewed in CI (`.ci/policies`, rendered manifests), but **operators create Pods
dynamically at runtime** and bypass that review — so they are the main spoofing
risk. Two complementary controls, both keyed on the *creating identity*
(`request.userInfo`, admission-only — hence `background: false`):

- **Forward** (`restrict-*-operator-pod-labels`): an operator may only set
  `app.kubernetes.io/name` to its own components — it can't claim `portal`,
  `apisix`, etc. The SA name is extracted namespace-agnostically via
  `split(request.userInfo.username, ':') | [-1]`.
- **Reverse** (`protect-operator-owned-labels`): an operator-owned value
  (`kafka`, `entity-operator`, `postgresql`) may only be set by a Pod that
  operator created — any other creator claiming it is denied.

> The operators' *own* pods (`strimzi-kafka-operator`, `cloudnative-pg`) are
> created by the Helm Deployment via kube-controller-manager, not by the operator
> SA, so those values are deliberately left out of the reverse policy to avoid
> false positives. Extend both the allowlists and the protected-value sets when
> you enable more Strimzi features (kafka-connect, cruise-control, …) or add an
> operator — copy a `restrict-*-operator-pod-labels.yaml` as the template.
