{{- define "civitas.componentReleases" }}
releases:
  {{- $root := . }}
  {{- $component := .Component }}
  {{- $parts := .Parts }}
  {{- range $parts }}
  {{- $part := . }}
  - name: {{ printf "%s-%s" $component $part }}
    labels:
      release: {{ $part }}
      {{- with (index $root.SpecialLabels $part) }}
      {{- . | toYaml | nindent 6 }}
      {{- end }}
    namespace: {{ index $root.AllHelmfileValues $component $part "namespace" }}
    chart: {{ index $root.AllHelmfileValues.charts $component $part "chart" }}
    version: {{ index $root.AllHelmfileValues.charts $component $part "version" }}
    createNamespace: true
    installed: {{ index $root.AllHelmfileValues $component $part "enabled" }}
    values:
      - values/{{ $part }}-values.yaml.gotmpl
      - {{ index $root.AllHelmfileValues $component $part "rawValues" | default dict | toYaml | nindent 8 }}
  {{- end }}
{{- end }}
