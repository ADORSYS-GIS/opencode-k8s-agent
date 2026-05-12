# Basic Configuration Example

This is the minimal configuration to get OpenCode K8s Agent running.

## Prerequisites

1. Kubernetes cluster
2. OpenAI API key
3. Discord webhook URL (or other notification channel)

## Installation Steps

### 1. Install Apprise API

```bash
helm install apprise-api ../../apprise-api
```

### 2. Update values.yaml

Edit `values.yaml` and set:
- `OPENCODE_API_KEY`: Your OpenAI API key
- `APPRISE_URLS`: Your Discord webhook URL

### 3. Install the agent

```bash
helm install opencode-k8s-agent ../.. -f values.yaml
```

### 4. Verify installation

```bash
# Check CronJob is created
kubectl get cronjob opencode-k8s-agent

# Trigger a manual run
kubectl create job --from=cronjob/opencode-k8s-agent test-run

# Watch the logs
kubectl logs -f job/test-run
```

### 5. Check your Discord channel

You should receive a cluster health report within a few minutes!

## What This Configuration Does

- Runs every 12 hours
- Uses OpenAI GPT-4 for analysis
- Sends reports to Discord
- Uses default investigation prompts
- Has read-only access to cluster resources

## Next Steps

- Customize the schedule in `controllers.main.cronjob.schedule`
- Add more notification channels to `APPRISE_URLS`
- Customize prompts (see production example)
