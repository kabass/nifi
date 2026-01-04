{{/*
Expand the name of the chart.
*/}}
{{- define "nifi-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nifi-platform.fullname" -}}
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
{{- define "nifi-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nifi-platform.labels" -}}
helm.sh/chart: {{ include "nifi-platform.chart" . }}
{{ include "nifi-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nifi-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nifi-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Nifi labels
*/}}
{{- define "nifi-platform.nifi.labels" -}}
{{ include "nifi-platform.labels" . }}
app.kubernetes.io/component: nifi
{{- end }}

{{/*
Nifi Registry labels
*/}}
{{- define "nifi-platform.nifiRegistry.labels" -}}
{{ include "nifi-platform.labels" . }}
app.kubernetes.io/component: nifi-registry
{{- end }}

{{/*
ZooKeeper labels
*/}}
{{- define "nifi-platform.zookeeper.labels" -}}
{{ include "nifi-platform.labels" . }}
app.kubernetes.io/component: zookeeper
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nifi-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nifi-platform.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Nifi ZooKeeper connection string
*/}}
{{- define "nifi-platform.zookeeper.connectionString" -}}
{{- if .Values.nifi.cluster.zookeeper.external.enabled }}
{{- .Values.nifi.cluster.zookeeper.external.connectionString }}
{{- else }}
{{- printf "%s-zookeeper:2181" (include "nifi-platform.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Nifi cluster node identity
*/}}
{{- define "nifi-platform.nifi.nodeIdentity" -}}
{{- printf "nifi-node-%d" . }}
{{- end }}

