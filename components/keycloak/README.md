# Keycloak

Central identity management of the platform

Next steps:
1. Configure helm charts in `components/keycloak/charts.yaml.gotmpl`
2. Configure values for every release in `components/keycloak/values`
3. Update your README.md

Deploy the component with:
$  helmfile apply -i --selector component=keycloak -f helmfile.yaml.gotmpl
