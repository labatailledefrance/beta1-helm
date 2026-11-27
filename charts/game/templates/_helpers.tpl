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

{{/* Identifiants des publications, adressées par leurs entrées (H-06) : le
digest de l'image fixe le manifeste et le code ; les zones, l'étendue. */}}
{{- define "game.publication.tiles" -}}
{{- $d := include "game.image" .Values.datachain -}}
{{- printf "%s|%s" $d (join "," .Values.datachain.zones) | sha256sum | trunc 16 -}}
{{- end -}}

{{- define "game.publication.assets" -}}
{{- include "game.image" .Values.assets | sha256sum | trunc 16 -}}
{{- end -}}

{{/* Attente d'une publication complète (initContainer) : `assets attendre`. */}}
{{- define "game.attendre" -}}
- name: attendre-{{ .nom }}
  image: {{ include "game.image" .racine.Values.assets }}
  args: ["attendre", "--fichier", {{ .fichier | quote }}]
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities: { drop: [ALL] }
  resources:
    requests: { cpu: 10m, memory: 16Mi }
    limits: { cpu: 100m, memory: 64Mi }
  volumeMounts:
    - { name: {{ .volume }}, mountPath: {{ .point }}, readOnly: true }
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
