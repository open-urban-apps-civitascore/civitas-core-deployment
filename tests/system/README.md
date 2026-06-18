# Test PoC

This directory contains a Robot Framework proof of concept for the dataset saga use case and its reusable test library.

The setup is intentionally split into two layers:

- `tests/system/java`: Java remote library that talks to the backend and gateway.
- `tests/system/robot`: Robot suite `tu-001-hero-case.robot` with one Hero Case test case that composes the open and protected data paths from fine-grained `TC-xxx` building blocks. Frontend steps use the Robot Browser library with Playwright under the hood.
- `tests/system/TEST_LIBRARY.md`: initial English template for the GitLab-based test library with `TC-xxx` identifiers and Hero Case composition guidance.

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
- Browser-based frontend execution for dataset management with Playwright via Robot Browser
- Waiting for the async saga to complete
- Verifying the public route anonymously and with authentication
