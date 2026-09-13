{{/*
Expand the name of the chart.
*/}}
{{- define "omada-controller.name" -}}
{{- default (.Chart.Name | trimSuffix "-helm") .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "omada-controller.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default (.Chart.Name | trimSuffix "-helm") .Values.nameOverride }}
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
{{- define "omada-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "omada-controller.labels" -}}
helm.sh/chart: {{ include "omada-controller.chart" . }}
{{ include "omada-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "omada-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "omada-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "omada-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "omada-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the Gateway to use
*/}}
{{- define "omada-controller.gatewayName" -}}
{{- default (include "omada-controller.fullname" .) .Values.gatewayApi.gateway.name }}
{{- end }}

{{/*
Verify that the Gateway API CRDs are present in the cluster before rendering any Gateway API
resource, so an enabled but unsupported cluster fails early with a clear message instead of
failing on an unknown resource type during install.

Helm only knows which API versions are served when it can reach the cluster. `helm template` does
not, so either pass `--api-versions gateway.networking.k8s.io/v1` or set
`gatewayApi.checkCapabilities` to `false` when rendering the chart offline.
*/}}
{{- define "omada-controller.gatewayApiCapabilities" -}}
{{- if .Values.gatewayApi.checkCapabilities }}
{{- if not (.Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1") }}
{{- fail "gatewayApi.enabled is set to true but the Gateway API CRDs (gateway.networking.k8s.io/v1) are not available in this cluster. Install the Gateway API CRDs (see https://gateway-api.sigs.k8s.io/guides/#installing-gateway-api), or set gatewayApi.checkCapabilities to false if you are rendering the chart without access to a cluster." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Resolve the BackendTLSPolicy API version served by the cluster.

BackendTLSPolicy graduated to gateway.networking.k8s.io/v1 in Gateway API v1.4; v1.2 and v1.3
serve it as gateway.networking.k8s.io/v1alpha3. Falls back to v1 when Helm cannot reach a cluster
(`helm template` without `--api-versions`).
*/}}
{{- define "omada-controller.backendTLSPolicyApiVersion" -}}
{{- if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1/BackendTLSPolicy" -}}
gateway.networking.k8s.io/v1
{{- else if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1alpha3/BackendTLSPolicy" -}}
gateway.networking.k8s.io/v1alpha3
{{- else -}}
gateway.networking.k8s.io/v1
{{- end -}}
{{- end -}}
