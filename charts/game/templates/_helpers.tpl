{{- define "game.labels" -}}
app.kubernetes.io/part-of: la-bataille-de-france
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "game.image" -}}
{{- $d := required "le digest de l'image est obligatoire (sha256:…)" .image.digest -}}
{{- if not (regexMatch "^sha256:[0-9a-f]{64}$" $d) -}}
{{- fail (printf "digest invalide : %s" $d) -}}
{{- end -}}
{{ .image.repository }}@{{ $d }}
{{- end -}}

{{/* Contexte de sécurité commun : non root, sans privilèges, racine en lecture seule. */}}
{{- define "game.podSecurity" -}}
automountServiceAccountToken: false
enableServiceLinks: false
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  fsGroup: 65532
  seccompProfile: { type: RuntimeDefault }
{{- with .Values.imagePullSecret }}
imagePullSecrets:
  - name: {{ . }}
{{- end }}
{{- end -}}

{{- define "game.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: [ALL] }
{{- end -}}
