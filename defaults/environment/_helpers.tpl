{{ define "civitas.namespace" }}
{{- if .global.singleNamespace -}}
  {{- .global.instanceSlug -}}
{{- else -}}
  {{- printf "%s-%s" .global.instanceSlug .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{ end }}

{{/* Configured namespace for the shared cluster operators, or empty when they run in */}}
{{/* the instance namespace. Precedence: */}}
{{/*   1. global.operators.namespace, if set (override per environment) */}}
{{/*   2. the multi-instance default "civitas-operators", whenever a dedicated deploy */}}
{{/*      layer is active (operators/instance entrypoints set deployLayer) */}}
{{/*   3. empty, for the legacy single-instance all-in-one deployment (deployLayer "") */}}
{{/* This is the single source of truth for the operator namespace; keep the literal */}}
{{/* default in sync with components/prepare/helmfile.yaml.gotmpl. */}}
{{ define "civitas.operatorNamespaceConfigured" }}
{{- $operators := .global.operators | default dict -}}
{{- if $operators.namespace -}}
  {{- $operators.namespace -}}
{{- else if ne (.deployLayer | default "") "" -}}
  {{- "civitas-operators" -}}
{{- end -}}
{{ end }}

{{/* Namespace to deploy the shared cluster operators into. */}}
{{/* Returns the configured operator namespace (see civitas.operatorNamespaceConfigured) */}}
{{/* when set, otherwise falls back to the instance namespace (legacy single-instance). */}}
{{ define "civitas.operatorNamespace" }}
{{- $configured := include "civitas.operatorNamespaceConfigured" (dict "global" .global "deployLayer" .deployLayer) | trim -}}
{{- if $configured -}}
  {{- $configured -}}
{{- else -}}
  {{- include "civitas.namespace" (dict "global" .global "suffix" .suffix) -}}
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
      {{- if $global -}}
        {{- tpl $content $global | fromYaml | toYaml | nindent 0 }}
      {{- else -}}
        {{- $content | fromYaml | toYaml | nindent 2 }}
      {{- end -}}
    {{- end }}
  {{- end }}
{{- end }}
