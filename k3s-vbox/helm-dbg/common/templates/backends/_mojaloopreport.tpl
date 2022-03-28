{{/*
Get MojaloopReport resourceKind.
*/}}
{{- define "common.backends.mojaloopreport.resourceKind" -}}
  {{- default "MojaloopReport" (default .Values.global.mojaloopreport.resourceKind .Values.mojaloopreport.resourceKind) -}}
{{- end -}}

{{/*
Get MojaloopReport resourceListKind.
*/}}
{{- define "common.backends.mojaloopreport.resourceListKind" -}}
  {{- default "MojaloopReportList" (default .Values.global.mojaloopreport.resourceListKind .Values.mojaloopreport.resourceListKind) -}}
{{- end -}}

{{/*
Get MojaloopReport resourceGroup.
*/}}
{{- define "common.backends.mojaloopreport.resourceGroup" -}}
  {{- default "mojaloop.io" (default .Values.global.mojaloopreport.resourceGroup .Values.mojaloopreport.resourceGroup) -}}
{{- end -}}

{{/*
Get MojaloopReport resourceVersion.
*/}}
{{- define "common.backends.mojaloopreport.resourceVersion" -}}
  {{- default "v1" (default .Values.global.mojaloopreport.resourceVersion .Values.mojaloopreport.resourceVersion) -}}
{{- end -}}

{{/*
Get MojaloopReport resourceSingular.
*/}}
{{- define "common.backends.mojaloopreport.resourceSingular" -}}
  {{- default "mojaloopreport" (default .Values.global.mojaloopreport.resourceSingular .Values.mojaloopreport.resourceSingular) -}}
{{- end -}}

{{/*
Get MojaloopReport resourcePlural.
*/}}
{{- define "common.backends.mojaloopreport.resourcePlural" -}}
  {{- default "mojaloopreports" (default .Values.global.mojaloopreport.resourcePlural .Values.mojaloopreport.resourcePlural) -}}
{{- end -}}
