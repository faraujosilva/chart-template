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
################################################################################
# CLOUD PROVIDER DECISION ENGINE
# 
# Lógica inteligente para escolher AWS vs Azure baseado em:
#   1. Manual override (se .Values.infrastructure.cloudProvider definido)
#   2. Cost optimization (compara preços da cost matrix)
#   3. Cloud strategy (aws-preferred, azure-preferred, cost-optimized)
################################################################################
*/}}

{{/*
Get cloud provider baseado em cost optimization
Compara custos do flavor específico e escolhe o mais barato
*/}}
{{- define "app.cloudProvider" -}}
{{- if .Values.infrastructure.cloudProvider }}
  {{- .Values.infrastructure.cloudProvider }}
{{- else }}
  {{- $flavor := .Values.infrastructure.storage.flavor }}
  {{- $strategy := .Values.infrastructure.cloudStrategy | default "cost-optimized" }}
  {{- $awsCost := 0.0 }}
  {{- $azureCost := 0.0 }}
  
  {{- if eq $flavor "standard" }}
    {{- $awsCost = .Values.infrastructure.costMatrix.aws.standard }}
    {{- $azureCost = .Values.infrastructure.costMatrix.azure.standard }}
  {{- else if eq $flavor "premium" }}
    {{- $awsCost = .Values.infrastructure.costMatrix.aws.premium }}
    {{- $azureCost = .Values.infrastructure.costMatrix.azure.premium }}
  {{- else if eq $flavor "economy" }}
    {{- $awsCost = .Values.infrastructure.costMatrix.aws.economy }}
    {{- $azureCost = .Values.infrastructure.costMatrix.azure.economy }}
  {{- else if eq $flavor "archive" }}
    {{- $awsCost = .Values.infrastructure.costMatrix.aws.archive }}
    {{- $azureCost = .Values.infrastructure.costMatrix.azure.archive }}
  {{- else }}
    {{- $awsCost = .Values.infrastructure.costMatrix.aws.standard }}
    {{- $azureCost = .Values.infrastructure.costMatrix.azure.standard }}
  {{- end }}
  
  {{- if eq $strategy "cost-optimized" }}
    {{- if lt $awsCost $azureCost }}
      {{- "aws" }}
    {{- else }}
      {{- "azure" }}
    {{- end }}
  {{- else if eq $strategy "aws-preferred" }}
    {{- $threshold := mul $azureCost 1.1 }}
    {{- if le $awsCost $threshold }}
      {{- "aws" }}
    {{- else }}
      {{- "azure" }}
    {{- end }}
  {{- else if eq $strategy "azure-preferred" }}
    {{- $threshold := mul $awsCost 1.1 }}
    {{- if le $azureCost $threshold }}
      {{- "azure" }}
    {{- else }}
      {{- "aws" }}
    {{- end }}
  {{- else }}
    {{- "aws" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate S3 bucket name (DNS compliant)
Format: app-name-namespace-random
*/}}
{{- define "app.storageBucketName" -}}
{{- $name := include "app.fullname" . | lower | replace "_" "-" }}
{{- $namespace := .Release.Namespace | lower }}
{{- $random := randAlphaNum 8 | lower }}
{{- printf "%s-%s-%s" $name $namespace $random | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Generate Azure Storage Account name (alphanumeric, 3-24 chars)
Format: appnamespacerandom
*/}}
{{- define "app.storageAccountName" -}}
{{- $name := include "app.fullname" . | lower | replace "-" "" | replace "_" "" }}
{{- $namespace := .Release.Namespace | lower | replace "-" "" | replace "_" "" }}
{{- $random := randAlphaNum 6 | lower }}
{{- printf "%s%s%s" $name $namespace $random | trunc 24 }}
{{- end }}

{{/*
Get Azure Account Tier baseado no flavor
*/}}
{{- define "app.azureAccountTier" -}}
{{- $flavor := .Values.infrastructure.storage.flavor }}
{{- if eq $flavor "premium" }}
  {{- "Premium" }}
{{- else }}
  {{- "Standard" }}
{{- end }}
{{- end }}

{{/*
Get Azure Replication Type baseado no flavor e HA
*/}}
{{- define "app.azureReplicationType" -}}
{{- $flavor := .Values.infrastructure.storage.flavor }}
{{- if eq $flavor "premium" }}
  {{- "LRS" }}  # Premium só suporta LRS
{{- else if eq $flavor "standard" }}
  {{- "GRS" }}  # Geo-redundant para standard
{{- else }}
  {{- "LRS" }}  # Local redundant para economy/archive
{{- end }}
{{- end }}

{{/*
Calculate estimated monthly cost (USD)
*/}}
{{- define "app.estimatedCost" -}}
{{- $flavor := .Values.infrastructure.storage.flavor }}

{{- $provider := include "app.cloudProvider" . }}
{{- $costPerGB := 0.0 }}

{{- if eq $provider "aws" }}
  {{- if eq $flavor "standard" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.aws.standard }}
  {{- else if eq $flavor "premium" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.aws.premium }}
  {{- else if eq $flavor "economy" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.aws.economy }}
  {{- else if eq $flavor "archive" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.aws.archive }}
  {{- end }}
{{- else }}
  {{- if eq $flavor "standard" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.azure.standard }}
  {{- else if eq $flavor "premium" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.azure.premium }}
  {{- else if eq $flavor "economy" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.azure.economy }}
  {{- else if eq $flavor "archive" }}
    {{- $costPerGB = .Values.infrastructure.costMatrix.azure.archive }}
  {{- end }}
{{- end }}

{{/*
Parse storage flavor to get cloud provider (LEGACY - mantido para compatibilidade)
*/}}
{{- define "app.storageProvider" -}}
{{- include "app.cloudProvider" . }}
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
