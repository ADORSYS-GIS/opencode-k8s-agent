# Apprise API Helm Chart

> **Notification Gateway for 100+ Services**  
> Send notifications to Discord, Slack, Email, and 90+ other services via a simple API.

## Overview

This Helm chart deploys [Apprise API](https://github.com/caronc/apprise), a notification gateway that provides a unified API for sending notifications to 100+ different services.

Apprise API is designed to work seamlessly with the OpenCode K8s Agent but can be used standalone for any notification needs.

## Features

- 🔔 **100+ Services**: Discord, Slack, Email, Teams, PagerDuty, and many more
- 🚀 **Simple API**: Single endpoint for all notification services
- 📦 **Lightweight**: Minimal resource requirements
- 🔒 **Secure**: No data persistence, stateless operation
- ⚡ **Fast**: Asynchronous notification delivery

## Quick Start

### Installation

```bash
helm install apprise-api .
```

### Verify Installation

```bash
kubectl get pods -l app.kubernetes.io/name=apprise-api
kubectl get svc apprise-api
```

### Test the API

```bash
# Port forward to access locally
kubectl port-forward svc/apprise-api 8000:8000

# Send a test notification
curl -X POST http://localhost:8000/notify \
  -d "urls=discord://webhook-id/webhook-token" \
  -d "body=Hello from Apprise API!"
```

## Configuration

### Basic Configuration

```yaml
apprise-api:
  controllers:
    main:
      replicas: 1  # Increase for high availability
  
  service:
    main:
      ports:
        http:
          port: 8000
  
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 64Mi
```

### High Availability

```yaml
apprise-api:
  controllers:
    main:
      replicas: 3  # Multiple replicas for HA
      
      strategy: RollingUpdate  # Rolling updates
  
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 128Mi
```

### Resource Limits

For high-volume usage:

```yaml
apprise-api:
  resources:
    limits:
      cpu: 2000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 256Mi
```

## Usage

### API Endpoints

#### POST /notify

Send a notification to one or more services.

**Parameters:**
- `urls` (required): Space-separated list of notification URLs
- `body` (required): Notification message body
- `title` (optional): Notification title
- `type` (optional): Message type (info, success, warning, failure)
- `attach` (optional): File attachment

**Example:**

```bash
curl -X POST http://apprise-api:8000/notify \
  -F "urls=discord://webhook-url slack://token" \
  -F "title=Alert" \
  -F "body=Something happened!" \
  -F "type=warning"
```

#### GET /

Health check endpoint.

```bash
curl http://apprise-api:8000/
```

### Notification URL Formats

#### Discord

```
discord://webhook-id/webhook-token
```

#### Slack

```
slack://token-a/token-b/token-c
slack://token-a/token-b/token-c/#channel
```

#### Email

```
mailto://user:password@domain.com
mailto://user:password@domain.com?to=recipient@example.com
```

#### Microsoft Teams

```
msteams://token-a/token-b/token-c
```

#### PagerDuty

```
pagerduty://integration-key@account
```

#### Telegram

```
tgram://bot-token/chat-id
```

See [Apprise URL documentation](https://github.com/caronc/apprise/wiki) for all supported services.

## Integration with OpenCode K8s Agent

The OpenCode K8s Agent uses Apprise API to send cluster health reports.

### Same Namespace

If both are in the same namespace, the agent automatically connects:

```bash
# Install Apprise API
helm install apprise-api .

# Install OpenCode K8s Agent (automatically uses http://apprise-api:8000)
helm install opencode-k8s-agent ../opencode-k8s-agent
```

### Different Namespace

If in different namespaces, configure the agent:

```yaml
# OpenCode K8s Agent values
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          env:
            APPRISE_API_URL: "http://apprise-api.notifications.svc.cluster.local:8000"
```

### External Apprise API

To use an external Apprise API instance:

```yaml
opencode-k8s-agent:
  controllers:
    main:
      containers:
        main:
          env:
            APPRISE_API_URL: "https://apprise.example.com"
```

## Exposing the API

### Via Ingress

```yaml
apprise-api:
  ingress:
    main:
      enabled: true
      hosts:
        - host: apprise.example.com
          paths:
            - path: /
              pathType: Prefix
              service:
                identifier: main
                port: http
      tls:
        - secretName: apprise-tls
          hosts:
            - apprise.example.com
```

### Via LoadBalancer

```yaml
apprise-api:
  service:
    main:
      type: LoadBalancer
      ports:
        http:
          port: 8000
```

### Via NodePort

```yaml
apprise-api:
  service:
    main:
      type: NodePort
      ports:
        http:
          port: 8000
          nodePort: 30800
```

## Security Considerations

### Network Policies

Restrict access to Apprise API:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: apprise-api-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: apprise-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: opencode-k8s-agent
      ports:
        - protocol: TCP
          port: 8000
```

### Authentication

Apprise API doesn't have built-in authentication. For production use:

1. **Use Network Policies** to restrict access
2. **Deploy behind an API Gateway** with authentication
3. **Use Ingress with OAuth2 Proxy** for external access

Example with OAuth2 Proxy:

```yaml
apprise-api:
  ingress:
    main:
      enabled: true
      annotations:
        nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.example.com/oauth2/auth"
        nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.example.com/oauth2/start"
```

## Monitoring

### Health Checks

```bash
# Check if API is responding
curl http://apprise-api:8000/

# Expected response: HTML page with Apprise API info
```

### Metrics

Apprise API doesn't expose Prometheus metrics by default. To monitor:

1. **Use Kubernetes metrics**:
   ```bash
   kubectl top pod -l app.kubernetes.io/name=apprise-api
   ```

2. **Monitor logs**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=apprise-api -f
   ```

3. **Use a sidecar** for metrics collection

## Troubleshooting

### API Not Responding

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=apprise-api

# Check logs
kubectl logs -l app.kubernetes.io/name=apprise-api

# Check service
kubectl get svc apprise-api
kubectl describe svc apprise-api
```

### Notifications Not Sending

1. **Test the notification URL manually**:
   ```bash
   kubectl port-forward svc/apprise-api 8000:8000
   curl -X POST http://localhost:8000/notify \
     -d "urls=your-notification-url" \
     -d "body=Test message"
   ```

2. **Check logs for errors**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=apprise-api | grep -i error
   ```

3. **Verify notification URL format**:
   - Check [Apprise documentation](https://github.com/caronc/apprise/wiki) for correct format
   - Test URL with Apprise CLI locally

### High Memory Usage

If memory usage is high:

1. **Increase memory limits**:
   ```yaml
   resources:
     limits:
       memory: 512Mi
   ```

2. **Scale horizontally**:
   ```yaml
   controllers:
     main:
       replicas: 3
   ```

## Examples

### Send to Multiple Channels

```bash
curl -X POST http://apprise-api:8000/notify \
  -d "urls=discord://webhook1 slack://token email://user:pass@smtp.com" \
  -d "title=Multi-Channel Alert" \
  -d "body=This goes to Discord, Slack, and Email!"
```

### Send with Attachment

```bash
curl -X POST http://apprise-api:8000/notify \
  -F "urls=discord://webhook-url" \
  -F "title=Report" \
  -F "body=See attached file" \
  -F "attach=@/path/to/file.txt"
```

### Different Message Types

```bash
# Info (default)
curl -X POST http://apprise-api:8000/notify \
  -d "urls=discord://webhook" \
  -d "body=Informational message" \
  -d "type=info"

# Success
curl -X POST http://apprise-api:8000/notify \
  -d "urls=discord://webhook" \
  -d "body=Operation successful!" \
  -d "type=success"

# Warning
curl -X POST http://apprise-api:8000/notify \
  -d "urls=discord://webhook" \
  -d "body=Warning: Check this" \
  -d "type=warning"

# Failure
curl -X POST http://apprise-api:8000/notify \
  -d "urls=discord://webhook" \
  -d "body=Operation failed!" \
  -d "type=failure"
```

## Supported Services

Apprise supports 100+ notification services including:

**Chat & Collaboration:**
- Discord
- Slack
- Microsoft Teams
- Mattermost
- Rocket.Chat
- Telegram
- WhatsApp

**Email:**
- SMTP
- Gmail
- Outlook
- SendGrid
- Mailgun
- Amazon SES

**Incident Management:**
- PagerDuty
- Opsgenie
- VictorOps
- Splunk On-Call

**SMS:**
- Twilio
- AWS SNS
- Nexmo
- Clickatell

**And many more...**

See [complete list](https://github.com/caronc/apprise/wiki) in Apprise documentation.

## Configuration Reference

### Complete Values Schema

```yaml
apprise-api:
  global:
    nameOverride: string
    fullnameOverride: string
  
  image:
    repository: string
    tag: string
    pullPolicy: IfNotPresent|Always|Never
  
  controllers:
    main:
      enabled: bool
      type: deployment
      replicas: int
      strategy: RollingUpdate|Recreate
      containers:
        main:
          image:
            repository: string
            tag: string
            pullPolicy: string
  
  service:
    main:
      controller: main
      type: ClusterIP|LoadBalancer|NodePort
      ports:
        http:
          port: int
          nodePort: int  # Only for NodePort
  
  ingress:
    main:
      enabled: bool
      hosts: []object
      tls: []object
  
  resources:
    limits:
      cpu: string
      memory: string
    requests:
      cpu: string
      memory: string
```

## FAQ

### Q: Can I use this without OpenCode K8s Agent?

**A:** Yes! Apprise API is a standalone service that can be used by any application.

### Q: Does Apprise API store notification history?

**A:** No, Apprise API is stateless and doesn't store any data.

### Q: Can I rate limit notifications?

**A:** Apprise API doesn't have built-in rate limiting. Use an API gateway or ingress controller for rate limiting.

### Q: How do I secure the API?

**A:** Use Network Policies to restrict access, or deploy behind an API gateway with authentication.

### Q: Can I use custom notification templates?

**A:** Apprise API uses default templates. For custom templates, you'll need to format the message body before sending.

## License

Apache License 2.0 - see [LICENSE](../../LICENSE) for details.

## Links

- [Apprise GitHub](https://github.com/caronc/apprise)
- [Apprise API GitHub](https://github.com/caronc/apprise-api)
- [Apprise Documentation](https://github.com/caronc/apprise/wiki)
- [OpenCode K8s Agent](../opencode-k8s-agent/)

## Support

- 📖 [Apprise Documentation](https://github.com/caronc/apprise/wiki)
- 💬 [GitHub Discussions](https://github.com/caronc/apprise/discussions)
- 🐛 [Issue Tracker](https://github.com/caronc/apprise/issues)
