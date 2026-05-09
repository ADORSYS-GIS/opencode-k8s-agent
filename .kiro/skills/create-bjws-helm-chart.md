# Skill: Create bjw-s v4.6.2 Helm Chart

## Overview
This skill provides step-by-step instructions for creating Helm charts using the bjw-s app-template v4.6.2. This is a library chart that simplifies Kubernetes resource creation.

## Critical Rules

### 1. Always Check Online Documentation When Confused
- **Search for examples**: Use `remote_web_search` to find working examples from GitHub
- **Check the official docs**: https://bjw-s-labs.github.io/helm-charts/docs/app-template/
- **Look for real-world charts**: Search GitHub for charts using app-template v4.6.2
- **Verify syntax**: When in doubt, search for "bjw-s app-template 4.6.2 [resource-type] example"

### 2. Chart Structure Requirements
The chart **MUST** use an alias in Chart.yaml, and all values **MUST** be nested under that alias.

**Chart.yaml structure:**
```yaml
apiVersion: v2
name: my-app
description: My application
type: application
version: 0.1.0
appVersion: "1.0"
kubeVersion: ">=1.22.0-0"
dependencies:
  - name: app-template
    version: "4.6.2"
    repository: https://bjw-s-labs.github.io/helm-charts
    alias: my-app  # CRITICAL: This alias is required
```

**values.yaml structure:**
```yaml
my-app:  # MUST match the alias from Chart.yaml
  # All configuration goes here
  controllers:
    main:
      # controller config
```

### 3. Update Dependencies After Creating Chart
```bash
helm dependency update
```

## Common Resource Patterns

### Deployment (Simple Web Service)

```yaml
my-app:
  global:
    nameOverride: my-app
    fullnameOverride: my-app

  controllers:
    main:
      enabled: true
      type: deployment
      replicas: 1
      containers:
        main:
          image:
            repository: nginx
            tag: latest
            pullPolicy: IfNotPresent
          env:
            MY_VAR: "value"
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 128Mi

  service:
    main:
      controller: main  # MUST reference the controller
      ports:
        http:
          port: 80

  serviceAccount:
    main:
      enabled: true  # Use 'enabled', not 'create'
```

### CronJob (Scheduled Task)

```yaml
my-cronjob:
  global:
    nameOverride: my-cronjob
    fullnameOverride: my-cronjob

  controllers:
    main:
      enabled: true
      type: cronjob
      cronjob:
        schedule: "0 2 * * *"  # Daily at 2 AM
        concurrencyPolicy: Forbid
        successfulJobsHistory: 3
        failedJobsHistory: 3
        backoffLimit: 1
        activeDeadlineSeconds: 3600
      pod:
        restartPolicy: Never  # MUST be at pod level, not cronjob level
      containers:
        main:
          image:
            repository: my-image
            tag: latest
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "Running scheduled task"
              # Your script here
          env:
            MY_VAR: "value"
          resources:
            limits:
              cpu: 1000m
              memory: 1Gi
            requests:
              cpu: 100m
              memory: 256Mi

  serviceAccount:
    main:
      enabled: true
```

### ConfigMaps (Configuration Files)

**Method 1: Inline in values.yaml**

```yaml
my-app:
  configMaps:
    config:
      enabled: true
      data:
        config.yaml: |
          # Your config content here
          key: value
        script.sh: |
          #!/bin/bash
          echo "Your script"

  persistence:
    config:
      enabled: true
      type: configMap
      name: my-app-config  # Will be auto-generated as {release-name}-config
      globalMounts:
        - path: /config
          readOnly: true
```

**Method 2: Load from files/ directory (requires custom template)**

bjw-s v4.6.2 does NOT have a built-in `configMapsFromFolder` feature. To load files from a directory, create a custom template:

**Create `templates/configmaps.yaml`:**

```yaml
{{- $files := .Files }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  labels:
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
data:
{{- if .Values.configMaps.runtime }}
  {{- range $key, $value := .Values.configMaps.runtime }}
  {{ $key }}: |
{{ $value | indent 4 }}
  {{- end }}
{{- else }}
  {{- range $path, $_ := $files.Glob "files/runtime/**" }}
  {{ base $path }}: |
{{ $files.Get $path | indent 4 }}
  {{- end }}
{{- end }}
```

**Add to values.yaml:**

```yaml
# ConfigMap file contents (optional overrides)
# If not specified, files from files/runtime/ will be used
configMaps:
  runtime: {}
    # config.json: |
    #   { "key": "value" }
```

**Benefits of this approach:**
- Files in `files/` directory are used by default
- Can override via values.yaml for ArgoCD deployments
- Supports environment-specific configurations
- GitOps-friendly

**File structure:**
```
my-chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   └── configmaps.yaml
└── files/
    └── runtime/
        ├── config.json
        ├── script.sh
        └── prompt.md
```

### Secrets (Sensitive Data)

```yaml
my-app:
  secrets:
    credentials:
      enabled: true
      stringData:
        API_KEY: ""
        DATABASE_PASSWORD: ""
        TOKEN: ""

  # Reference in container
  controllers:
    main:
      containers:
        main:
          envFrom:
            - secretRef:
                name: my-app-credentials
```

### Persistence (Volumes)

```yaml
my-app:
  persistence:
    # ConfigMap mount
    config:
      enabled: true
      type: configMap
      name: my-app-config
      globalMounts:
        - path: /config
          readOnly: true
    
    # EmptyDir (temporary storage)
    temp:
      enabled: true
      type: emptyDir
      globalMounts:
        - path: /tmp
    
    # PersistentVolumeClaim
    data:
      enabled: true
      type: persistentVolumeClaim
      accessMode: ReadWriteOnce
      size: 10Gi
      globalMounts:
        - path: /data
```

### Init Containers

```yaml
my-app:
  controllers:
    main:
      initContainers:
        init-db:
          image:
            repository: busybox
            tag: latest
          command:
            - sh
            - -c
            - |
              echo "Initializing..."
              # Your init logic
      containers:
        main:
          # main container config
```

### Multiple Containers in Pod

```yaml
my-app:
  controllers:
    main:
      containers:
        app:
          image:
            repository: my-app
            tag: latest
          env:
            PORT: "8080"
        sidecar:
          image:
            repository: my-sidecar
            tag: latest
          env:
            SIDECAR_MODE: "proxy"
```

## RBAC (Custom Templates Required)

**Note**: bjw-s app-template v4.6.2 does NOT have native RBAC support. You must create custom templates.

### Create `templates/rbac.yaml`:

```yaml
{{- if .Values.rbac.create -}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ .Values.rbac.clusterRole.name | default (printf "%s-readonly" .Release.Name) }}
  labels:
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
rules:
  {{- toYaml .Values.rbac.clusterRole.rules | nindent 2 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .Values.rbac.clusterRoleBinding.name | default (printf "%s-readonly-binding" .Release.Name) }}
  labels:
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ .Values.rbac.clusterRole.name | default (printf "%s-readonly" .Release.Name) }}
subjects:
  - kind: ServiceAccount
    name: {{ .Release.Name }}
    namespace: {{ .Release.Namespace }}
{{- end }}
```

### Add to values.yaml:

```yaml
rbac:
  create: true
  clusterRole:
    name: my-app-readonly
    rules:
      - apiGroups: [""]
        resources: [pods, services, configmaps]
        verbs: [get, list, watch]
      - apiGroups: ["apps"]
        resources: [deployments, statefulsets]
        verbs: [get, list, watch]
```

## Testing Your Chart

### 1. Lint the Chart
```bash
helm lint .
```

### 2. Template Rendering (Dry Run)
```bash
helm template test-release . --dry-run
```

### 3. Check Generated Resources
```bash
helm template test-release . --dry-run 2>&1 | grep -E "^kind:" | sort | uniq -c
```

### 4. Install (Dry Run)
```bash
helm install test-release . --dry-run --debug
```

## Common Errors and Solutions

### Error: "No enabled controller found"
**Cause**: Controller not enabled or service references wrong controller
**Solution**: 
- Add `enabled: true` to controller
- Ensure `service.main.controller: main` matches your controller name

### Error: "serviceAccount.create: Invalid type"
**Cause**: Using `create: true` instead of `enabled: true`
**Solution**: Use `enabled: true` for serviceAccount

### Error: "Additional property mountPath is not allowed"
**Cause**: Using old v3 persistence syntax
**Solution**: Use `globalMounts` with path and readOnly

### Error: "values don't meet the specifications"
**Cause**: Schema validation failure
**Solution**: Check the error message for the specific field and correct syntax

### Error: Empty template output
**Cause**: Values not nested under chart alias
**Solution**: Ensure all values are under the alias key from Chart.yaml

## Workflow

1. **Create Chart.yaml** with alias
2. **Create values.yaml** with values nested under alias
3. **Run `helm dependency update`**
4. **Run `helm lint .`** to validate
5. **Run `helm template test . --dry-run`** to test rendering
6. **Check generated resources** with grep
7. **Iterate** until all resources generate correctly

## When to Search Online

- When you encounter a validation error you don't understand
- When implementing a resource type you haven't used before
- When the chart generates no output or unexpected output
- When you need to see real-world examples of complex configurations
- When documentation is unclear or incomplete

## Key Takeaways

1. **Always use an alias** in Chart.yaml dependencies
2. **Nest all values** under the alias key
3. **Use `controllers` (plural)** with proper container definitions
4. **Use `enabled: true`** for serviceAccount, not `create: true`
5. **Use `globalMounts`** for persistence, not `mountPath`
6. **Put `restartPolicy`** at pod level for CronJobs
7. **Reference controller** in service definition
8. **RBAC requires custom templates** in v4.6.2
9. **Search online** when confused or stuck
10. **Test frequently** with lint and template commands
