# Model Atlas

[Model Atlas](https://gitlab.eclipse.org/eclipse/Fennec/model.atlas) is a component of the Eclipse Fennec project. It provides a REST API for working with EMF (Eclipse Modeling Framework) models and integrates with Apicurio Registry for schema management.

## Features

- REST API for EMF model management
- Integration with Apicurio Registry for schema storage
- Lightweight deployment with minimal resource requirements

## Dependencies

- **Apicurio Registry**: Model Atlas connects to Apicurio for schema management

## Configuration

| Value | Description | Default |
|-------|-------------|---------|
| `modelAtlas.modelAtlas.enabled` | Enable/disable the component | `true` |
| `modelAtlas.modelAtlas.subdomain` | Subdomain for ingress | `model-atlas` |
| `modelAtlas.modelAtlas.pathPrefix` | Path prefix for ingress | `/` |

## Deployment

Navigate to `deployment/` and run:

```bash
helmfile apply -i --selector component=modelAtlas
```
