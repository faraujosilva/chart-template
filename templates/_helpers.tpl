{{/*
Expand the name of the chart.
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "app.fullname" -}}
{{- if .Values.app.name }}
{{- .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.app.name }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform.io/team: {{ .Values.app.team | default "unknown" | quote }}
{{- if .Values.app.costCenter }}
platform.io/cost-center: {{ .Values.app.costCenter | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Workspace name for infrastructure resources
*/}}
{{- define "app.workspaceName" -}}
{{- printf "%s-%s" (include "app.fullname" .) .Release.Namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Parse storage flavor to get cloud provider
*/}}
{{- define "app.storageProvider" -}}
{{- $flavor := .Values.infrastructure.storage.flavor }}
{{- if hasPrefix "s3" $flavor }}
{{- "aws" }}
{{- else if hasPrefix "azure" $flavor }}
{{- "azure" }}
{{- else }}
{{- "aws" }}
{{- end }}
{{- end }}

{{/*
Parse database flavor to get cloud provider
*/}}
{{- define "app.databaseProvider" -}}
{{- $flavor := .Values.infrastructure.database.flavor }}
{{- if hasPrefix "rds" $flavor }}
{{- "aws" }}
{{- else if hasPrefix "azure" $flavor }}
{{- "azure" }}
{{- else }}
{{- "aws" }}
{{- end }}
{{- end }}

{{/*
Parse cache flavor to get cloud provider
*/}}
{{- define "app.cacheProvider" -}}
{{- $flavor := .Values.infrastructure.cache.flavor }}
{{- if hasPrefix "elasticache" $flavor }}
{{- "aws" }}
{{- else if hasPrefix "azure" $flavor }}
{{- "azure" }}
{{- else }}
{{- "aws" }}
{{- end }}
{{- end }}
