{{/*
Get fully qualified keto name.
*/}}
{{- define "common.backends.keto.fullname" -}}
  {{- if .Values.keto -}}
    {{- if .Values.keto.fullnameOverride -}}
      {{- .Values.keto.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "keto" .Values.keto.nameOverride -}}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- $name := default "keto" .Values.keto.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Get keto read URL.
*/}}
{{- define "common.backends.keto.readURL" -}}
  {{- default "http://keto-read:80" (default .Values.global.keto.readURL .Values.keto.readURL) -}}
{{- end -}}

{{/*
Get keto write URL.
*/}}
{{- define "common.backends.keto.writeURL" -}}
  {{- default "http://keto-write:80" (default .Values.global.keto.writeURL .Values.keto.writeURL) -}}
{{- end -}}
