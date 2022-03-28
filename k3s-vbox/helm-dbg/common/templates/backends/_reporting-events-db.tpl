{{/*
Get fully qualified reporting-events-db name.
*/}}
{{- define "common.backends.reportingEventsDB.fullname" -}}
  {{- if .Values.reportingEventsDB -}}
    {{- if .Values.reportingEventsDB.fullnameOverride -}}
      {{- .Values.reportingEventsDB.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "reporting-events-db" .Values.reportingEventsDB.nameOverride -}}
      {{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
    {{- end -}}
  {{- else -}}
    {{- $name := default "reporting-events-db" .Values.reportingEventsDB.nameOverride -}}
    {{ printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
  {{- end -}}
{{- end -}}

{{/*
Get reporting-events-db port.
*/}}
{{- define "common.backends.reportingEventsDB.port" -}}
  {{- default 3306 (default .Values.global.reportingEventsDB.port .Values.reportingEventsDB.port) -}}
{{- end -}}


{{/*
Get fully qualified reporting-events-db host.
*/}}
{{- define "common.backends.reportingEventsDB.host" -}}
  {{- default (include "common.backends.reportingEventsDB.fullname" .) (default .Values.global.reportingEventsDB.host .Values.reportingEventsDB.host) -}}
{{- end -}}

{{/*
Get reporting-events-db user.
*/}}
{{- define "common.backends.reportingEventsDB.user" -}}
  {{- default "nouser" (default .Values.global.reportingEventsDB.user .Values.reportingEventsDB.user) -}}
{{- end -}}

{{/*
Get reporting-events-db database.
*/}}
{{- define "common.backends.reportingEventsDB.database" -}}
  {{- default "nodatabase" (default .Values.global.reportingEventsDB.database .Values.reportingEventsDB.database) -}}
{{- end -}}

{{/*
Get fully qualified reporting-events-db secret.name
*/}}
{{- define "common.backends.reportingEventsDB.secret.name" -}}
  {{- default (include "common.backends.reportingEventsDB.fullname" .) (default .Values.global.reportingEventsDB.secret.name .Values.reportingEventsDB.secret.name) -}}
{{- end -}}

{{/*
Get fully qualified reporting-events-db secret.key
*/}}
{{- define "common.backends.reportingEventsDB.secret.key" -}}
  {{- default (include "common.backends.reportingEventsDB.fullname" .) (default .Values.global.reportingEventsDB.secret.key .Values.reportingEventsDB.secret.key) -}}
{{- end -}}
