# Production Configuration Example

This example shows a production-ready configuration with:

- Custom prompts tailored to your infrastructure
- Multiple notification channels
- Extended resource limits
- Custom RBAC for your CRDs
- Detailed runbooks and documentation

## Features

✅ Runs every 4 hours  
✅ Custom investigation prompts for your services  
✅ Detailed runbook with escalation procedures  
✅ Multiple notification channels (Discord, Slack, Email)  
✅ Extended timeout for large clusters  
✅ Pinned image version  
✅ Custom RBAC for your CRDs  

## Installation

### 1. Customize the configuration

Edit `values.yaml` and update:

- **Services**: Replace example services with your actual services
- **Namespaces**: Update namespace names to match your cluster
- **RBAC**: Add your custom resource definitions
- **Notification URLs**: Set your Discord, Slack, email URLs
- **API Key**: Set your OpenAI API key

### 2. Review the custom prompt

The `configMaps.runtime.prompt.md` section contains the investigation logic.
Customize it to match your infrastructure:

- Service names and namespaces
- SLA requirements
- Alert thresholds
- Investigation priorities

### 3. Update the runbook

The `configMaps.docs.runbook.md` section contains operational procedures.
Update it with:

- Your service map
- Known issues specific to your cluster
- Escalation procedures
- On-call contacts

### 4. Install

```bash
# Install Apprise API first
helm install apprise-api ../../apprise-api

# Install the agent with production config
helm install opencode-k8s-agent ../.. -f values.yaml
```

### 5. Test

```bash
# Trigger a manual run
kubectl create job --from=cronjob/opencode-k8s-agent prod-test

# Watch logs
kubectl logs -f job/prod-test

# Check your notification channels
```

## Customization Guide

### Adding Your Services

1. **Update the prompt** (`configMaps.runtime.prompt.md`):

```markdown
2. **Critical Services** (Namespace: `your-namespace`):
   - `your-service-1` - Description (SLA: 99.9%)
   - `your-service-2` - Description (SLA: 99.5%)
```

2. **Update the runbook** (`configMaps.docs.runbook.md`):

```markdown
#### Your Service
- **Deployment**: `your-service`
- **Replicas**: 3 (minimum)
- **Dependencies**: Database, Cache
- **SLA**: 99.9% uptime
- **Alert Threshold**: > 5 restarts/hour
```

### Adding Custom Resources

1. **Add RBAC permissions**:

```yaml
rbac:
  clusterRole:
    rules:
      - apiGroups: ["your-operator.io"]
        resources: ["yourresources"]
        verbs: [get, list, watch]
```

2. **Add investigation steps** (`configMaps.docs.custom-resources.md`):

```markdown
## Your Custom Resource

### Health Check
\`\`\`bash
kubectl get yourresource -A
\`\`\`

### Investigation Steps
1. Check status
2. Check controller logs
3. Common issues and fixes
```

### Adjusting Schedule

For more frequent checks:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 */2 * * *"  # Every 2 hours
```

For less frequent checks:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      cronjob:
        schedule: "0 8,20 * * *"  # Twice daily at 8 AM and 8 PM
```

### Multiple Notification Channels

```yaml
APPRISE_URLS: "discord://webhook-url slack://token email://user:pass@smtp.example.com"
```

See [Apprise documentation](https://github.com/caronc/apprise/wiki) for all supported services.

## Monitoring the Agent

### Check CronJob Status

```bash
kubectl get cronjob opencode-k8s-agent
```

### View Recent Jobs

```bash
kubectl get jobs -l app.kubernetes.io/name=opencode-k8s-agent --sort-by=.metadata.creationTimestamp
```

### Check Logs

```bash
# Get latest job
LATEST_JOB=$(kubectl get jobs -l app.kubernetes.io/name=opencode-k8s-agent --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# View logs
kubectl logs job/$LATEST_JOB
```

### Verify Reports

Check your notification channels for reports. Each report should include:

- Executive Summary
- Critical Issues (if any)
- Service Health
- Database Status
- Background Jobs
- Recommendations

## Troubleshooting

### No Reports Received

1. Check job logs for errors
2. Verify Apprise API is running
3. Test notification URLs manually
4. Check RBAC permissions

### Incomplete Reports

1. Verify RBAC includes all needed resources
2. Check for timeout (increase `activeDeadlineSeconds`)
3. Review prompt for clarity

### High Resource Usage

1. Reduce check frequency
2. Lower resource limits
3. Optimize prompt to check fewer resources

## Next Steps

- Set up alerting on failed jobs
- Create dashboards for job metrics
- Implement log aggregation
- Schedule regular prompt reviews
- Document incident response procedures
