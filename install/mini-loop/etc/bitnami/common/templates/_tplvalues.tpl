{{/* vim: set filetype=mustache: */}}
{{/*
Renders a value that contains template.
Usage:
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "common.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{- define "common.tplvalues.renderToJson" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context | fromYaml | toPrettyJson |squote }}
    {{- else }}
        {{- tpl (.value | toYaml) .context | fromYaml | toPrettyJson }}
    {{- end }}
{{- end -}}
