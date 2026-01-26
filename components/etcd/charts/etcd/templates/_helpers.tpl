{{/*
Expand the name of the chart.
*/}}
{{- define "etcd.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "etcd.fullname" -}}
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
{{- define "etcd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "etcd.labels" -}}
helm.sh/chart: {{ include "etcd.chart" . }}
{{ include "etcd.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "etcd.selectorLabels" -}}
app.kubernetes.io/name: {{ include "etcd.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "etcd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "etcd.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the etcd client port
*/}}
{{- define "etcd.clientPort" -}}
{{- .Values.service.clientPort | default 2379 }}
{{- end }}

{{/*
Return the etcd peer port
*/}}
{{- define "etcd.peerPort" -}}
{{- .Values.service.peerPort | default 2380 }}
{{- end }}

{{/*
Generate the initial cluster string for etcd
*/}}
{{- define "etcd.initialCluster" -}}
{{- $fullname := include "etcd.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $peerPort := include "etcd.peerPort" . -}}
{{- $replicaCount := int .Values.replicas -}}
{{- $list := list -}}
{{- range $i := until $replicaCount -}}
{{- $list = append $list (printf "%s-%d=http://%s-%d.%s-headless.%s.svc.cluster.local:%s" $fullname $i $fullname $i $fullname $namespace $peerPort) -}}
{{- end -}}
{{- join "," $list -}}
{{- end }}

{{/*
Return the etcd image
*/}}
{{- define "etcd.image" -}}
{{- $registry := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" $registry $tag -}}
{{- end }}
