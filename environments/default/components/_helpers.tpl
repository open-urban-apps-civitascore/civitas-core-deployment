{{ define "civitas.namespace" }}
{{- if .global.singleNamespace -}}
  {{- .global.instanceSlug -}}
{{- else -}}
  {{- printf "%s-%s" .global.instanceSlug .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{ end }}
