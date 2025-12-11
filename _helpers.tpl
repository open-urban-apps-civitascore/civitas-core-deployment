{{- define "civitas.component" }}
{{- $componentData := (readFile "./component.yaml" | fromYaml) }}
releases:
  {{- $root := . }}
  {{- $component := $componentData.component }}
  {{- $parts :=  $componentData.parts }}
  {{- range $parts }}
  {{- $part := . }}
  {{- $releaseName := printf "%s-%s" $component $part.name }}
  - name: {{ $releaseName }}
    labels:
      release: {{ $releaseName }}
      {{- range $key, $value := (index $part "extraLabels" | default dict) }}
      {{ $key }}: {{ $value }}
      {{- end }}
    namespace: {{ index $root $component $part.name "namespace" }}
    chart: {{ index $root.charts $component $part.name "chart" }}
    version: {{ index $root.charts $component $part.name "version" }}
    createNamespace: true
    installed: {{ index $root $component $part.name "enabled" }}
    condition: {{ $component }}.{{ $part.name }}.enabled
    {{- if index $part "needs" }}
    needs:
      {{ range index $part "needs" }}
        {{- $items := splitList "." . -}}
        {{- $depComponent := index $items 0 -}}
        {{- $depPart := index $items 1 -}}
      - {{ index $root $depComponent $depPart "namespace" }}/{{ printf "%s-%s" $depComponent $depPart }}
      {{- end }}
    {{- end }}
    {{- if index $part "hooks" }}
    hooks:
      {{- range index $part "hooks" }}
      - {{ . }}
      {{- end }}
    {{- end }}
    values:
      - values/{{ $part.name }}-values.yaml.gotmpl
      - {{- index $root $component $part.name "rawValues" | default dict | toYaml | nindent 8 }}
  {{- end }}
---
commonLabels:
  component: {{ $componentData.component }}
{{- end }}
