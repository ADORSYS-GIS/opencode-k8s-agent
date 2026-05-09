# 🛡️ Cluster Investigation Runbook

This document provides context for investigating the `converse` and `monitoring-tests` environments.

## 🏢 Service Map

### 1. Lightbridge Core (Namespace: `converse`)
- **API**: `lightbridge-api-main` (Deployment) - Gateway to the platform.
- **Usage**: `lightbridge-usage-main` (Deployment) - Tracks consumption.
- **MCP**: `lightbridge-mcp` (Deployment) - Model Context Protocol services.
- **OPA**: `lightbridge-opa-main` (Deployment) - Policy engine.
- **Databases**: 
  - `lightbridge-main-db` (Managed by CNPG)
  - `lightbridge-usage-db` (Managed by CNPG)

### 2. Conversational Chat (Namespace: `converse-chat`)
- **App**: `librechat` (Deployment) - Frontend/Backend interface.
- **DB**: `librechat-db` (StatefulSet/MongoDB) - Primary store.
- **Search**: `librechat-search` (StatefulSet/Meilisearch) - RAG/Search engine.

### 3. Monitoring & Gateway (Namespaces: `converse-monitoring`, `converse-gateway`)
- **Phoenix**: `phoenix` (Deployment) - Observability dashboard.
- **Collectors**: `core-gateway-phoenix-collector`, `core-gateway-usage-collector`.

## ⏰ Scheduled Tasks (CronJobs)

| Namespace | Name | Schedule | Purpose |
|-----------|------|----------|---------|
| `converse-chat` | `mongodb-backup` | `0 2 * * *` | Daily backup of LibreChat data. |
| `monitoring-tests` | `cluster-reporter` | `0 */12 * * *` | This investigation job. |

---

## 🚩 Health Thresholds & Investigation Logic

### 1. Pod Health & Logs
- **Restarts**: Any pod with `RESTARTS > 10` in the last 24h is a CRITICAL issue.
- **Status**: Investigate any pod NOT in `Running` or `Completed` state (e.g., `CrashLoopBackOff`, `ImagePullBackOff`, `Evicted`).
- **Log Monitoring (CRITICAL)**:
  - **Lightbridge Usage**: Check logs for `error`, `fail`, or `timeout` during metrics ingestion. Ensure usage data is correctly recorded.
  - **Controllers**: Monitor logs for `cnpg-cloudnative-pg` (Namespace: `cnpg-system`) and `ai-gateway-controller` (Namespace: `envoy-ai-gateway-system`) for synchronization errors or resource admission failures.

### 2. Job & CronJob Health
- **Failing Jobs**: Check `kubectl get jobs` for any where `SUCCESSFUL < 1`.
- **Lingering Jobs**: Completed jobs older than 48 hours should be flagged for cleanup.
- **Backups**: If `mongodb-backup` has no successful runs in the last 24h, mark as a HIGH severity issue.

### 3. Resource Consumption
- **Nodes**: Check for `DiskPressure` or `MemoryPressure` on Linode nodes.
- **Pods**: Use `kubectl top pods -A` to identify outliers.

### 4. Custom Resources
- **CNPG**: Check `kubectl get clusters -n converse` for any cluster where `INSTANCES != READY`.
- **Certificates**: Ensure no `Certificate` resources in `cert-system` are in `False` status.
