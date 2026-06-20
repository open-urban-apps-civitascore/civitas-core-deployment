# Debugging Session: Keycloak Auth & NAT Loopback
**Date:** 2026-06-20

## 1. The Core Problem: Hairpinning (NAT Loopback)
In a local/cloud Kubernetes environment (specifically noted with Infomaniak), the external IP of the cluster (`37.156.42.200`) is assigned to the LoadBalancer. 
When a Pod *inside* the cluster (like `portal-frontend` or `portal-backend`) tries to send traffic to an external domain (`https://idm.civitas.test`) that resolves back to the cluster's own external IP, the network drops the packets. This is a known limitation called blocked NAT Loopback or Hairpinning.

**Symptoms:**
- The Next.js frontend threw `TypeError: fetch failed` when NextAuth tried to reach the Keycloak token endpoint.
- APISIX threw `503 Service Temporarily Unavailable` because the frontend was hanging on the token request until APISIX's proxy timeout was reached.

## 2. TLS Certificate Validation (Next.js)
Because the local environment uses self-signed certificates, Node.js (which powers Next.js) blocks the HTTPS connection to Keycloak by default.
**Solution:** We injected the environment variable `NODE_TLS_REJECT_UNAUTHORIZED: "0"` into the `portal-frontend` deployment to bypass strict certificate validation during development.

## 3. Bypassing External DNS with `hostAliases`
To prevent the Pods from routing traffic to the external LoadBalancer IP, we injected internal DNS overrides directly into the Pods' `/etc/hosts` files using Kubernetes `hostAliases`.

Instead of the external IP, we map the domains (`idm.civitas.test`, `portal.civitas.test`, etc.) to the **internal ClusterIP** of the `ingress-nginx-controller` (e.g., `10.103.12.151`).

**Retrieving the Internal IP:**
To find the correct IP for the patch, we ran:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}'
```

**Implementation:**
```yaml
spec:
  template:
    spec:
      hostAliases:
      - ip: "10.103.12.151" # Internal Ingress Controller ClusterIP
        hostnames:
        - "idm.civitas.test"
        - "portal.civitas.test"
        - "api.civitas.test"
        - "apicurio.civitas.test"
```
*Note: This patch was necessary for BOTH the `portal-frontend` (for NextAuth token exchange) and the `portal-backend` (for Spring Security JWT validation).*

## 4. APISIX Circuit Breaker & 503 Errors
We observed that the main HTML page loaded successfully (`/login`), but static Next.js assets (`_next/static/chunks/...`) and the NextAuth callback (`/api/auth/callback/keycloak`) failed with `503 Service Unavailable` from APISIX.

**Root Cause Analysis:**
If the Next.js frontend takes too long to respond (because the `fetch` to Keycloak hangs), APISIX's health check marks the entire `portal-bff` upstream as unhealthy. Once the Circuit Breaker trips, APISIX immediately returns `503` for *all* subsequent requests (including static CSS/JS files) for a short period.

## 5. Linkerd Service Mesh Interference (Current Hypothesis)
Even after patching the internal Ingress IP into the frontend, the token exchange still hung.
The `portal-frontend` Pod has a `linkerd-proxy` sidecar container injected. Linkerd transparently intercepts all outbound TCP traffic to negotiate mTLS (Mutual TLS). 
Since the `ingress-nginx-controller` is outside the Linkerd mesh and we are sending an opaque HTTPS request to its internal IP, the Linkerd proxy likely fails to establish the connection or routes it incorrectly.

**Next Action:** 
Temporarily disable Linkerd injection on the `portal-frontend` Pod using the `linkerd.io/inject: disabled` annotation. This will allow the Node.js process to establish a direct, unintercepted TCP connection to the internal Ingress IP.
