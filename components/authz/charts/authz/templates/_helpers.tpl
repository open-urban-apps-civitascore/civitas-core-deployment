{{/*
Expand the name of the chart.
*/}}
{{- define "authz.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "authz.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "authz.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "authz.labels" -}}
helm.sh/chart: {{ include "authz.chart" . }}
{{ include "authz.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "authz.selectorLabels" -}}
app.kubernetes.io/name: {{ include "authz.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
OPA specific labels
*/}}
{{- define "authz.opa.labels" -}}
{{ include "authz.labels" . }}
app.kubernetes.io/component: opa
{{- end }}

{{/*
OPA selector labels
*/}}
{{- define "authz.opa.selectorLabels" -}}
{{ include "authz.selectorLabels" . }}
app.kubernetes.io/component: opa
{{- end }}

{{/*
Authz specific labels
*/}}
{{- define "authz.authz.labels" -}}
{{ include "authz.labels" . }}
app.kubernetes.io/component: authz
{{- end }}

{{/*
Authz selector labels
*/}}
{{- define "authz.authz.selectorLabels" -}}
{{ include "authz.selectorLabels" . }}
app.kubernetes.io/component: authz
{{- end }}
