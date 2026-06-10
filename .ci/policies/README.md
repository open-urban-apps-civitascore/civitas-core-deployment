# Kyverno policies

Policies applied to the rendered helmfile output in CI (`scan-kyverno-policies`)
and locally via `just verify-policies`.

## Layout

| Path        | Applied to                              | Content                                                              |
| ----------- | --------------------------------------- | -------------------------------------------------------------------- |
| `base/`     | every environment (`local`, `production`) | security and hygiene baseline (capabilities, rootfs, probes, ingress) |
| `production/` | `production` rendering only (in addition to `base/`) | HA hardening (replicas, PDB, resources, rolling update)              |
| `tests/`    | `kyverno test .ci/policies` / `just test-policies` | good/bad fixtures and expected results for every rule                |

## Vendored upstream policies

`base/require-drop-all.yaml`, `base/require-ro-rootfs.yaml` and the four
`base/disallow-*.yaml` PSS baseline policies (privileged containers, host
namespaces, hostPath, hostPort) are vendored verbatim from
[kyverno/policies](https://github.com/kyverno/policies) at the commit pinned
in `vendor-upstream-policies.sh`. Do not edit them by hand; to update, bump
`UPSTREAM_REF` in the script and run `just vendor-policies`, then review the
diff and run `just test-policies`.

Known difference: the upstream `require-ro-rootfs` only validates
`spec.containers`, not init containers. The gap is pinned down by an explicit
fixture in `tests/` so an upstream change shows up as a test diff.

All other policies are project-specific and maintained here. Every rule must
have at least one passing and one failing fixture in `tests/` - a broken
JMESPath expression silently passes everything, which is exactly what the
test suite exists to catch.
