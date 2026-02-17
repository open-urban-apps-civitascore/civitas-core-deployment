# Frost

A Complete Server implementation of the OGC SensorThings API

## Component dependencies

- secrets (for database credentials)
- postgres

## Deployment validation

A successful deployment can be tested by opening a shell in the pod and getting all Projects via the API:

```bash
curl localhost:8080/FROST-Server/v1.1/Projects
```
