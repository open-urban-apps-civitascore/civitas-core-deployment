{{ define "civitas.namespace" }}
{{- if .global.singleNamespace -}}
  {{- .global.instanceSlug -}}
{{- else -}}
  {{- printf "%s-%s" .global.instanceSlug .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{ end }}

{{ define "civitas.configFiles" }}
  {{/* Usage: {{ include "civitas.configFiles" (dict "components" .Values.components "file" "images.yaml") }} */}}
  {{/* For gotmpl files that need template rendering, pass "global" context: */}}
  {{/* {{ include "civitas.configFiles" (dict "components" .Values.components "file" "default-environment.yaml.gotmpl" "global" .) }} */}}
  {{- $file := .file -}}
  {{- $global := index . "global" | default dict -}}
  {{- range .components }}
    {{- $component := . }}
    {{- $addonPath := printf "../../deployment/addons/%s" $component }}
    {{- $componentPath := printf "../../components/%s/%s" $component $file }}
    {{- $filePath := $componentPath }}
    {{- if isDir $addonPath }}
      {{- $filePath = printf "%s/%s" $addonPath $file }}
    {{- end }}
    {{- if isFile $filePath -}}
      {{- $content := readFile $filePath -}}
      {{- if and $global (hasSuffix ".gotmpl" $file) -}}
        {{- tpl $content $global | fromYaml | toYaml | nindent 0 }}
      {{- else -}}
        {{- $content | fromYaml | toYaml | nindent 2 }}
      {{- end -}}
    {{- end }}
  {{- end }}
{{- end }}
