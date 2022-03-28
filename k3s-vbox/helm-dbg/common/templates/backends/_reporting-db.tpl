{{/*
Get fully qualified reportingDB name.
*/}}
{{- define "common.backends.reportingDB.fullname" -}}
  {{- if .Values.reportingDB -}}
    {{- if .Values.reportingDB.fullnameOverride -}}
      {{- .Values.reportingDB.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "reporting-db" .Values.reportingDB.nameOverride -}}
      {{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
    {{- end -}}
  {{- else -}}
    {{- $name := default "reporting-db" .Values.reportingDB.nameOverride -}}
    {{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
  {{- end -}}
{{- end -}}

{{/*
Get reportingDB port.
*/}}
{{- define "common.backends.reportingDB.port" -}}
  {{- default 3306 (default .Values.global.reportingDB.port .Values.reportingDB.port) -}}
{{- end -}}


{{/*
Get fully qualified reportingDB host.
*/}}
{{- define "common.backends.reportingDB.host" -}}
  {{- default (include "common.backends.reportingDB.fullname" .) (default .Values.global.reportingDB.host .Values.reportingDB.host) -}}
{{- end -}}

{{/*
Get reportingDB user.
*/}}
{{- define "common.backends.reportingDB.user" -}}
  {{- default "nouser" (default .Values.global.reportingDB.user .Values.reportingDB.user) -}}
{{- end -}}

{{/*
Get reportingDB database.
*/}}
{{- define "common.backends.reportingDB.database" -}}
  {{- default "nodatabase" (default .Values.global.reportingDB.database .Values.reportingDB.database) -}}
{{- end -}}

{{/*
Get fully qualified reportingDB secret.name
*/}}
{{- define "common.backends.reportingDB.secret.name" -}}
  {{- default (include "common.backends.reportingDB.fullname" .) (default .Values.global.reportingDB.secret.name .Values.reportingDB.secret.name) -}}
{{- end -}}

{{/*
Get fully qualified reportingDB secret.key
*/}}
{{- define "common.backends.reportingDB.secret.key" -}}
  {{- default (include "common.backends.reportingDB.fullname" .) (default .Values.global.reportingDB.secret.key .Values.reportingDB.secret.key) -}}
{{- end -}}
