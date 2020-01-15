{{/*
We create Deployment resource as template to be able to use many deployments but with
different name and version. This is for Istio POC.
*/}}
{{- define "accounts-referrals.renderDeployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "accounts-referrals.fullname" $ }}-{{ .version | default "base" }}
  labels:
    app: {{ template "accounts-referrals.fullname" $ }}
    chart: "{{ $.Chart.Name }}-{{ $.Chart.Version | replace "+" "_" }}"
    release: {{ $.Release.Name  | quote }}
    heritage: {{ $.Release.Service  | quote }}
    version: {{ .version | default "base" | quote  }}
spec:
  replicas: {{ default 1 $.Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ template "accounts-referrals.fullname" . }}
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
        app: {{ template "accounts-referrals.fullname" . }}
        chart: "{{ $.Chart.Name }}-{{ $.Chart.Version | replace "+" "_" }}"
        release: {{ $.Release.Name  | quote }}
        heritage: {{ $.Release.Service  | quote }}
        version: {{ .version | default "base" | quote  }}
    spec:
      # In production Kubernetes clusters we have multiple tiers of worker nodes.
      # The following setting makes sure that your applicaiton will run on
      # service nodes which don't run internal pods like monitoring.
      # This is needed to ensure a good quality of service.
      {{- with (default $.Values.global.appServiceTolerations $.Values.tolerations ) }}
      tolerations:
{{ toYaml . | indent 8}}
      {{- end }}
      affinity:
{{ toYaml (default $.Values.global.appServiceAffinity $.Values.affinity) | indent 8 }}
      imagePullSecrets:
        - name: "{{ $.Release.Name }}-{{ $.Values.global.codefresh }}-registry"
      terminationGracePeriodSeconds: 10
      containers:
        - name: {{ template "accounts-referrals.fullname" . }}
          image: "{{ .Values.image }}:{{ .imageTag }}"
          imagePullPolicy: {{ default "" .Values.imagePullPolicy | quote }}
          resources:
{{ toYaml .Values.resources | indent 12 }}
          env:
          {{- if $.Values.global.env }}
          {{- range $key, $value := $.Values.global.env }}
          - name: {{ $key }}
            value: {{ $value | quote }}
          {{- end}}
          {{- end}}
          {{- range $key, $value := $.Values.env }}
          - name: {{ $key }}
            value: {{ $value | quote }}
          {{- end }}
          - name: NODE_ENV
            value: kubernetes
          - name: MONGO_URI
            {{ if .Values.mongoURI }}
            valueFrom:
              secretKeyRef:
                name: {{ template "accounts-referrals.fullname" . }}
                key: mongo-uri
            {{ else }}
            value: "mongodb://{{ .Values.global.mongodbUsername }}:{{ .Values.global.mongodbPassword }}@{{ .Release.Name }}-{{ .Values.global.mongoService }}:{{ .Values.global.mongoPort }}/{{ .Values.global.accountsReferralsService }}"
            {{ end }}
          - name: RABBIT_PASSWORD
            valueFrom:
              secretKeyRef:
                name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}"
                key: rabbitmq-password
          - name: RABBIT_USER
            valueFrom:
              secretKeyRef:
                name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}"
                key: rabbitmq-username
          - name: EVENTBUS_URI
            value: amqp://$(RABBIT_USER):$(RABBIT_PASSWORD)@{{ default (printf "%s-%s" .Release.Name .Values.global.rabbitService) .Values.global.rabbitmqHostname }}
          - name: POSTGRES_HOST
            value: {{ default (printf "%s-%s" .Release.Name .Values.global.postgresService) .Values.global.postgresHostname | quote }}
          - name: POSTGRES_DATABASE
            value: {{ .Values.global.postgresDatabase }}
          - name: POSTGRES_USER
            valueFrom:
              secretKeyRef:
                name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}"
                key: postgres-user
          - name: POSTGRES_PASSWORD
            valueFrom:
              secretKeyRef:
                name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}"
                key: postgres-password
          - name: NEWRELIC_LICENSE_KEY
            valueFrom:
              secretKeyRef:
                name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}"
                key: newrelic-license-key
          - name: PORT
            value: "{{ .Values.global.accountsReferralsPort }}"
          - name: SERVICE_NAME
            value: {{ template "accounts-referrals.name" . }}
          - name: FORMAT_LOGS_TO_ELK
            value: "{{ .Values.formatLogsToElk }}"
          ports:
          - containerPort: {{ .Values.port }}
            protocol: TCP
          readinessProbe:
            httpGet:
              path: /api/ping
              port: {{ .Values.port }}
            periodSeconds: 5
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 2
      restartPolicy: Always
{{- end }}
