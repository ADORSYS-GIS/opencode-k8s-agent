# OpenCode K8s Agent Helm Chart

OpenCode-powered Kubernetes cluster review agent with OIDC authentication and Apprise notifications.

## Overview

This Helm chart deploys a CronJob that runs OpenCode to analyze your Kubernetes cluster and sends reports via Apprise.

### Features

- **OpenCode Agent**: Runs OpenCode with Kubernetes MCP for cluster analysis
- **OIDC Authentication**: Authenticates to Keycloak using client credentials flow
- **Apprise Notifications**: Sends reports via external Apprise API (Discord, Slack, Email, etc.)
- **RBAC**: Configurable ClusterRole for cluster access

## Installation

```bash
# Install Apprise API first (separate chart)
helm repo add bjw-s-labs https://bjw-s-labs.github.io/helm-charts
helm install apprise-api ./helm/apprise-api

# Then install the OpenCode agent
helm install opencode-k8s-agent ./helm/opencode-k8s-agent
```

## Configuration

### Required Secrets

Create a secret with the following keys:

```yaml
secret:
  opencode-k8s-agent-secrets:
    data:
      OPENCODE_API_KEY: ""        # Fallback API key (if not using OIDC)
      APPRISE_URLS: ""            # Apprise notification URLs
      KEYCLOAK_CLIENT_SECRET: ""  # Keycloak client secret (for OIDC)
```

### Apprise URLs

The `APPRISE_URLS` secret accepts multiple notification URLs. Format:

```
discord://webhook_id/webhook_token
slack://BotUserOAuthToken
mailto://user:password@smtp.example.com
tgram://bot_token/chat_id
```

Examples:

```bash
# Discord
discord://123456789/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV

# Slack
slack://xoxb-bot-token

# Multiple URLs (space-separated)
"discord://... slack://... mailto://..."
```

### Keycloak OIDC

Configure OIDC for token-based authentication:

```yaml
keycloak:
  enabled: true
  url: https://auth.verif.fyi
  realm: camer-digital
  clientId: opencode-k8s
```

The agent will:
1. Fetch a token from Keycloak using client credentials
2. Use the token as the API key for OpenCode/LightBridge

### OpenCode Configuration

```yaml
opencode:
  model: minimax-m2p7
  baseUrl: https://api.ai.camer.digital/v1
  thinking: true
```

### CronJob Schedule

```yaml
app-template:
  controller:
    cronjob:
      schedule: "0 */12 * * *"  # Every 12 hours
```

## Values Reference

| Value | Description | Default |
|-------|-------------|---------|
| `app-template.image.repository` | Docker image repository | `ghcr.io/adorsys-gis/opencode-k8s-agent` |
| `app-template.image.tag` | Docker image tag | `latest` |
| `app-template.controller.cronjob.schedule` | Cron schedule | `0 */12 * * *` |
| `opencode.model` | OpenCode model | `minimax-m2p7` |
| `opencode.baseUrl` | API base URL | `https://api.ai.camer.digital/v1` |
| `keycloak.enabled` | Enable OIDC | `true` |
| `keycloak.url` | Keycloak URL | `https://auth.verif.fyi` |
| `keycloak.realm` | Keycloak realm | `camer-digital` |
| `keycloak.clientId` | Keycloak client ID | `opencode-k8s` |
| `apprise-api.enabled` | Enable Apprise API | `true` |

## Files Configuration

The chart loads configuration files from the `files/` directory:

| File | Purpose |
|------|---------|
| `opencode.json` | OpenCode provider & model configuration |
| `prompt.md` | System prompt for the agent |
| `run.sh` | Entry point script |
| `runbook.md` | Cluster investigation runbook |
| `custom-resources.md` | Custom resources to check |

Edit these files directly in `helm/opencode-k8s-agent/files/` and they will be mounted as ConfigMaps.

## RBAC

The chart creates a ClusterRole with read-only access to:

- Nodes, Pods, Services, Events, ConfigMaps
- Deployments, StatefulSets, DaemonSets
- Jobs, CronJobs
- Ingresses, HPA
- Custom Resources (CNPG, External Secrets, Certificates, Authorino)

## Troubleshooting

### Check logs

```bash
kubectl logs -n monitoring-tests job/<job-name>
```

### Manual run

```bash
kubectl create job -n monitoring-tests --from=cronjob/opencode-k8s-agent manual-run
```

### Test Apprise connectivity

```bash
curl -X POST "http://apprise-api:8000/notify" \
  -F "body=Test message" \
  -F "title=Test" \
  -F "url=discord://test"
```
