{{/*
Get MojaloopRole resourceKind.
*/}}
{{- define "common.backends.mojalooprole.resourceKind" -}}
  {{- default "MojaloopRole" (default .Values.global.mojalooprole.resourceKind .Values.mojalooprole.resourceKind) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceListKind.
*/}}
{{- define "common.backends.mojalooprole.resourceListKind" -}}
  {{- default "MojaloopRoleList" (default .Values.global.mojalooprole.resourceListKind .Values.mojalooprole.resourceListKind) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceGroup.
*/}}
{{- define "common.backends.mojalooprole.resourceGroup" -}}
  {{- default "mojaloop.io" (default .Values.global.mojalooprole.resourceGroup .Values.mojalooprole.resourceGroup) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceVersion.
*/}}
{{- define "common.backends.mojalooprole.resourceVersion" -}}
  {{- default "v1" (default .Values.global.mojalooprole.resourceVersion .Values.mojalooprole.resourceVersion) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceSingular.
*/}}
{{- define "common.backends.mojalooprole.resourceSingular" -}}
  {{- default "mojalooprole" (default .Values.global.mojalooprole.resourceSingular .Values.mojalooprole.resourceSingular) -}}
{{- end -}}

{{/*
Get MojaloopRole resourcePlural.
*/}}
{{- define "common.backends.mojalooprole.resourcePlural" -}}
  {{- default "mojalooproles" (default .Values.global.mojalooprole.resourcePlural .Values.mojalooprole.resourcePlural) -}}
{{- end -}}
