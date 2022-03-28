{{/*
Get fully qualified Mojaloop adminApiSvc name.
*/}}
{{- define "common.backends.mojaloop.adminApiSvc.fullname" -}}
  {{- if .Values.kafka -}}
    {{- if .Values.adminApiSvc.fullnameOverride -}}
      {{- .Values.adminApiSvc.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "admin-api-svc" .Values.adminApiSvc.nameOverride -}}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- $name := default "admin-api-svc" .Values.adminApiSvc.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Get Mojaloop adminApiSvc port.
*/}}
{{- define "common.backends.mojaloop.adminApiSvc.port" -}}
  {{- default 80 (default .Values.global.adminApiSvc.port .Values.adminApiSvc.port) -}}
{{- end -}}

{{/*
Get fully qualified Mojaloop adminApiSvc host.
*/}}
{{- define "common.backends.mojaloop.adminApiSvc.host" -}}
  {{- default (include "common.backends.mojaloop.adminApiSvc.fullname" .) (default .Values.global.adminApiSvc.host .Values.adminApiSvc.host) -}}
{{- end -}}

{{/*
Get fully qualified Mojaloop settlementSvc name.
*/}}
{{- define "common.backends.mojaloop.settlementSvc.fullname" -}}
  {{- if .Values.kafka -}}
    {{- if .Values.settlementSvc.fullnameOverride -}}
      {{- .Values.settlementSvc.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "settlement-svc" .Values.settlementSvc.nameOverride -}}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- $name := default "settlement-svc" .Values.settlementSvc.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Get Mojaloop settlementSvc port.
*/}}
{{- define "common.backends.mojaloop.settlementSvc.port" -}}
  {{- default 80 (default .Values.global.settlementSvc.port .Values.settlementSvc.port) -}}
{{- end -}}

{{/*
Get fully qualified Mojaloop settlementSvc host.
*/}}
{{- define "common.backends.mojaloop.settlementSvc.host" -}}
  {{- default (include "common.backends.mojaloop.settlementSvc.fullname" .) (default .Values.global.settlementSvc.host .Values.settlementSvc.host) -}}
{{- end -}}
