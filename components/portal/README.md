# Portal

User-facing UI for the Civitas platform, consisting of a Next.js frontend and a Spring Boot backend.

## Features

- Web-based user interface for platform management
- SSO authentication via Keycloak integration
- Backend REST API with PostgreSQL database

## Dependencies

- **Keycloak**: Portal uses Keycloak for authentication and SSO
- **PostgreSQL**: Backend stores data in a PostgreSQL database

## Configuration

| Value | Description | Default |
|-------|-------------|---------|
| `portal.portal.enabled` | Enable/disable the component | `true` |
| `portal.portal.subdomain` | Subdomain for ingress | `portal` |
| `portal.portal.pathPrefix` | Path prefix for ingress | `/` |

## Deployment

Navigate to `deployment/` and run:

```bash
helmfile apply -i --selector component=portal
```
