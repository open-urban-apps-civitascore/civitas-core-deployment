{{- define "civitas.component" }}
{{- $componentData := (readFile "./releases.yaml" | fromYaml) }}
releases:
  {{- $root := . }}
  {{- $component := $componentData.component }}
  {{- $parts :=  $componentData.parts }}
  {{- range $parts }}
  {{- $part := . }}
  - name: {{ printf "%s-%s" $component $part.name }}
    labels:
      release: {{ $part.name }}
      {{ range $key, $value := (index $part "extraLabels" | default dict) }}
      {{ $key }}: {{ $value }}
      {{- end }}
    namespace: {{ index $root $component $part.name "namespace" }}
    chart: {{ index $root.charts $component $part.name "chart" }}
    version: {{ index $root.charts $component $part.name "version" }}
    createNamespace: true
    installed: {{ index $root $component $part.name "enabled" }}
    values:
      - values/{{ $part.name }}-values.yaml.gotmpl
      - {{ index $root $component $part.name "rawValues" | default dict | toYaml | nindent 8 }}
  {{- end }}
{{- end }}


{{- define "civitas.release" }}
  {{- $root := . }}
  {{- $component := .Component }}
  {{- $part := .Part }}
  {{- $labels := .ExtraLabels }}
name: {{ printf "%s-%s" $component $part }}
labels:
  release: {{ $part }}
  {{ $labels | toYaml }}
namespace: {{ index $root.AllHelmfileValues $component $part "namespace" }}
chart: {{ index $root.AllHelmfileValues.charts $component $part "chart" }}
version: {{ index $root.AllHelmfileValues.charts $component $part "version" }}
createNamespace: true
installed: {{ index $root.AllHelmfileValues $component $part "enabled" }}
values:
  - values/{{ $part }}-values.yaml.gotmpl
  - {{ index $root.AllHelmfileValues $component $part "rawValues" | default dict | toYaml | nindent 4 }}
{{- end }}
