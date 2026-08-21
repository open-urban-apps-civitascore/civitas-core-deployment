# Geoportal Addon

Addon to add geoportal components to the CIVITAS/CORE Platform Version 2.

Components are:
- Masterportal: Open-Source Geoportal. [Official website](https://www.masterportal.org/)
- Portal Backend: Backend for authorization and config handling
- Mapfish print: A component of MapFish for printing templated cartographic maps.

## Installation

```bash
cd deployment/addons
# Clone repo into addons folder
# The folder should be name 'geoportal' and not 'deployment'. That's the second parameter
git clone git@gitlab.com:civitas-connect/civitas-core/civitas-core-v2/add-ons/geoportal/deployment.git geoportal
```

Add component to `deployment/environments/<environment>/global.yaml.gotmpl`

```yaml
components:
  - prepare
  - secrets
  - ... # all other components from the default
  - geoportal # added
```

## Bring your own Config

By default, this addon ships with demo configurations to work out of the box.
To configure it with your own settings, follow the following instructions.

### Build your own images

Fork the [template repository](https://gitlab.com/civitas-connect/civitas-core/civitas-core-v2/add-ons/geoportal/config-template), adjust it and build your own images.
The Repository already contains a GitLab Pipeline file, which builds all three images, so only Changes inside the `config` folder are required.

### Add the images to the deployment

Create a file `images.yaml.gotmpl` in your environment to override the images.

```yaml
  geoportal:
    backend:
      repository: registry.gitlab.com/<your_group>/civitas2-geoportal-demo/geoportal_backend
      tag: 1.0.0
    masterportal:
      repository: registry.gitlab.com/<your_group>/civitas2-geoportal-demo/geoportal_portal
      tag: 1.0.0
    mapfish:
      repository: registry.gitlab.com/<your_group>/civitas2-geoportal-demo/geoportal_mapfish
      tag: 1.0.0
```

### Adding images from a private registry

Add the dockerconfigjson secret to the namespace manually

```bash
kubectl create secret docker-registry <secret-name> --docker-server=<registry-url> --docker-username=<username> --docker-password=<password>
```

Set the imagePullSecret value for all images in your environment config. Either `global.yaml.gotmpl` or a dedicated file `geoportal.yaml.gotmpl`.

```yaml
geoportal:
  backend:
    rawValues:
      imagePullSecrets:
        - name: <secret-name>
  masterportal:
    rawValues:
      imagePullSecrets:
        - name: <secret-name>
  mapfish:
    rawValues:
      imagePullSecrets:
        - name: <secret-name>
```
