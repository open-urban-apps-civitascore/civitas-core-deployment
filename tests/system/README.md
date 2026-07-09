# Test PoC

This directory contains a Robot Framework proof of concept for the dataset saga use case and its reusable test library.

The setup is intentionally split into two layers:

- `tests/system/java`: Java remote library that talks to the backend and gateway.
- `tests/system/robot`: Robot suite `tu-001-hero-case.robot` with one Hero Case test case that composes the open and protected data paths from fine-grained `TC-xxx` building blocks. Frontend steps use the Robot Browser library with Playwright under the hood.
- `tests/system/TEST_LIBRARY.md`: initial English template for the GitLab-based test library with `TC-xxx` identifiers and Hero Case composition guidance.

## Run locally

Locally you need Java 21, Maven, Python 3 and the Robot
Browser library:

```bash
python3 -m pip install robotframework -r tests/system/browser/requirements.txt
rfbrowser init
```

Against a local dev stack (defaults target `localhost`):

```bash
bash tests/system/run-system-tests.sh
```

### Run against a cluster

Point the endpoint env vars at the target cluster. Use public ingress URLs, or
`kubectl port-forward` the services and target `localhost`.

```bash
# Example: public ingress of a smoke-test/nightly environment
export API_BASE_URL=https://api.<slug>.<base-domain>/v1
export PORTAL_BACKEND_URL=https://portal.<slug>.<base-domain>/v1
export KEYCLOAK_URL=https://idm.<slug>.<base-domain>
export KEYCLOAK_REALM=civitas
export PORTAL_FRONTEND_URL=https://portal.<slug>.<base-domain>
export APISIX_GATEWAY_URL=https://api.<slug>.<base-domain>
export SYSTEM_TEST_AUTH_USER=admin@civitas.test
export SYSTEM_TEST_AUTH_PASSWORD=<password>

bash tests/system/run-system-tests.sh
```

### Runner flags

```bash
bash tests/system/run-system-tests.sh --help
```

- `--suite <path>` run a specific suite/dir (repeatable)
- `--include <tag>` / `--exclude <tag>` filter by tag (repeatable)
- `--results-dir <dir>` output directory
- `--remote-port <port>` Java remote-library port
- `--skip-build` reuse an already-built Java jar

## Required environment variables

The defaults are tuned for the local development setup, but they can be overridden:

- `PORTAL_BACKEND_URL`
- `KEYCLOAK_URL`
- `KEYCLOAK_REALM`
- `KEYCLOAK_CLIENT_ID`
- `APISIX_GATEWAY_URL` or `PUBLIC_GATEWAY_URL`
- `PORTAL_FRONTEND_URL`
- `FROST_BASE_URL`
- `SYSTEM_TEST_AUTH_USER` or `AUTH_USER`
- `SYSTEM_TEST_AUTH_PASSWORD` or `AUTH_PASSWORD`
- `SYSTEM_TEST_REMOTE_PORT`

Frontend browser execution additionally requires the `robotframework-browser` package and a browser initialization step (`rfbrowser init`) in the local environment or CI image.

## What the PoC covers

- Open data publication flow
- Restricted data publication flow
- Data structure creation and release
- Datasource creation, patching, and release
- Dataset creation, pipeline creation, staging, and release
- Geo pipeline creation, OWS API configuration, and layer metadata validation
- Browser-based frontend execution for dataset management with Playwright via Robot Browser
- Waiting for the async saga to complete
- Verifying the public route anonymously and with authentication
