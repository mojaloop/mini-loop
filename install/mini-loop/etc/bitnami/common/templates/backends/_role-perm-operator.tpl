{{/*
Get fully qualified role operator name.
*/}}
{{- define "common.backends.rolePermOperator.fullname" -}}
  {{- if .Values.rolePermOperator -}}
    {{- if .Values.rolePermOperator.fullnameOverride -}}
      {{- .Values.rolePermOperator.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $name := default "security-role-perm-operator-svc" .Values.rolePermOperator.nameOverride -}}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- $name := default "security-role-perm-operator-svc" .Values.rolePermOperator.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Get MojaloopRole resourceKind.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopRole.resourceKind" -}}
  {{- default "MojaloopRole" (default .Values.global.rolePermOperator.mojaloopRole.resourceKind .Values.rolePermOperator.mojaloopRole.resourceKind) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceListKind.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopRole.resourceListKind" -}}
  {{- default "MojaloopRoleList" (default .Values.global.rolePermOperator.mojaloopRole.resourceListKind .Values.rolePermOperator.mojaloopRole.resourceListKind) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceGroup.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopRole.resourceGroup" -}}
  {{- default "mojaloop.io" (default .Values.global.rolePermOperator.mojaloopRole.resourceGroup .Values.rolePermOperator.mojaloopRole.resourceGroup) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceVersion.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopRole.resourceVersion" -}}
  {{- default "v1" (default .Values.global.rolePermOperator.mojaloopRole.resourceVersion .Values.rolePermOperator.mojaloopRole.resourceVersion) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceSingular.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopRole.resourceSingular" -}}
  {{- default "mojalooprole" (default .Values.global.rolePermOperator.mojaloopRole.resourceSingular .Values.rolePermOperator.mojaloopRole.resourceSingular) -}}
{{- end -}}

{{/*
Get MojaloopRole resourcePlural.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopRole.resourcePlural" -}}
  {{- default "mojalooproles" (default .Values.global.rolePermOperator.mojaloopRole.resourcePlural .Values.rolePermOperator.mojaloopRole.resourcePlural) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceKind.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopPermissionExclusion.resourceKind" -}}
  {{- default "MojaloopPermissionExclusion" (default .Values.global.rolePermOperator.mojaloopPermissionExclusion.resourceKind .Values.rolePermOperator.mojaloopPermissionExclusion.resourceKind) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceListKind.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopPermissionExclusion.resourceListKind" -}}
  {{- default "MojaloopPermissionExclusionsList" (default .Values.global.rolePermOperator.mojaloopPermissionExclusion.resourceListKind .Values.rolePermOperator.mojaloopPermissionExclusion.resourceListKind) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceGroup.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopPermissionExclusion.resourceGroup" -}}
  {{- default "mojaloop.io" (default .Values.global.rolePermOperator.mojaloopPermissionExclusion.resourceGroup .Values.rolePermOperator.mojaloopPermissionExclusion.resourceGroup) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceVersion.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopPermissionExclusion.resourceVersion" -}}
  {{- default "v1" (default .Values.global.rolePermOperator.mojaloopPermissionExclusion.resourceVersion .Values.rolePermOperator.mojaloopPermissionExclusion.resourceVersion) -}}
{{- end -}}

{{/*
Get MojaloopRole resourceSingular.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopPermissionExclusion.resourceSingular" -}}
  {{- default "mojaloop-permission-exclusion" (default .Values.global.rolePermOperator.mojaloopPermissionExclusion.resourceSingular .Values.rolePermOperator.mojaloopPermissionExclusion.resourceSingular) -}}
{{- end -}}

{{/*
Get MojaloopRole resourcePlural.
*/}}
{{- define "common.backends.rolePermOperator.mojaloopPermissionExclusion.resourcePlural" -}}
  {{- default "mojaloop-permission-exclusions" (default .Values.global.rolePermOperator.mojaloopPermissionExclusion.resourcePlural .Values.rolePermOperator.mojaloopPermissionExclusion.resourcePlural) -}}
{{- end -}}

{{/*
Get Mojaloop operatorApiSvc port.
*/}}
{{- define "common.backends.rolePermOperator.apiSvc.port" -}}
  {{- default 80 (default .Values.global.rolePermOperator.apiSvc.port .Values.rolePermOperator.apiSvc.port) -}}
{{- end -}}

{{/*
Get fully qualified Mojaloop operatorApiSvc host.
*/}}
{{- define "common.backends.rolePermOperator.apiSvc.host" -}}
  {{- default (include "common.backends.rolePermOperator.fullname" .) (default .Values.global.rolePermOperator.apiSvc.host .Values.rolePermOperator.apiSvc.host) -}}
{{- end -}}