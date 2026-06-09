# System Test PoC

This directory contains a Robot Framework proof of concept for the dataset saga use case.

The setup is intentionally split into two layers:

- `tests/system/java`: Java remote library that talks to the backend and gateway.
- `tests/system/robot`: Robot suites that describe the open and restricted use cases in fine-grained steps.

## Run locally

```bash
bash tests/system/run-system-tests.sh
```

## Required environment variables

The defaults are tuned for the local development setup, but they can be overridden:

- `PORTAL_BACKEND_URL` or `API_BASE_URL`
- `KEYCLOAK_URL`
- `KEYCLOAK_REALM`
- `KEYCLOAK_CLIENT_ID`
- `APISIX_GATEWAY_URL` or `PUBLIC_GATEWAY_URL`
- `FROST_BASE_URL`
- `SYSTEM_TEST_AUTH_USER` or `AUTH_USER`
- `SYSTEM_TEST_AUTH_PASSWORD` or `AUTH_PASSWORD`
- `SYSTEM_TEST_REMOTE_PORT`

## What the PoC covers

- Open data publication flow
- Restricted data publication flow
- Data structure creation and release
- Datasource creation, patching, and release
- Dataset creation, pipeline creation, staging, and release
- Waiting for the async saga to complete
- Verifying the public route anonymously and with authentication
