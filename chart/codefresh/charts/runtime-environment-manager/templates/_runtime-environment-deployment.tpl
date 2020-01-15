{{/*
We create Deployment resource as template to be able to use many deployments but with
different name and version. This is for Istio POC.
*/}}
{{- define "runtime-environment-manager.renderDeployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "runtime-environment-manager.fullname" $ }}-{{ .version | default "base" }}
  labels:
    app: {{ template "runtime-environment-manager.fullname" . }}
    chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
    release: {{ .Release.Name  | quote }}
    heritage: {{ .Release.Service  | quote }}
    version: {{ .version | default "base" | quote  }}
spec:
  replicas: {{ default 1 .Values.replicaCount }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 50%
      maxSurge: 50%
  selector:
    matchLabels:
      app: {{ template "runtime-environment-manager.fullname" . }}
  template:
    metadata:
      {{- if .Values.redeploy }}
      annotations:
        forceRedeployUniqId: {{ now | quote }}
        sidecar.istio.io/inject: {{ $.Values.global.istio.enabled | default "false" | quote }}
      {{- else }}
      annotations:
        sidecar.istio.io/inject: {{ $.Values.global.istio.enabled | default "false" | quote }}
      {{- end }}
      labels:
        app: {{ template "runtime-environment-manager.fullname" . }}
        chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
        release: {{ .Release.Name  | quote }}
        heritage: {{ .Release.Service  | quote }}
        version: {{ .version | default "base" | quote  }}
    spec:
      # In production Kubernetes clusters we have multiple tiers of worker nodes.
      # The following setting makes sure that your applicaiton will run on
      # service nodes which don't run internal pods like monitoring.
      # This is needed to ensure a good quality of service.
      {{- with (default .Values.global.appServiceTolerations .Values.tolerations ) }}
      tolerations:
{{ toYaml . | indent 8}}
      {{- end }}
      affinity:
{{ toYaml (default .Values.global.appServiceAffinity .Values.affinity) | indent 8 }}
      imagePullSecrets:
        - name: "{{ template "runtime-environment-manager.fullname" . }}-registry"
      containers:
      - name: {{ template "runtime-environment-manager.fullname" . }}
        {{- if .Values.global.privateRegistry }}
        image: "{{ .Values.global.dockerRegistry }}{{ .Values.image }}:{{ .imageTag }}"
        {{- else }}
        image: "{{ .Values.dockerRegistry }}{{ .Values.image }}:{{ .imageTag }}"
        {{- end }}
        imagePullPolicy: {{ default "" .Values.imagePullPolicy | quote }}
        resources:
{{ toYaml .Values.resources | indent 10 }}
        env:
           {{- if $.Values.global.env }}
           {{- range $key, $value := $.Values.global.env }}
           - name: {{ $key }}
             value: {{ $value | quote }}
           {{- end}}
           {{- end}}
          - name: API_URI
            value: "{{ .Release.Name }}-{{ .Values.global.cfapiService }}"
          - name: API_PORT
            value: {{ .Values.global.cfapiInternalPort | quote }}
          - name: PAYMENTS_URI
            value: "{{ .Release.Name }}-{{ .Values.global.paymentsService }}"
          - name: PAYMENTS_PORT
            value: {{ .Values.global.paymentsServicePort | quote }}
          - name: PIPELINE_MANAGER_URI
            value: "{{ .Release.Name }}-{{ .Values.global.pipelineManagerService }}"
          - name: PIPELINE_MANAGER_PORT
            value: {{ .Values.global.pipelineManagerPort | quote }}
          - name: CLUSTER_PROVIDERS_URI
            value: "{{ .Release.Name }}-{{ .Values.global.clusterProvidersService }}"
          - name: CLUSTER_PROVIDERS_PORT
            value: "{{ .Values.global.clusterProvidersPort }}"
          {{- if .Values.requiredInfraComponenets.mongo }}
          - name: MONGO_URI
            valueFrom:
              secretKeyRef:
                name: {{ template "runtime-environment-manager.fullname" . }}
                key: mongo-uri
          {{- end}}

          - name: SERVICE_NAME
            value: {{ template "runtime-environment-manager.name" . }}
          - name: FORMAT_LOGS_TO_ELK
            value: "{{ .Values.formatLogsToElk }}"

          {{- if .Values.global.env }}
          {{- range $key, $value := .Values.global.env }}
          - name: {{ $key }}
            value: {{ $value | quote }}
          {{- end}}
          {{- end}}
          {{- range $key, $value := .Values.env }}
          - name: {{ $key }}
            value: {{ $value | quote }}
          {{- end }}
          - name: PORT
            value: {{ .Values.port | quote }}
          - name: NEWRELIC_LICENSE_KEY
            valueFrom:
              secretKeyRef:
                name: {{ template "runtime-environment-manager.fullname" . }}
                key: newrelic-license-key
        ports:
          - containerPort: {{ .Values.port }}
            protocol: TCP
        volumeMounts:
          - name: runtime-environments
            mountPath: /etc/admin/runtimeEnvironments.json
            subPath: runtimeEnvironments.json
        {{- if .Values.global.addResolvConf }}
        - mountPath: /etc/resolv.conf
          name: resolvconf
          subPath: resolv.conf
          readOnly: true
        {{- end }}
        readinessProbe:
          httpGet:
            path: /api/ping
            port: {{ .Values.port }}
          periodSeconds: 5
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 2
      volumes:
      {{- if .Values.global.addResolvConf }}
      - name: resolvconf
        configMap:
          name: {{ .Release.Name }}-{{ .Values.global.codefresh }}-resolvconf
      {{- end }}
      - name: runtime-environments
        configMap:
          name: {{ .Release.Name }}-{{ .Values.global.codefresh }}-runtime-envs
{{- end }}
