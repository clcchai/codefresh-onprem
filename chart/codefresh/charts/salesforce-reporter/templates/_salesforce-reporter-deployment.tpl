{{/*
We create Deployment resource as template to be able to use many deployments but with 
different name and version. This is for Istio POC.
*/}}
{{- define "salesforce-reporter.renderDeployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "salesforce-reporter.fullname" $ }}-{{ .version | default "base" }}
  labels:
    app: {{ template "salesforce-reporter.fullname" . }}
    chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
    release: {{ .Release.Name  | quote }}
    heritage: {{ .Release.Service  | quote }}
    version: {{ .version | default "base" | quote  }}
spec:
  replicas: {{ default 1 .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ template "salesforce-reporter.fullname" . }}
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
        app: {{ template "salesforce-reporter.fullname" . }}
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
        - name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}-registry"
      terminationGracePeriodSeconds: 10
      restartPolicy: Always
      containers:
      - name: {{ template "salesforce-reporter.fullname" . }}
        image: "{{ .Values.image }}:{{ .imageTag }}"
        imagePullPolicy: {{ default "" .Values.imagePullPolicy | quote }}
        resources:
{{ toYaml .Values.resources | indent 10 }}
        env:
        {{- range $key, $value := .Values.env }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        - name: NEWRELIC_LICENSE_KEY
          valueFrom:
            secretKeyRef:
              name: "{{ .Release.Name }}-{{ .Values.global.codefresh }}"
              key: newrelic-license-key
        - name: EVENTBUS_URI
          value: 'amqp://{{ .Values.global.rabbitmqUsername }}:{{ .Values.global.rabbitmqPassword }}@{{ default (printf "%s-%s" .Release.Name .Values.global.rabbitService) .Values.global.rabbitmqHostname }}'
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
        - name: ACTIVE
          value: {{ default "" .Values.active | quote }}
        - name: SALESFORCE_OAUTH_ENDPOINT
          valueFrom:
            configMapKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: oauth-endpoint
        - name: SALESFORCE_HOST
          valueFrom:
            configMapKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: host
        - name: SALESFORCE_CLIENT_ID
          valueFrom:
            configMapKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: client-id
        - name: SALESFORCE_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: client-secret
        - name: SALESFORCE_USERNAME
          valueFrom:
            configMapKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: username
        - name: SALESFORCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: password
        - name: SALESFORCE_USER_SECURITY_TOKEN
          valueFrom:
            secretKeyRef:
              name: {{ template "salesforce-reporter.fullname" . }}
              key: security-token
        - name: SERVICE_NAME
          value: {{ template "salesforce-reporter.name" . }}
        - name: FORMAT_LOGS_TO_ELK
          value: "{{ .Values.formatLogsToElk }}"
        ports:
          - containerPort: {{ .Values.targetPort }}
            protocol: TCP
        readinessProbe:
          httpGet:
            path: /api/ping
            port: {{ .Values.targetPort }}
          periodSeconds: 5
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 2
{{- end }}