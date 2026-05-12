# OpenCode K8s Agent

> **AI-Powered Kubernetes Cluster Health Monitoring**  
> Never get caught off-guard by cluster issues again.

[![Helm Version](https://img.shields.io/badge/helm-v3.0+-blue.svg)](https://helm.sh)
[![Kubernetes Version](https://img.shields.io/badge/kubernetes-v1.22+-blue.svg)](https://kubernetes.io)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

## What is OpenCode K8s Agent?

OpenCode K8s Agent is an intelligent Kubernetes monitoring solution that uses AI to proactively investigate your cluster health and send structured reports to your notification channels. 

Unlike traditional monitoring tools that require complex rule configuration, this agent uses natural language prompts to understand what matters in your cluster and adapts to your specific infrastructure.

### The Problem

Traditional Kubernetes monitoring requires:
- Complex alert rule configuration
- Constant tuning to reduce noise
- Deep knowledge of what to monitor
- Manual correlation of issues across resources
- Separate tools for different resource types

### The Solution

OpenCode K8s Agent:
- 🤖 Uses AI to intelligently investigate cluster state
- 📝 Configured with natural language prompts
- 🔍 Automatically correlates issues across resources
- 📊 Generates executive summaries with actionable recommendations
- 🎯 Adapts to your specific infrastructure and priorities
- 🔔 Sends structured reports to your notification channels

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.22+)
- Helm 3.0+
- OpenAI API key (or compatible endpoint)
- Notification channel (Discord, Slack, etc.)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/ADORSYS-GIS/opencode-k8s-agent
cd opencode-k8s-agent

# 2. Install Apprise API (notification gateway)
helm install apprise-api ./helm/apprise-api

# 3. Create secrets
kubectl create secret generic opencode-k8s-agent-secrets \
  --from-literal=OPENCODE_API_KEY="sk-your-api-key" \
  --from-literal=APPRISE_URLS="discord://webhook-id/webhook-token"

# 4. Install the agent
helm install opencode-k8s-agent ./helm/opencode-k8s-agent

# 5. Trigger a test run
kubectl create job --from=cronjob/opencode-k8s-agent test-run

# 6. Watch the logs
kubectl logs -f job/test-run
```

Within a few minutes, you'll receive a cluster health report in your notification channel!

## Features

### 🤖 AI-Powered Analysis

Uses OpenCode with Kubernetes MCP (Model Context Protocol) to intelligently investigate cluster state. The AI understands Kubernetes concepts and can reason about complex issues.

### 📊 Structured Reporting

Generates executive summaries with:
- Critical issues requiring immediate attention
- Service health status
- Resource utilization
- Actionable recommendations

### 🔔 Multi-Channel Notifications

Integrates with 100+ notification services via Apprise:
- Discord
- Slack
- Email
- Microsoft Teams
- PagerDuty
- And many more...

### 🔒 Secure by Default

- Read-only RBAC permissions
- No cluster modification capabilities
- Secrets managed via Kubernetes secrets
- Optional OIDC authentication

### ⚙️ Fully Customizable

- Override investigation prompts for your use case
- Customize documentation for your infrastructure
- Add custom resource types
- Adjust RBAC permissions
- Configure notification formats

### 🚀 GitOps Ready

First-class support for ArgoCD and Flux:
- Values overrides for environment-specific config
- Files embedded in chart for defaults
- No external dependencies

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                              │
│  ┌────────────────┐                                         │
│  │   CronJob      │  Runs on schedule (default: 12h)       │
│  │  (Scheduled)   │                                         │
│  └───────┬────────┘                                         │
│          │                                                   │
│          ▼                                                   │
│  ┌────────────────┐                                         │
│  │  OpenCode      │  ┌─────────────────────────────┐       │
│  │  Agent Pod     │──│ Kubernetes API              │       │
│  │                │  │ (Read-Only Access)          │       │
│  │  ┌──────────┐  │  └─────────────────────────────┘       │
│  │  │ OpenCode │  │                                         │
│  │  │   CLI    │  │  Reads:                                │
│  │  └────┬─────┘  │  • Pod status                          │
│  │       │        │  • Events                              │
│  │       ▼        │  • Resource metrics                    │
│  │  ┌──────────┐  │  • Custom resources                    │
│  │  │   MCP    │  │                                         │
│  │  │  Server  │  │  Analyzes with AI:                     │
│  │  │   (K8s)  │  │  • Correlates issues                   │
│  │  └──────────┘  │  • Identifies problems                 │
│  │                │  • Generates recommendations           │
│  └───────┬────────┘                                         │
│          │                                                   │
│          ▼                                                   │
│  ┌────────────────┐                                         │
│  │  Apprise API   │  Notification Gateway                  │
│  │  (Service)     │                                         │
│  └───────┬────────┘                                         │
│          │                                                   │
└──────────┼─────────────────────────────────────────────────┘
           │
           ▼
    ┌──────────────┐
    │ Notification │  Discord, Slack, Email, etc.
    │  Channels    │
    └──────────────┘
```

## Use Cases

### 1. Proactive Monitoring

Get regular health reports without configuring complex alert rules:

```yaml
# Run every 6 hours
schedule: "0 */6 * * *"
```

### 2. Cost Optimization

Configure the agent to focus on cost-related issues:

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a cost optimization agent.
      Focus on:
      - Pods with low resource utilization
      - Over-provisioned requests
      - Unused PVCs
      - Scaling opportunities
```

### 3. Security Auditing

Monitor security posture:

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a security audit agent.
      Check for:
      - Pods running as root
      - Missing network policies
      - Exposed secrets
      - RBAC violations
```

### 4. Compliance Monitoring

Ensure organizational policies are followed:

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a compliance monitoring agent.
      Verify:
      - All resources have required labels
      - All namespaces have resource quotas
      - All services have documentation
```

### 5. Multi-Cluster Monitoring

Deploy in each cluster with cluster-specific configuration:

```yaml
# cluster-us-east.yaml
configMaps:
  runtime:
    prompt.md: |
      You are monitoring the US-EAST production cluster.
      Focus on services serving North American customers...

# cluster-eu-west.yaml
configMaps:
  runtime:
    prompt.md: |
      You are monitoring the EU-WEST production cluster.
      Focus on GDPR compliance and European services...
```

## Documentation

### Getting Started

- [Quick Start Guide](helm/opencode-k8s-agent/README.md#quick-start)
- [Installation](helm/opencode-k8s-agent/README.md#installation)
- [Configuration](helm/opencode-k8s-agent/README.md#configuration)

### Examples

- [Basic Configuration](helm/opencode-k8s-agent/examples/basic/) - Minimal setup
- [Production Configuration](helm/opencode-k8s-agent/examples/production/) - Production-ready with custom prompts
- [Cost Optimization](helm/opencode-k8s-agent/examples/cost-optimization/) - Focus on cost savings
- [Security Audit](helm/opencode-k8s-agent/examples/security-audit/) - Security-focused monitoring

### Advanced Topics

- [Customization Guide](helm/opencode-k8s-agent/README.md#customization)
- [ArgoCD Integration](helm/opencode-k8s-agent/README.md#argocd--gitops-integration)
- [Troubleshooting](helm/opencode-k8s-agent/README.md#troubleshooting)
- [Contributing](helm/opencode-k8s-agent/CONTRIBUTING.md)

## Repository Structure

```
.
├── README.md                          # This file
├── LICENSE                            # Apache 2.0 license
├── .gitignore                         # Git ignore rules
│
├── helm/
│   ├── opencode-k8s-agent/           # Main Helm chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── README.md                 # Detailed chart documentation
│   │   ├── CONTRIBUTING.md           # Contribution guidelines
│   │   ├── templates/                # Helm templates
│   │   │   ├── configmaps.yaml
│   │   │   └── rbac.yaml
│   │   ├── files/                    # Default configuration files
│   │   │   ├── runtime/
│   │   │   │   ├── opencode.json    # OpenCode configuration
│   │   │   │   ├── prompt.md        # Investigation prompt
│   │   │   │   └── run.sh           # Execution script
│   │   │   └── docs/
│   │   │       ├── runbook.md       # Operational runbook
│   │   │       └── custom-resources.md  # CRD investigation guide
│   │   └── examples/                 # Usage examples
│   │       ├── basic/
│   │       ├── production/
│   │       ├── cost-optimization/
│   │       └── security-audit/
│   │
│   └── apprise-api/                  # Apprise API chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── README.md
│
└── docker/                           # Docker image (if applicable)
    └── Dockerfile
```

## Configuration Overview

### Basic Configuration

```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */12 * * *"  # Every 12 hours
      containers:
        main:
          env:
            OPENCODE_MODEL: "gpt-4"
            OPENCODE_BASE_URL: "https://api.openai.com/v1"
  
  secrets:
    secrets:
      stringData:
        OPENCODE_API_KEY: "sk-..."
        APPRISE_URLS: "discord://webhook-url"
```

### Custom Prompts

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are monitoring a production e-commerce cluster.
      
      Focus on:
      - Customer-facing services (frontend, api-gateway)
      - Payment processing (payment-service)
      - Order fulfillment (order-processor)
      
      Alert on:
      - Any service with > 5 restarts/hour
      - Failed payment transactions
      - Database connection issues
```

### Custom Documentation

```yaml
configMaps:
  docs:
    runbook.md: |
      # My Cluster Runbook
      
      ## Critical Services
      - frontend: Customer-facing web app
      - api: Backend API
      - payments: Payment processing (CRITICAL)
      
      ## Known Issues
      - Frontend restarts during traffic spikes (expected)
      - Payment service timeout during peak hours (retry logic in place)
```

## Integration with Apprise API

The agent uses Apprise API as a notification gateway, supporting 100+ services.

### Standalone Deployment

```bash
# Deploy Apprise API
helm install apprise-api ./helm/apprise-api

# Agent automatically connects to http://apprise-api:8000
```

### External Apprise API

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          env:
            APPRISE_API_URL: "https://apprise.example.com"
```

### Supported Notification Services

- **Chat**: Discord, Slack, Microsoft Teams, Mattermost, Rocket.Chat
- **Email**: SMTP, Gmail, Outlook, SendGrid, Mailgun
- **Incident Management**: PagerDuty, Opsgenie, VictorOps
- **SMS**: Twilio, AWS SNS, Nexmo
- **And 90+ more...**

See [Apprise documentation](https://github.com/caronc/apprise/wiki) for complete list.

## Comparison with Other Tools

| Feature | OpenCode K8s Agent | Prometheus + Alertmanager | Datadog | New Relic |
|---------|-------------------|---------------------------|---------|-----------|
| **AI-Powered Analysis** | ✅ | ❌ | Partial | Partial |
| **Natural Language Config** | ✅ | ❌ | ❌ | ❌ |
| **Executive Summaries** | ✅ | ❌ | ❌ | ❌ |
| **Automatic Correlation** | ✅ | ❌ | ✅ | ✅ |
| **Custom Prompts** | ✅ | ❌ | ❌ | ❌ |
| **Self-Hosted** | ✅ | ✅ | ❌ | ❌ |
| **Cost** | API usage only | Free | $$$ | $$$ |
| **Setup Complexity** | Low | High | Medium | Medium |
| **Customization** | High | High | Medium | Medium |

## FAQ

### Q: How much does this cost to run?

**A:** Costs depend on AI API usage. For a cluster running reports every 12 hours:
- AI API: ~$1-5/month (depending on model and cluster size)
- Kubernetes resources: Minimal (~100m CPU, 256Mi RAM)
- Notification services: Usually free

### Q: Can I use this with OpenAI?

**A:** Yes! Just configure:

```yaml
env:
  OPENCODE_BASE_URL: "https://api.openai.com/v1"
  OPENCODE_MODEL: "gpt-4"
```

### Q: Can I use this with Anthropic Claude?

**A:** Yes! See [configuration examples](helm/opencode-k8s-agent/README.md#faq).

### Q: Is this secure?

**A:** Yes:
- Read-only RBAC permissions by default
- No cluster modification capabilities
- Secrets managed via Kubernetes secrets
- Data only sent to AI API (you control the endpoint)

### Q: Can I run this on-demand?

**A:** Yes! Create a manual job:

```bash
kubectl create job --from=cronjob/opencode-k8s-agent manual-check
```

### Q: How do I customize for my cluster?

**A:** See the [Customization Guide](helm/opencode-k8s-agent/README.md#customization) and [Production Example](helm/opencode-k8s-agent/examples/production/).

## Contributing

We welcome contributions! See [CONTRIBUTING.md](helm/opencode-k8s-agent/CONTRIBUTING.md) for guidelines.

Ways to contribute:
- 🐛 Report bugs
- 💡 Suggest features
- 📝 Improve documentation
- 🔧 Submit bug fixes
- ✨ Add new features
- 📊 Share custom prompts

## Community

- **GitHub Discussions**: [Ask questions and share ideas](https://github.com/ADORSYS-GIS/opencode-k8s-agent/discussions)
- **GitHub Issues**: [Report bugs and request features](https://github.com/ADORSYS-GIS/opencode-k8s-agent/issues)
- **Pull Requests**: [Contribute code](https://github.com/ADORSYS-GIS/opencode-k8s-agent/pulls)

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [OpenCode](https://github.com/opencode-ai/opencode) - AI agent framework
- [Apprise](https://github.com/caronc/apprise) - Notification library
- [bjw-s app-template](https://github.com/bjw-s-labs/helm-charts) - Helm chart library
- [Kubernetes MCP](https://github.com/strowk/mcp-k8s-go) - Kubernetes Model Context Protocol server

## Support

- 📖 [Documentation](helm/opencode-k8s-agent/README.md)
- 💬 [Discussions](https://github.com/ADORSYS-GIS/opencode-k8s-agent/discussions)
- 🐛 [Issue Tracker](https://github.com/ADORSYS-GIS/opencode-k8s-agent/issues)

---

**Made with ❤️ for Kubernetes operators who want to sleep better at night.**

⭐ Star this repo if you find it useful!
