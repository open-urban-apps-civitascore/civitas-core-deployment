# Hello Add-on

A minimal add-on used to prove the CIVITAS AppStore install path end to end:
catalogue entry -> pull request -> operator review -> running component.

It serves one static page through nginx and needs nothing from the platform:
no database, no Keycloak client, no generated secrets. The only integration
point is the APISIX route, which also puts the host on the shared ingress and
into the `apisix-tls` certificate.

## What the operator gets

| Aspect | Value |
| --- | --- |
| Public address | `https://hello.<instance domain>` |
| Image | `nginxinc/nginx-unprivileged` (runs as a non-root user) |
| Resources | 1 replica, no persistence, no cluster-wide permissions |

## Removing it

Delete `deployment/addons/hello-addon/` and remove `hello-addon` from the
`components` list of the environment. Nothing else references it.

## Note on the image tag

`images.yaml` is the single source for the image and always wins over the
chart's own defaults. It pins a floating `stable-alpine` tag so the demo cannot
break when a version is retired; a production add-on should pin an exact
version or digest.
