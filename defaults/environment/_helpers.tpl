{{ define "civitas.namespace" }}
{{- if .global.singleNamespace -}}
  {{- .global.instanceSlug -}}
{{- else -}}
  {{- printf "%s-%s" .global.instanceSlug .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{ end }}

{{ define "civitas.configFiles" }}
  {{/* Usage: {{ include "civitas.configFiles" (dict "components" .Values.components "file" "images.yaml") }} */}}
  {{- $file := .file -}}
  {{- range .components }}
		{{- $component := . }}
		{{- $addonPath := printf "../../deployment/addons/%s" $component }}
		{{- $componentPath := printf "../../components/%s/%s" $component $file }}
		{{- $filePath := $componentPath }}
	  {{- if isDir $addonPath }}
	    {{- $filePath = printf "%s/" $addonPath $file }}
		{{- end }}
		{{- if isFile $filePath -}}
	{{- readFile $filePath | fromYaml | toYaml | nindent 2 }}
		{{- end }}
	{{- end }}
{{- end }}
