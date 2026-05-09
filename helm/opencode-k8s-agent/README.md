# OpenCode K8s Agent Helm Chart

This Helm chart deploys the OpenCode K8s Review Agent with Kubernetes MCP integration.

## Features

- **CronJob-based execution**: Runs periodic cluster health checks
- **ConfigMap management**: Supports both file-based defaults and ArgoCD overrides
- **RBAC**: Read-only cluster access for investigation
- **Secrets management**: Secure handling of API keys and credentials
- **Notification integration**: Sends reports via Apprise API

## Installation

### Basic Installation

```bash
helm install opencode-k8s-agent . \
  --set opencode-k8s-agent.secrets.secrets.stringData.OPENCODE_API_KEY="your-api-key" \
  --set opencode-k8s-agent.secrets.secrets.stringData.APPRISE_URLS="discord://webhook-url"
```

### With Custom Values

```bash
helm install opencode-k8s-agent . -f custom-values.yaml
```

## ConfigMap File Management

This chart supports two methods for managing ConfigMap content:

### Method 1: File-based (Default)

By default, the chart loads files from the `files/` directory:

- `files/runtime/` → `opencode-k8s-agent-config` ConfigMap
  - `opencode.json` - OpenCode configuration
  - `prompt.md` - Investigation prompt
  - `run.sh` - Execution script
  
- `files/docs/` → `opencode-k8s-agent-docs` ConfigMap
  - `custom-resources.md` - Custom resource investigation guide
  - `runbook.md` - Operational runbook

**No configuration needed** - files are automatically loaded.

### Method 2: Values Override (ArgoCD-friendly)

Override ConfigMap content via `values.yaml` or ArgoCD Application spec:

```yaml
configMaps:
  runtime:
    opencode.json: |
      {
        "logLevel": "INFO",
        "provider": {
          "custom": "configuration"
        }
      }
    prompt.md: |
      # Custom Prompt
      Your custom content here
    run.sh: |
      #!/bin/bash
      echo "Custom script"
  docs:
    custom-resources.md: |
      # Custom Docs
    runbook.md: |
      # Custom Runbook
```

**When to use:**
- ArgoCD deployments where you want environment-specific configurations
- GitOps workflows where config is managed separately from the chart
- Multi-environment deployments with different prompts/scripts

See `argocd-override-example.yaml` for a complete example.

## Configuration

### Required Secrets

```yaml
opencode-k8s-agent:
  secrets:
    secrets:
      stringData:
        OPENCODE_API_KEY: "your-api-key"
        APPRISE_URLS: "discord://webhook-url"
        KEYCLOAK_CLIENT_SECRET: "client-secret"  # Optional if using OIDC
```

### CronJob Schedule

```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */12 * * *"  # Every 12 hours
```

### Resource Limits

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          resources:
            limits:
              cpu: 1000m
              memory: 1Gi
            requests:
              cpu: 100m
              memory: 256Mi
```

## RBAC

The chart creates a ClusterRole with read-only access to:
- Core resources (pods, services, configmaps, etc.)
- Workload resources (deployments, statefulsets, jobs, etc.)
- Custom resources (CNPG clusters, ExternalSecrets, etc.)

To disable RBAC:

```yaml
rbac:
  create: false
```

## Testing

### Lint the chart

```bash
helm lint .
```

### Template and inspect

```bash
helm template test-opencode . | less
```

### Test with overrides

```bash
helm template test-opencode . -f custom-values.yaml
```

### Verify ConfigMaps

```bash
helm template test-opencode . | grep -A 30 "kind: ConfigMap"
```

## ArgoCD Integration

See `argocd-override-example.yaml` for a complete ArgoCD Application example with values overrides.

Key points:
- Use `spec.source.helm.values` to override ConfigMap content
- Files from the chart are used as defaults
- Overrides completely replace the default content (not merged)

## Troubleshooting

### ConfigMaps are empty

Check that either:
1. Files exist in `files/runtime/` and `files/docs/` directories, OR
2. You've provided overrides in `configMaps.runtime` and `configMaps.docs`

### CronJob not running

Check:
```bash
kubectl get cronjob opencode-k8s-agent
kubectl describe cronjob opencode-k8s-agent
```

### Check logs

```bash
# Get the latest job
kubectl get jobs -l app.kubernetes.io/name=opencode-k8s-agent

# View logs
kubectl logs -l job-name=<job-name>
```

## Dependencies

- **bjw-s app-template**: v4.6.2
- **Kubernetes**: >= 1.22.0

## License

See parent repository for license information.
