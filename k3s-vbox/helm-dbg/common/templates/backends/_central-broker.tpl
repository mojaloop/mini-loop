{{/*
Get fully qualified kafka name.
*/}}
{{- define "common.backends.centralbroker.fullname" -}}
  {{- if .Values.kafka -}}
    {{- if .Values.kafka.fullnameOverride -}}
      {{- .Values.kafka.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "kafka" .Values.kafka.nameOverride -}}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- $name := default "kafka" .Values.kafka.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Get kafka port.
*/}}
{{- define "common.backends.centralbroker.port" -}}
  {{- default 9092 (default .Values.global.kafka.port .Values.kafka.port) -}}
{{- end -}}

{{/*
Get fully qualified kafka host.
*/}}
{{- define "common.backends.centralbroker.host" -}}
  {{- default (include "common.backends.centralbroker.fullname" .) (default .Values.global.kafka.host .Values.kafka.host) -}}
{{- end -}}
