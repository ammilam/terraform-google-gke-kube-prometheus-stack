{{/*
Expand the name of the chart.
*/}}
{{- define "gcp-ingress-configs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gcp-ingress-configs.fullname" -}}
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
{{- define "gcp-ingress-configs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gcp-ingress-configs.labels" -}}
helm.sh/chart: {{ include "gcp-ingress-configs.chart" . }}
{{ include "gcp-ingress-configs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gcp-ingress-configs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gcp-ingress-configs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the BackendConfig to use
*/}}
{{- define "gcp-ingress-configs.BackendConfigName" -}}
{{- if .Values.BackendConfig.create }}
{{- default (include "gcp-ingress-configs.fullname" .) .Values.BackendConfig.name }}
{{- else }}
{{- default "default" .Values.BackendConfig.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the FrontendConfig to use
*/}}
{{- define "gcp-ingress-configs.FrontendConfigName" -}}
{{- if .Values.FrontendConfig.create }}
{{- default (include "gcp-ingress-configs.fullname" .) .Values.FrontendConfig.name }}
{{- else }}
{{- default "default" .Values.FrontendConfig.name }}
{{- end }}
{{- end }}
