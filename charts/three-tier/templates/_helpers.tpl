{{- define "three-tier.labels" -}}
app.kubernetes.io/part-of: three-tier
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "three-tier.image" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- if $root.Values.image.registry -}}
{{ $root.Values.image.registry }}/{{ $component.image }}:{{ $component.tag }}
{{- else -}}
{{ $component.image }}:{{ $component.tag }}
{{- end -}}
{{- end -}}
