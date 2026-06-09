# OpenCode K8s Agent

> **AI-Powered Kubernetes Cluster Health Monitoring**  
> Never get caught off-guard by cluster issues again.

[![Helm Version](https://img.shields.io/badge/helm-v3.0+-blue.svg)](https://helm.sh)
[![Kubernetes Version](https://img.shields.io/badge/kubernetes-v1.22+-blue.svg)](https://kubernetes.io)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

## Overview

OpenCode K8s Agent is an intelligent Kubernetes monitoring solution that uses AI to proactively investigate your cluster health and send structured reports to your notification channels. Unlike traditional monitoring tools that require complex rule configuration, this agent uses natural language prompts to understand what matters in your cluster and adapts to your specific infrastructure.

### Key Features

- 🤖 **AI-Powered Analysis**: Uses OpenCode with Kubernetes MCP to intelligently investigate cluster state
- 📊 **Structured Reporting**: Generates executive summaries with actionable recommendations
- 🔔 **Multi-Channel Notifications**: Integrates with Discord, Slack, email, and 100+ services via Apprise
- 🔒 **Read-Only by Default**: RBAC-controlled with no modification permissions
- ⚙️ **Fully Customizable**: Override prompts, investigation logic, and documentation for your specific needs
- 🚀 **GitOps Ready**: First-class support for ArgoCD and Flux with values overrides
- 📦 **Zero Dependencies**: Runs as a self-contained CronJob

### How It Works

```
┌─────────────────┐
│   CronJob       │  Runs on schedule (default: every 12 hours)
│  (Kubernetes)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  OpenCode Agent │  Reads cluster state via Kubernetes API
│   + MCP Server  │  Analyzes using AI with custom prompts
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Apprise API    │  Sends formatted reports to your channels
│  (Notifications)│  (Discord, Slack, Email, etc.)
└─────────────────┘
```

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.22+)
- Helm 3.0+
- An OpenCode-compatible API endpoint (or OpenAI API)
- Notification channel (Discord webhook, Slack, etc.)

### 1. Install Apprise API (Notification Gateway)

```bash
helm install apprise-api ./helm/apprise-api
```

### 2. Create Secrets

```bash
kubectl create secret generic opencode-k8s-agent-secret \
  --from-literal=OPENCODE_API_KEY="your-model-endpoint-api-key" \
  --from-literal=APPRISE_URLS="discord://webhook-id/webhook-token"
```

### 3. Install OpenCode K8s Agent

```bash
helm install opencode-k8s-agent ./helm/opencode-k8s-agent
```

### 4. Verify Installation

```bash
# Check CronJob is created
kubectl get cronjob opencode-k8s-agent

# Trigger a manual run
kubectl create job --from=cronjob/opencode-k8s-agent manual-test

# Watch the logs
kubectl logs -f job/manual-test
```

You should receive a cluster health report in your configured notification channel within a few minutes!

## Configuration

### Basic Configuration

The chart comes with sensible defaults, but you'll want to customize it for your environment:

```yaml
# values.yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */6 * * *"  # Run every 6 hours
```

Secrets must be created externally (e.g. via ESO) as `opencode-k8s-agent-secret` containing:

```yaml
OPENCODE_API_KEY: "your-model-endpoint-api-key"
APPRISE_URLS: "discord://webhook-url"
```

> **Note**: `OPENCODE_API_KEY` is the model-endpoint bearer (sent as `Authorization: Bearer`). Provide it in the secret, or inject it at runtime — e.g. a projected Kubernetes ServiceAccount token — by overriding the container `command`.

### Notification Channels

The agent uses [Apprise](https://github.com/caronc/apprise) for notifications, supporting 100+ services:

#### Discord

```yaml
APPRISE_URLS: "discord://webhook-id/webhook-token"
```

#### Slack

```yaml
APPRISE_URLS: "slack://token-a/token-b/token-c"
```

#### Multiple Channels

```yaml
APPRISE_URLS: "discord://webhook-url slack://token email://user:pass@domain.com"
```

See [Apprise URL documentation](https://github.com/caronc/apprise/wiki) for all supported services.

### AI Model Configuration

Configure which AI model to use for analysis:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          env:
            OPENCODE_MODEL: "gpt-4"  # or claude-3-5-sonnet, minimax-m2p7, etc.
            OPENCODE_BASE_URL: "https://api.openai.com/v1"
```

### RBAC Permissions

By default, the agent has read-only access to:

- **Core Resources**: Pods, Services, ConfigMaps, PVCs, Events, Nodes
- **Workloads**: Deployments, StatefulSets, DaemonSets, Jobs, CronJobs
- **Networking**: Ingresses
- **Custom Resources**: CNPG Clusters, ExternalSecrets, Certificates, AuthConfigs

To add custom resources:

```yaml
rbac:
  create: true
  clusterRole:
    rules:
      # Default rules...
      - apiGroups: ["your-operator.io"]
        resources: ["customresources"]
        verbs: [get, list, watch]
```

To disable RBAC (not recommended):

```yaml
rbac:
  create: false
```

## Customization

### Understanding the Configuration Files

The agent uses three main configuration files that you can customize:

#### 1. `opencode.json` - AI Provider Configuration

Configures the OpenCode agent and AI provider:

```json
{
  "logLevel": "INFO",
  "provider": {
    "openai": {
      "npm": "@ai-sdk/openai",
      "options": {
        "baseURL": "${OPENCODE_BASE_URL}",
        "apiKey": "${OPENCODE_API_KEY}"
      },
      "models": {
        "gpt-4": {
          "id": "gpt-4",
          "tool_call": true
        }
      }
    }
  },
  "agent": {
    "coder": {
      "model": "openai:gpt-4"
    }
  },
  "mcp": {
    "kubernetes": {
      "type": "local",
      "command": ["/usr/local/bin/kubernetes-mcp-server"],
      "enabled": true
    }
  }
}
```

#### 2. `prompt.md` - Investigation Instructions

The AI prompt that guides cluster investigation. This is where you define:

- What to investigate
- Which namespaces to focus on
- What constitutes a problem
- How to format the report

**Example: Custom prompt for a production e-commerce cluster**

```markdown
You are a Kubernetes cluster investigation agent for an e-commerce platform.

Your role is to analyze the cluster and produce a structured operational report.

## Investigation Scope

1. **Critical Services** (Namespace: `production`):
   - `frontend` - Customer-facing web application
   - `api-gateway` - Backend API gateway
   - `payment-processor` - Payment processing service
   - `inventory-service` - Inventory management

2. **Databases** (Namespace: `databases`):
   - PostgreSQL clusters (managed by CloudNativePG)
   - Redis caches

3. **Background Jobs** (Namespace: `jobs`):
   - `order-processor` - Processes customer orders
   - `email-sender` - Sends transactional emails
   - `inventory-sync` - Syncs with warehouse system

## Health Checks

1. **Response Time**: Check if any service has high latency
2. **Error Rates**: Look for pods with recent error logs
3. **Resource Pressure**: Identify pods near memory/CPU limits
4. **Failed Jobs**: Check for failed CronJobs in last 24 hours
5. **Database Health**: Verify all PostgreSQL clusters are healthy

## Report Format

# Executive Summary
[One-paragraph overview of cluster health]

## 🚨 Critical Issues
[Any issues requiring immediate attention]

## 📊 Service Health
[Status of frontend, api-gateway, payment-processor, inventory-service]

## 💾 Database Status
[PostgreSQL cluster health, Redis availability]

## ⏰ Background Jobs
[Status of order-processor, email-sender, inventory-sync]

## 💡 Recommendations
[Actionable steps to improve cluster health]
```

#### 3. `runbook.md` & `custom-resources.md` - Context Documentation

These files provide context about your specific infrastructure:

**`runbook.md`** - Service map and operational procedures:

```markdown
# Production E-Commerce Cluster Runbook

## Service Dependencies

### Frontend (production/frontend)
- **Depends on**: api-gateway, Redis cache
- **Critical**: Yes - customer-facing
- **SLA**: 99.9% uptime
- **Restart threshold**: > 5 restarts/hour is critical

### Payment Processor (production/payment-processor)
- **Depends on**: PostgreSQL (payments-db), Stripe API
- **Critical**: Yes - revenue impact
- **SLA**: 99.95% uptime
- **Alert on**: Any failed payment transactions

## Known Issues

### Issue: Frontend pods restart during high traffic
- **Cause**: Memory limit too low during flash sales
- **Mitigation**: Scale horizontally before planned sales events
- **Long-term fix**: Implement HPA with memory-based scaling

### Issue: Inventory sync job occasionally fails
- **Cause**: Warehouse API timeout (30s limit)
- **Mitigation**: Job will retry on next schedule
- **Long-term fix**: Increase timeout to 60s
```

**`custom-resources.md`** - Custom resource investigation guide:

```markdown
# Custom Resources Guide

## CloudNativePG Clusters

Check PostgreSQL cluster health:

```bash
kubectl get cluster -n databases
```

**Healthy state**: INSTANCES = READY

**Investigation steps if unhealthy**:
1. Check controller logs: `kubectl logs -n cnpg-system deploy/cnpg-controller`
2. Check cluster events: `kubectl describe cluster -n databases <cluster-name>`
3. Verify backup status: `kubectl get backup -n databases`

## Cert-Manager Certificates

Check certificate status:

```bash
kubectl get certificate -A
```

**Alert if**: Any certificate shows `Ready: False`

**Common issues**:
- DNS01 challenge failures (check DNS provider)
- Rate limiting from Let's Encrypt (use staging for testing)
```

### Method 1: Override via Values (Recommended for GitOps)

Create a custom values file:

```yaml
# custom-values.yaml
configMaps:
  runtime:
    prompt.md: |
      # Your custom investigation prompt
      You are monitoring a production e-commerce cluster...
      
    opencode.json: |
      {
        "logLevel": "INFO",
        "provider": {
          "openai": {
            "npm": "@ai-sdk/openai",
            "options": {
              "baseURL": "https://api.openai.com/v1",
              "apiKey": "${OPENCODE_API_KEY}"
            }
          }
        }
      }
    
    run.sh: |
      #!/bin/bash
      # Your custom execution script
      # Add pre-checks, custom logic, etc.
      
  docs:
    runbook.md: |
      # Your cluster runbook
      
    custom-resources.md: |
      # Your custom resources guide
```

Install with overrides:

```bash
helm install opencode-k8s-agent ./helm/opencode-k8s-agent -f custom-values.yaml
```

### Method 2: Fork and Modify Files

For more extensive customization:

1. Fork this repository
2. Modify files in `helm/opencode-k8s-agent/files/`
3. Deploy from your fork

```bash
git clone https://github.com/ADORSYS-GIS/opencode-k8s-agent
cd opencode-k8s-agent

# Edit files
vim helm/opencode-k8s-agent/files/runtime/prompt.md
vim helm/opencode-k8s-agent/files/docs/runbook.md

# Deploy
helm install opencode-k8s-agent ./helm/opencode-k8s-agent
```

## Integration with Apprise API

The agent is designed to work seamlessly with the included Apprise API chart.

### Standalone Apprise API

Deploy Apprise API in the same namespace:

```bash
helm install apprise-api ./helm/apprise-api
```

The agent will automatically connect to `http://apprise-api:8000`.

### External Apprise API

If you have Apprise API running elsewhere:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          env:
            APPRISE_API_URL: "https://apprise.example.com"
```

### Direct Notification (Without Apprise API)

You can bypass Apprise API and send notifications directly by modifying `run.sh`:

```yaml
configMaps:
  runtime:
    run.sh: |
      #!/bin/bash
      # ... generate report ...
      
      # Send directly to Discord
      curl -X POST "${DISCORD_WEBHOOK_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$(cat $REPORT_FILE)\"}"
```

## ArgoCD / GitOps Integration

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opencode-k8s-agent
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ADORSYS-GIS/your-repo
    targetRevision: main
    path: helm/opencode-k8s-agent
    helm:
      values: |
        # Override for production environment
        opencode-k8s-agent:
          controllers:
            main:
              cronjob:
                schedule: "0 */4 * * *"  # Every 4 hours in prod
        
        configMaps:
          runtime:
            prompt.md: |
              # Production Cluster Investigation
              Focus on critical services in the `production` namespace...
          
          docs:
            runbook.md: |
              # Production Runbook
              ## Critical Services
              - frontend: Customer-facing application
              - api: Backend API
  
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Multi-Environment Setup

Use different values files per environment:

```
gitops/
├── base/
│   └── opencode-k8s-agent.yaml
├── staging/
│   └── values-staging.yaml
└── production/
    └── values-production.yaml
```

**`values-staging.yaml`**:
```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */12 * * *"  # Less frequent in staging

configMaps:
  runtime:
    prompt.md: |
      # Staging Cluster Investigation
      This is a non-production environment...
```

**`values-production.yaml`**:
```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */4 * * *"  # More frequent in production

configMaps:
  runtime:
    prompt.md: |
      # Production Cluster Investigation
      CRITICAL: This is the production environment...
```

## Advanced Use Cases

### Multi-Cluster Monitoring

Deploy the agent in each cluster with cluster-specific configuration:

```yaml
# cluster-us-east.yaml
configMaps:
  runtime:
    prompt.md: |
      You are monitoring the US-EAST production cluster.
      This cluster serves North American customers...

# cluster-eu-west.yaml
configMaps:
  runtime:
    prompt.md: |
      You are monitoring the EU-WEST production cluster.
      This cluster serves European customers and must comply with GDPR...
```

### Cost Optimization Monitoring

Configure the agent to focus on cost-related issues:

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a Kubernetes cost optimization agent.
      
      ## Investigation Focus
      
      1. **Resource Waste**:
         - Pods with very low CPU/memory utilization
         - Over-provisioned resource requests
         - Unused PersistentVolumeClaims
      
      2. **Scaling Opportunities**:
         - Services that could benefit from HPA
         - StatefulSets that could be scaled down
      
      3. **Cost Anomalies**:
         - Sudden increases in pod count
         - New expensive resources (LoadBalancers, large PVCs)
      
      ## Report Format
      
      # Cost Optimization Report
      
      ## 💰 Potential Savings
      [List resources that could be optimized]
      
      ## 📈 Scaling Recommendations
      [Suggest HPA or manual scaling adjustments]
      
      ## ⚠️ Cost Anomalies
      [Flag unusual resource consumption]
```

### Security Audit Mode

Focus on security-related issues:

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a Kubernetes security audit agent.
      
      ## Security Checks
      
      1. **Pod Security**:
         - Pods running as root
         - Pods with privileged: true
         - Pods without resource limits
      
      2. **Network Policies**:
         - Namespaces without NetworkPolicies
         - Overly permissive policies
      
      3. **Secrets Management**:
         - Secrets mounted as environment variables (prefer volumes)
         - ExternalSecrets sync failures
      
      4. **RBAC**:
         - ServiceAccounts with cluster-admin
         - Overly broad ClusterRoles
      
      ## Report Format
      
      # Security Audit Report
      
      ## 🔴 Critical Security Issues
      [Immediate security risks]
      
      ## 🟡 Security Recommendations
      [Best practice improvements]
      
      ## ✅ Compliant Resources
      [Resources following security best practices]
```

### Compliance Monitoring

Monitor compliance with organizational policies:

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a Kubernetes compliance monitoring agent.
      
      ## Compliance Requirements
      
      1. **Labeling Standards**:
         - All resources must have: app, team, environment labels
         - All namespaces must have: cost-center label
      
      2. **Resource Quotas**:
         - All namespaces must have ResourceQuota
         - All namespaces must have LimitRange
      
      3. **Backup Compliance**:
         - All StatefulSets must have backup annotations
         - All PVCs must have backup enabled
      
      4. **Documentation**:
         - All services must have description annotation
         - All CronJobs must have runbook-url annotation
      
      ## Report Format
      
      # Compliance Report
      
      ## ❌ Non-Compliant Resources
      [Resources violating policies]
      
      ## 📋 Compliance Summary
      [Overall compliance percentage by policy]
      
      ## 📝 Remediation Steps
      [How to bring resources into compliance]
```

## Troubleshooting

### Agent Not Running

Check CronJob status:

```bash
kubectl get cronjob opencode-k8s-agent
kubectl describe cronjob opencode-k8s-agent
```

Check for recent jobs:

```bash
kubectl get jobs -l app.kubernetes.io/name=opencode-k8s-agent
```

### No Reports Received

1. **Check job logs**:
   ```bash
   kubectl logs -l job-name=<job-name>
   ```

2. **Verify Apprise API is running**:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=apprise-api
   ```

3. **Test Apprise API manually**:
   ```bash
   kubectl port-forward svc/apprise-api 8000:8000
   curl -X POST http://localhost:8000/notify \
     -d "urls=discord://your-webhook" \
     -d "body=Test message"
   ```

4. **Check secrets are set**:
   ```bash
   kubectl get secret opencode-k8s-agent-secret -o yaml
   ```

### Reports Are Empty or Incomplete

1. **Check RBAC permissions**:
   ```bash
   kubectl auth can-i list pods --as=system:serviceaccount:default:opencode-k8s-agent
   ```

2. **Verify OpenCode API is accessible**:
   ```bash
   kubectl exec -it <pod-name> -- curl -v ${OPENCODE_BASE_URL}/models
   ```

3. **Check ConfigMaps are populated**:
   ```bash
   kubectl get configmap opencode-k8s-agent-config -o yaml
   kubectl get configmap opencode-k8s-agent-docs -o yaml
   ```

### Job Timeout

If jobs are timing out, increase the deadline:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        activeDeadlineSeconds: 7200  # 2 hours
```

### High Resource Usage

Reduce resource consumption:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 50m
              memory: 128Mi
```

## Configuration Reference

### Complete Values Schema

```yaml
opencode-k8s-agent:
  global:
    nameOverride: string
    fullnameOverride: string
  
  controllers:
    main:
      enabled: bool
      type: cronjob
      cronjob:
        schedule: string (cron format)
        concurrencyPolicy: Forbid|Allow|Replace
        successfulJobsHistory: int
        failedJobsHistory: int
        backoffLimit: int
        activeDeadlineSeconds: int
      pod:
        restartPolicy: Never|OnFailure
      containers:
        main:
          image:
            repository: string
            tag: string
            pullPolicy: IfNotPresent|Always|Never
          command: []string
          env: map[string]string
          envFrom: []object
          resources:
            limits:
              cpu: string
              memory: string
            requests:
              cpu: string
              memory: string
  
  serviceAccount:
    main:
      enabled: bool
      forceRename: string
  
  persistence:
    runtime:
      enabled: bool
      type: configMap
      name: string
      globalMounts:
        - path: string
          readOnly: bool
    docs:
      enabled: bool
      type: configMap
      name: string
      globalMounts:
        - path: string
          readOnly: bool
  
  # No secrets block — secret must be created externally as opencode-k8s-agent-secret
  # Required keys: APPRISE_URLS, and OPENCODE_API_KEY unless that bearer is
  # injected at runtime (e.g. a projected SA token via the container command)

rbac:
  create: bool
  clusterRole:
    name: string
    rules: []object
  clusterRoleBinding:
    create: bool
    name: string

configMaps:
  runtime: map[string]string
  docs: map[string]string
```

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `OPENCODE_API_KEY` | Model-endpoint bearer (sent as `Authorization: Bearer`) | Yes (unless injected at runtime) | - |
| `APPRISE_URLS` | Notification URLs (space-separated) | Yes | - |
| `OPENCODE_MODEL` | Model to use for analysis | No | `minimax-m2p7` |
| `OPENCODE_BASE_URL` | API endpoint URL | No | `https://api.ai.camer.digital/v1` |
| `APPRISE_API_URL` | Apprise API endpoint | No | `http://apprise-api:8000` |

## Examples

See the `examples/` directory for complete working examples:

- `examples/basic/` - Minimal configuration
- `examples/production/` - Production-ready setup with monitoring
- `examples/multi-cluster/` - Multi-cluster deployment
- `examples/cost-optimization/` - Cost-focused monitoring
- `examples/security-audit/` - Security-focused monitoring

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Reporting Issues

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Search [existing issues](https://github.com/ADORSYS-GIS/opencode-k8s-agent/issues)
3. Open a new issue with:
   - Kubernetes version
   - Helm version
   - Chart version
   - Complete error logs
   - Steps to reproduce

### Sharing Custom Prompts

Have a great custom prompt for a specific use case? Share it!

1. Fork the repository
2. Add your prompt to `examples/prompts/`
3. Submit a pull request

## FAQ

### Q: Can I use this with OpenAI instead of a custom endpoint?

**A:** Yes! Just configure:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          env:
            OPENCODE_BASE_URL: "https://api.openai.com/v1"
            OPENCODE_MODEL: "gpt-4"
```

### Q: How much does this cost to run?

**A:** Costs depend on:
- AI API usage (typically $0.01-0.10 per report)
- Kubernetes resources (minimal - ~100m CPU, 256Mi RAM)
- Notification services (usually free)

For a cluster running reports every 12 hours: ~$1-5/month in AI API costs.

### Q: Can I run this on-demand instead of on a schedule?

**A:** Yes! Create a manual job:

```bash
kubectl create job --from=cronjob/opencode-k8s-agent manual-investigation
```

Or change to a Deployment and trigger via API/webhook.

### Q: Is this secure? What data is sent to the AI?

**A:** The agent:
- Has read-only RBAC permissions
- Sends cluster metadata (pod names, statuses, events)
- Does NOT send: secrets, configmap contents, logs (unless you customize)
- Runs in your cluster (data doesn't leave except to AI API)

Review `files/runtime/prompt.md` to see exactly what's investigated.

### Q: Can I use this with Anthropic Claude?

**A:** Yes! Configure the provider:

```yaml
configMaps:
  runtime:
    opencode.json: |
      {
        "provider": {
          "anthropic": {
            "npm": "@ai-sdk/anthropic",
            "options": {
              "apiKey": "${OPENCODE_API_KEY}"
            },
            "models": {
              "claude-3-5-sonnet-20241022": {
                "id": "claude-3-5-sonnet-20241022",
                "tool_call": true
              }
            }
          }
        },
        "agent": {
          "coder": {
            "model": "anthropic:claude-3-5-sonnet-20241022"
          }
        }
      }
```

### Q: How do I test changes to prompts without waiting for the CronJob?

**A:** Create a manual job:

```bash
kubectl create job --from=cronjob/opencode-k8s-agent test-prompt
kubectl logs -f job/test-prompt
```

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [OpenCode](https://github.com/opencode-ai/opencode) - AI agent framework
- [Apprise](https://github.com/caronc/apprise) - Notification library
- [bjw-s app-template](https://github.com/bjw-s-labs/helm-charts) - Helm chart library
- [Kubernetes MCP](https://github.com/strowk/mcp-k8s-go) - Kubernetes Model Context Protocol server

## Support

- 📖 [Documentation](https://github.com/ADORSYS-GIS/opencode-k8s-agent/wiki)
- 💬 [Discussions](https://github.com/ADORSYS-GIS/opencode-k8s-agent/discussions)
- 🐛 [Issue Tracker](https://github.com/ADORSYS-GIS/opencode-k8s-agent/issues)
- 📧 Email: kingkoufan@gmail.com

---

**Made with ❤️ for Kubernetes operators who want to sleep better at night.**
