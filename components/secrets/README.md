# Secrets

Generating secrets for components which expect pre-configured secrets like admin passwords.

## Usage

For generating secrets in a component:
- Add a `secrets.yaml.gotmpl` file in the component directory with the desired secret keys and generation logic.

The structure of the `secrets.yaml.gotmpl` file should follow standard Helm templating conventions. For example:

```gotemplate
{{- $this := .Values.keycloak -}}
keycloak:
  app:
    {{ $this.app.admin.secret.name }}:
      {{ $this.app.admin.secret.passwordKey }}:
        length: 16  # Length of the generated password
        generate: true # Indicates that this value should be generated
```


Deploy the component with:
$ # navigate to `deployment/` and run:
$ helmfile apply -i --selector component=secrets
