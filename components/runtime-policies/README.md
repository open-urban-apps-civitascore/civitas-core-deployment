# Runtime Kyverno policies

In-cluster Kyverno `ClusterPolicy` resources that enforce/report on things that
**only exist at runtime** — injected sidecars, namespace annotations applied by
the `prepare` hook, opt-out markers. They are deliberately **not** part of the
helmfile deployment.

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

Kyverno must be running **in the cluster**. This repo does not deploy it (it
only uses the `kyverno` CLI in CI). Install it separately, e.g. the upstream
Helm chart, before applying these policies.

## Deploy

```sh
# apply every policy in this directory (kubectl ignores README.md)
kubectl apply -f runtime-policies/

# check what is being flagged
kubectl get clusterpolicyreport,policyreport -A
kubectl describe clusterpolicyreport <name>
```

Or point a GitOps controller (Argo CD / Flux) at this directory — it has no
dependency on the helmfile release, so it can be reconciled independently.

## Enforcement level

Every policy ships with `validate.failureAction: Audit` — violations are
reported, nothing is blocked. Once a policy is clean in the reports, flip the
relevant rule to `Enforce` to block at admission.

> Caution with `Enforce` on `require-linkerd-sidecar`: if the Linkerd proxy
> injector is down, **no** Pod in a meshed namespace will admit. Keep it on
> `Audit` until injection is reliably healthy.

## Adding a policy

Drop a new `*.yaml` `ClusterPolicy` into this directory and re-apply — no other
file needs editing. Conventions to keep the set consistent:

- `background: true` so existing resources are scanned, not just new ones.
- `validate.failureAction: Audit` to start.
- Fill in the `policies.kyverno.io/*` annotations (title, category, severity,
  subject, description) as the existing policies do.
- Validate before committing (see below).

## Validate locally

```sh
# offline: works for policies that only read request.object
kyverno apply runtime-policies/<policy>.yaml --resource <fixture>.yaml

# policies that read the creating identity (restrict-*-operator-pod-labels,
# protect-operator-owned-labels) need a mocked userInfo offline:
kyverno apply runtime-policies/restrict-strimzi-operator-pod-labels.yaml \
  --resource pods.yaml --userinfo userinfo.yaml
# where userinfo.yaml is:
#   apiVersion: cli.kyverno.io/v1alpha1
#   kind: UserInfo
#   userInfo:
#     username: system:serviceaccount:<ns>:strimzi-cluster-operator

# policies using an apiCall context (e.g. require-linkerd-sidecar reads the
# namespace annotation) need a live cluster to resolve the context:
kyverno apply runtime-policies/require-linkerd-sidecar.yaml --cluster -n <ns>
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

## Inventory

| Policy                                    | Kind      | Flags when …                                                                                  |
| ----------------------------------------- | --------- | --------------------------------------------------------------------------------------------- |
| `require-linkerd-sidecar`                 | Pod       | a Pod in a `linkerd.io/inject=enabled` namespace has no `linkerd-proxy` (classic *or* native sidecar), unless it opted out with `linkerd.io/inject=disabled`. *(uses an apiCall context → needs a live cluster; the offline CLI cannot resolve it.)* |
| `require-meshed-namespace-inbound-policy` | Namespace | a `linkerd.io/inject=enabled` namespace does not set `config.linkerd.io/default-inbound-policy` (would fall back to all-unauthenticated). |
| `justify-linkerd-inject-opt-out`          | Pod       | a Pod sets `linkerd.io/inject=disabled` without a `mesh.civitas-core/opt-out-reason` annotation. |
| `restrict-strimzi-operator-pod-labels`    | Pod       | the `strimzi-cluster-operator` creates a Pod whose `app.kubernetes.io/name` is not a Strimzi component. *(admission-only, `background: false`)* |
| `restrict-cnpg-operator-pod-labels`       | Pod       | the CloudNativePG operator creates a Pod whose `app.kubernetes.io/name` is not a CNPG component. *(admission-only, `background: false`)* |
| `protect-operator-owned-labels`           | Pod       | a Pod carries an operator-owned authorization label but was not created by that operator: `app.kubernetes.io/name` ∈ {`kafka`,`entity-operator`,`postgresql`}, the bare `app` label (superset/frost — operators never set it), or `cnpg.io/jobRole`. *(admission-only, `background: false`)* |
