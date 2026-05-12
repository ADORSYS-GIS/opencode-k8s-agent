# Customization Guide

This guide explains how to customize OpenCode K8s Agent for your specific infrastructure and use cases.

## Table of Contents

- [Understanding the Configuration Files](#understanding-the-configuration-files)
- [Customizing Investigation Prompts](#customizing-investigation-prompts)
- [Writing Effective Runbooks](#writing-effective-runbooks)
- [Documenting Custom Resources](#documenting-custom-resources)
- [Adjusting RBAC Permissions](#adjusting-rbac-permissions)
- [Configuring Notifications](#configuring-notifications)
- [Environment-Specific Configuration](#environment-specific-configuration)
- [Advanced Customization](#advanced-customization)

## Understanding the Configuration Files

The agent uses three main configuration files that work together:

### 1. `opencode.json` - AI Provider Configuration

Configures the AI model and provider:

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

**When to customize:**
- Using a different AI provider (Anthropic, Azure OpenAI, etc.)
- Changing log level for debugging
- Adjusting model parameters

### 2. `prompt.md` - Investigation Instructions

The AI prompt that guides cluster investigation. This is the most important file to customize.

**Structure:**
```markdown
# Role Definition
You are a [type] agent for [environment].

## Investigation Scope
[What to investigate]

## Tasks
[Specific checks to perform]

## Report Format
[How to structure the output]
```

**When to customize:**
- Adapting to your infrastructure
- Focusing on specific services
- Changing investigation priorities
- Adjusting report format

### 3. `runbook.md` & `custom-resources.md` - Context Documentation

Provides context about your infrastructure that the AI reads before investigating.

**When to customize:**
- Documenting your services
- Adding known issues
- Providing escalation procedures
- Explaining custom resources

## Customizing Investigation Prompts

### Step 1: Identify Your Critical Services

List the services that matter most to your business:

```markdown
## Critical Services

### Production Namespace
- `api-gateway` - Customer-facing API (SLA: 99.9%)
- `web-app` - Web application (SLA: 99.9%)
- `payment-service` - Payment processing (SLA: 99.95%)

### Databases Namespace
- `postgres-main` - Primary database
- `redis-cache` - Session cache
```

### Step 2: Define Investigation Priorities

What should the agent check first?

```markdown
## Investigation Priority

1. **Critical Services** (production namespace)
   - Check if all pods are Running
   - Look for restarts > 5 in last 24h
   - Check for CrashLoopBackOff

2. **Databases** (databases namespace)
   - Verify PostgreSQL clusters are healthy
   - Check Redis availability
   - Verify backups completed successfully

3. **Background Jobs** (jobs namespace)
   - Check for failed CronJobs
   - Verify scheduled jobs ran on time
```

### Step 3: Set Alert Thresholds

Define what constitutes a problem:

```markdown
## Alert Thresholds

### Critical (Immediate Action Required)
- Any pod in CrashLoopBackOff
- Payment service with ANY restarts
- Database cluster with INSTANCES != READY
- Failed backup in last 24h

### Warning (Action Required Within 24h)
- Pod with > 5 restarts in 24h
- Pod using > 80% memory limit
- Node with DiskPressure or MemoryPressure
- Certificate expiring in < 30 days

### Info (Monitor)
- Pod with 1-5 restarts in 24h
- Pod using > 60% memory limit
- Completed jobs older than 48h
```

### Step 4: Define Report Format

Structure the output for your needs:

```markdown
## Report Format

# Executive Summary
[One paragraph: overall health, number of issues, severity]

## 🚨 Critical Issues
[Issues requiring IMMEDIATE attention]

## ⚠️ Warnings
[Issues requiring attention within 24h]

## 📊 Service Health
[Status of each critical service]

## 💾 Database Status
[Database cluster health]

## 💡 Recommendations
[Actionable steps to resolve issues]
```

### Complete Example

```yaml
configMaps:
  runtime:
    prompt.md: |
      You are a Kubernetes cluster investigation agent for an e-commerce platform.
      
      Your role is to analyze the cluster and produce a structured operational report.
      
      You MUST rely on tool outputs. Do not guess.
      You MUST NOT modify cluster resources.
      
      ## 🛡️ Investigation Process
      
      1. **Initial Context**: Read documentation in `/docs` to understand the infrastructure.
      
      2. **Critical Services** (Namespace: `production`):
         - `api-gateway` - Customer-facing API (SLA: 99.9%)
         - `web-app` - Web application (SLA: 99.9%)
         - `payment-service` - Payment processing (SLA: 99.95%)
         - `order-processor` - Order fulfillment (SLA: 99.5%)
      
      3. **Databases** (Namespace: `databases`):
         - PostgreSQL clusters (managed by CloudNativePG)
         - Redis caches
      
      4. **Background Jobs** (Namespace: `jobs`):
         - `email-sender` - Transactional emails
         - `report-generator` - Daily reports
         - `inventory-sync` - Inventory synchronization
      
      ## 📋 Investigation Tasks
      
      1. **Critical Service Health**:
         - Check if all critical services are Running
         - Look for pods with RESTARTS > 5 in last 24h
         - Check for CrashLoopBackOff or ImagePullBackOff
         - Verify HPA is scaling appropriately
      
      2. **Resource Pressure**:
         - Identify nodes with DiskPressure or MemoryPressure
         - Find pods near CPU/memory limits (>80%)
         - Check for pending PVCs
         - Look for pods in Pending state
      
      3. **Database Health**:
         - Verify all PostgreSQL clusters have INSTANCES = READY
         - Check for failed backups in last 24h
         - Verify Redis pods are healthy
         - Check database connection pools
      
      4. **Background Jobs**:
         - Check for failed CronJobs in last 24h
         - Verify scheduled jobs are running on time
         - Look for jobs stuck in Running state
         - Check job completion times
      
      5. **Events & Errors**:
         - Extract Warning/Error events from last 12 hours
         - Focus on events in production, databases, jobs namespaces
         - Ignore events in kube-system unless critical
         - Correlate events with pod issues
      
      6. **Custom Resources**:
         - Check Certificate resources for expiration (< 30 days)
         - Verify ExternalSecrets are synced
         - Check Ingress resources are healthy
         - Verify HPA resources are functioning
      
      ## 📄 Reporting Format
      
      Your final response MUST follow this template:
      
      # Executive Summary
      [One paragraph: overall cluster health, number of issues found, severity level]
      
      ## 🚨 Critical Issues
      [Issues requiring IMMEDIATE attention - service outages, data loss risk, security breaches]
      
      ## ⚠️ Warnings
      [Issues requiring attention within 24h - degraded performance, approaching limits, minor failures]
      
      ## 📊 Service Health
      
      ### API Gateway
      [Status, restarts, resource usage, recent events]
      
      ### Web Application
      [Status, restarts, resource usage, recent events]
      
      ### Payment Service
      [Status, restarts, resource usage, recent events]
      
      ### Order Processor
      [Status, restarts, resource usage, recent events]
      
      ## 💾 Database Status
      
      ### PostgreSQL Clusters
      [Cluster health, backup status, resource usage]
      
      ### Redis Caches
      [Availability, memory usage, eviction rate]
      
      ## ⏰ Background Jobs
      
      ### Email Sender
      [Last run, success rate, failures]
      
      ### Report Generator
      [Last run, completion time, output size]
      
      ### Inventory Sync
      [Last run, sync status, errors]
      
      ## 📈 Resource Utilization
      
      ### Nodes
      [CPU, memory, disk usage per node]
      
      ### Pods
      [Pods near limits, resource requests vs usage]
      
      ### Storage
      [PVC usage, available capacity]
      
      ## 💡 Recommendations
      [Actionable steps to resolve issues and improve cluster health]
      
      ---
      
      If no issues are found, explicitly state: "✅ All systems operational. No issues detected."
```

## Writing Effective Runbooks

A good runbook provides context that helps the AI understand your infrastructure.

### Service Documentation Template

```markdown
## Service Name

- **Deployment**: `deployment-name`
- **Namespace**: `namespace`
- **Replicas**: X (minimum)
- **Dependencies**: List of dependencies
- **SLA**: X% uptime
- **Alert Threshold**: When to alert
- **Escalation**: Who to contact
- **Known Issues**: Common problems and solutions
```

### Example

```yaml
configMaps:
  docs:
    runbook.md: |
      # Production Cluster Runbook
      
      ## Service Map
      
      ### API Gateway (production/api-gateway)
      
      - **Deployment**: `api-gateway`
      - **Namespace**: `production`
      - **Replicas**: 3 (minimum), scales to 10 with HPA
      - **Dependencies**: 
        - Redis cache (session storage)
        - PostgreSQL (user data)
        - External: Auth0 (authentication)
      - **SLA**: 99.9% uptime
      - **Alert Threshold**: 
        - > 3 restarts/hour
        - > 5% error rate
        - Response time > 500ms (p95)
      - **Escalation**: 
        - P0: Page on-call + team lead
        - P1: Page on-call
        - P2: Slack notification
      - **Known Issues**:
        - **Memory spikes during traffic bursts**: Expected behavior, HPA scales automatically
        - **Occasional 503 during deployments**: Rolling update strategy, < 1 minute downtime
        - **Redis connection timeouts**: Retry logic in place, self-healing
      
      ### Payment Service (production/payment-service)
      
      - **Deployment**: `payment-service`
      - **Namespace**: `production`
      - **Replicas**: 3 (minimum), NO autoscaling (compliance requirement)
      - **Dependencies**:
        - PostgreSQL payments-db (transaction log)
        - External: Stripe API (payment processing)
      - **SLA**: 99.95% uptime (CRITICAL)
      - **Alert Threshold**:
        - ANY restart (immediate investigation)
        - ANY failed transaction
        - Response time > 2s
      - **Escalation**:
        - ANY issue: IMMEDIATE page to on-call + team lead + CTO
      - **Known Issues**:
        - **Stripe API latency during peak hours**: Retry logic with exponential backoff
        - **Database connection pool exhaustion**: Increase pool size to 50 (planned Q2)
      
      ## Scheduled Maintenance Windows
      
      - **Database backups**: Daily at 2 AM UTC (5-10 minute performance impact)
      - **Certificate renewal**: Automatic, no downtime
      - **Kubernetes upgrades**: Quarterly, Saturday 2-6 AM UTC
      
      ## Escalation Matrix
      
      | Severity | Response Time | Notification | Examples |
      |----------|---------------|--------------|----------|
      | P0 - Critical | Immediate | Page on-call + team lead + CTO | Service outage, data loss, security breach |
      | P1 - High | 15 minutes | Page on-call | High error rate, pod crash loops |
      | P2 - Medium | 1 hour | Slack notification | Background job failures, high resource usage |
      | P3 - Low | Next business day | Ticket | Certificate expiring in 30 days, low disk space warning |
      
      ## On-Call Contacts
      
      - **Primary**: Slack #oncall-engineering
      - **Escalation**: Slack #engineering-leads
      - **Emergency**: PagerDuty (auto-pages from P0/P1 alerts)
```

## Documenting Custom Resources

Document how to investigate custom resources specific to your cluster.

### Template

```markdown
## Custom Resource Name

### Health Check
\`\`\`bash
kubectl get <resource> -n <namespace>
\`\`\`

**Healthy State**: [Description]

### Investigation Steps

1. **Check resource status**
2. **Check controller logs**
3. **Common issues and fixes**
```

### Example

```yaml
configMaps:
  docs:
    custom-resources.md: |
      # Custom Resources Investigation Guide
      
      ## CloudNativePG Clusters
      
      ### Health Check
      \`\`\`bash
      kubectl get cluster -n databases
      \`\`\`
      
      **Healthy State**: INSTANCES = READY (e.g., "3/3")
      
      ### Investigation Steps
      
      1. **Check cluster status**:
         \`\`\`bash
         kubectl describe cluster -n databases main-db
         \`\`\`
         Look for: Phase, Instances, Ready instances
      
      2. **Check controller logs**:
         \`\`\`bash
         kubectl logs -n cnpg-system deploy/cnpg-controller --tail=100
         \`\`\`
         Look for: Reconcile errors, leader election issues
      
      3. **Check backup status**:
         \`\`\`bash
         kubectl get backup -n databases
         \`\`\`
         Verify: Latest backup completed successfully
      
      4. **Check pod logs**:
         \`\`\`bash
         kubectl logs -n databases main-db-1 --tail=100
         \`\`\`
         Look for: Connection errors, replication lag
      
      ### Common Issues
      
      **Issue**: Cluster shows INSTANCES < READY (e.g., "2/3")
      - **Possible Causes**:
        - Pod scheduling failure (check node resources)
        - Image pull errors (check image availability)
        - PVC provisioning failure (check storage class)
      - **Investigation**:
        \`\`\`bash
        kubectl get pods -n databases -l cnpg.io/cluster=main-db
        kubectl describe pod -n databases main-db-3
        \`\`\`
      - **Resolution**:
        - If node resources: Scale cluster or add nodes
        - If image pull: Verify image tag and registry access
        - If PVC: Check storage class and provisioner
      
      **Issue**: Backup failures
      - **Possible Causes**:
        - S3 credentials expired
        - Network connectivity issues
        - S3 rate limiting
      - **Investigation**:
        \`\`\`bash
        kubectl logs -n cnpg-system deploy/cnpg-controller | grep backup
        kubectl describe backup -n databases <backup-name>
        \`\`\`
      - **Resolution**:
        - Verify S3 credentials in secret
        - Test S3 connectivity from pod
        - Check S3 bucket permissions
      
      **Issue**: High replication lag
      - **Possible Causes**:
        - Network latency between pods
        - High write load on primary
        - Insufficient replica resources
      - **Investigation**:
        \`\`\`bash
        kubectl exec -n databases main-db-1 -- psql -c "SELECT * FROM pg_stat_replication;"
        \`\`\`
      - **Resolution**:
        - Increase replica resources
        - Optimize queries on primary
        - Consider read replicas for read-heavy workloads
```

## Adjusting RBAC Permissions

Add permissions for custom resources in your cluster.

### Default Permissions

The chart includes read-only access to common resources:

```yaml
rbac:
  clusterRole:
    rules:
      - apiGroups: [""]
        resources: [nodes, pods, pods/log, events, services, endpoints, configmaps, persistentvolumeclaims]
        verbs: [get, list, watch]
      - apiGroups: ["apps"]
        resources: [deployments, statefulsets, daemonsets]
        verbs: [get, list, watch]
      - apiGroups: ["batch"]
        resources: [jobs, cronjobs]
        verbs: [get, list, watch]
```

### Adding Custom Resources

```yaml
rbac:
  clusterRole:
    rules:
      # ... default rules ...
      
      # Add your custom resources
      - apiGroups: ["your-operator.io"]
        resources: ["customresources"]
        verbs: [get, list, watch]
      
      # Example: Argo CD
      - apiGroups: ["argoproj.io"]
        resources: ["applications", "appprojects"]
        verbs: [get, list, watch]
      
      # Example: Istio
      - apiGroups: ["networking.istio.io"]
        resources: ["virtualservices", "destinationrules", "gateways"]
        verbs: [get, list, watch]
      
      # Example: Prometheus
      - apiGroups: ["monitoring.coreos.com"]
        resources: ["servicemonitors", "prometheusrules"]
        verbs: [get, list, watch]
```

## Configuring Notifications

### Single Channel

```yaml
APPRISE_URLS: "discord://webhook-id/webhook-token"
```

### Multiple Channels

```yaml
APPRISE_URLS: "discord://webhook-url slack://token email://user:pass@smtp.com"
```

### Environment-Specific Channels

```yaml
# Production
APPRISE_URLS: "pagerduty://integration-key slack://prod-channel email://oncall@example.com"

# Staging
APPRISE_URLS: "slack://staging-channel"

# Development
APPRISE_URLS: "discord://dev-webhook"
```

### Conditional Notifications

Modify `run.sh` to send to different channels based on severity:

```yaml
configMaps:
  runtime:
    run.sh: |
      #!/bin/bash
      # ... generate report ...
      
      # Check for critical issues
      if grep -qi "Critical Issues" "$REPORT_FILE"; then
        # Send to PagerDuty for critical issues
        APPRISE_URLS="${PAGERDUTY_URL} ${SLACK_URL}"
      else
        # Send to Slack only for normal reports
        APPRISE_URLS="${SLACK_URL}"
      fi
      
      # Send notification
      curl -X POST "${APPRISE_API_URL}/notify" \
        -F "body=<${REPORT_FILE}" \
        -F "title=${TITLE}" \
        -F "url=${APPRISE_URLS}"
```

## Environment-Specific Configuration

### Using Multiple Values Files

```bash
# Base configuration
values.yaml

# Environment-specific overrides
values-dev.yaml
values-staging.yaml
values-production.yaml
```

**Example: `values-production.yaml`**

```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */4 * * *"  # More frequent in production
      
      containers:
        main:
          image:
            tag: "v1.0.0"  # Pin version in production
          
          resources:
            limits:
              cpu: 2000m
              memory: 2Gi

configMaps:
  runtime:
    prompt.md: |
      You are monitoring the PRODUCTION environment.
      CRITICAL: Any issues require immediate attention.
      # ... production-specific prompt ...
```

### Using ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: opencode-k8s-agent-prod
spec:
  source:
    helm:
      valueFiles:
        - values.yaml
        - values-production.yaml
```

## Advanced Customization

### Custom Execution Script

Modify `run.sh` to add custom logic:

```yaml
configMaps:
  runtime:
    run.sh: |
      #!/bin/bash
      set -euo pipefail
      
      echo "[Custom] Starting investigation..."
      
      # Pre-checks
      echo "[Custom] Running pre-checks..."
      kubectl cluster-info || exit 1
      
      # Custom metric collection
      echo "[Custom] Collecting custom metrics..."
      kubectl top nodes > /tmp/node-metrics.txt
      kubectl top pods -A > /tmp/pod-metrics.txt
      
      # Run OpenCode investigation
      echo "[Custom] Running AI investigation..."
      opencode run "$(cat /config/prompt.md)" \
        --agent coder \
        --model "lightbridge/${OPENCODE_MODEL}" \
        --dangerously-skip-permissions \
        --thinking \
        > /tmp/report.txt
      
      # Post-processing
      echo "[Custom] Post-processing report..."
      
      # Add custom metrics to report
      echo -e "\n\n## Custom Metrics\n" >> /tmp/report.txt
      echo "### Node Metrics" >> /tmp/report.txt
      cat /tmp/node-metrics.txt >> /tmp/report.txt
      
      # Send notification
      echo "[Custom] Sending notification..."
      curl -X POST "${APPRISE_API_URL}/notify" \
        -F "body=</tmp/report.txt" \
        -F "title=Cluster Report: $(date +'%Y-%m-%d %H:%M')" \
        -F "url=${APPRISE_URLS}"
      
      echo "[Custom] Complete!"
```

### Multiple AI Models

Use different models for different checks:

```yaml
configMaps:
  runtime:
    run.sh: |
      #!/bin/bash
      
      # Quick check with fast model
      opencode run "Quick health check" \
        --model "openai:gpt-3.5-turbo" \
        > /tmp/quick-check.txt
      
      # Detailed analysis with powerful model
      opencode run "$(cat /config/prompt.md)" \
        --model "openai:gpt-4" \
        > /tmp/detailed-report.txt
      
      # Combine reports
      cat /tmp/quick-check.txt /tmp/detailed-report.txt > /tmp/final-report.txt
```

### Custom Report Formatting

Format reports for specific notification channels:

```yaml
configMaps:
  runtime:
    run.sh: |
      #!/bin/bash
      
      # Generate report
      opencode run "$(cat /config/prompt.md)" > /tmp/report.txt
      
      # Format for Discord (2000 char limit)
      head -c 1800 /tmp/report.txt > /tmp/discord-report.txt
      
      # Format for Slack (with formatting)
      sed 's/^# /\*\*/g' /tmp/report.txt | \
        sed 's/^## /\*/g' > /tmp/slack-report.txt
      
      # Send to different channels
      curl -X POST "${APPRISE_API_URL}/notify" \
        -F "body=</tmp/discord-report.txt" \
        -F "url=${DISCORD_URL}"
      
      curl -X POST "${APPRISE_API_URL}/notify" \
        -F "body=</tmp/slack-report.txt" \
        -F "url=${SLACK_URL}"
```

## Testing Your Customizations

### 1. Lint the Chart

```bash
helm lint .
```

### 2. Template and Verify

```bash
helm template test . -f custom-values.yaml | less
```

### 3. Dry Run Install

```bash
helm install test . -f custom-values.yaml --dry-run --debug
```

### 4. Install in Test Cluster

```bash
helm install test . -f custom-values.yaml
```

### 5. Trigger Manual Run

```bash
kubectl create job --from=cronjob/test-opencode-k8s-agent manual-test
kubectl logs -f job/manual-test
```

### 6. Verify Report

Check your notification channel for the report and verify:
- All expected sections are present
- Information is accurate
- Format is correct
- Recommendations are actionable

## Best Practices

1. **Start Simple**: Begin with default configuration, then customize incrementally
2. **Test Thoroughly**: Test each customization in a non-production environment
3. **Document Changes**: Keep notes on why you made specific customizations
4. **Version Control**: Store your values files in Git
5. **Review Regularly**: Review and update prompts as your infrastructure evolves
6. **Monitor Performance**: Watch resource usage and adjust limits as needed
7. **Iterate**: Refine prompts based on report quality and usefulness

## Getting Help

If you need help with customization:

1. Check the [examples](examples/) directory
2. Review the [FAQ](README.md#faq)
3. Search [GitHub Discussions](https://github.com/ADORSYS-GIS/opencode-k8s-agent/discussions)
4. Open a [new discussion](https://github.com/ADORSYS-GIS/opencode-k8s-agent/discussions/new)

## Contributing Your Customizations

If you've created a useful customization, consider sharing it!

See [CONTRIBUTING.md](CONTRIBUTING.md#sharing-custom-prompts) for how to contribute custom prompts and configurations.
