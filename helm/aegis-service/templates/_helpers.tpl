{{- define "aegis-service.name" -}}
{{- .Values.name | default .Chart.Name -}}
{{- end -}}

{{- define "aegis-service.labels" -}}
app.kubernetes.io/name: {{ include "aegis-service.name" . }}
app.kubernetes.io/part-of: aegis
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "aegis-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aegis-service.name" . }}
{{- end -}}
