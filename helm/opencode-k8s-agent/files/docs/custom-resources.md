# 🧩 Custom Resource Investigation Guide

Use this guide to investigate specialized resources that are critical to the platform's stability.

## 1. CloudNativePG Clusters (Namespace: `converse`, `coder`, `cnpg-system`)
- **Kind**: `Cluster`
- **Focus**: These manage the PostgreSQL instances for Lightbridge and Coder.
- **Investigation**: 
  - **Status Check**: `kubectl get cluster -n converse`.
  - **Controller Logs**: If clusters are failing, check the `cnpg-cloudnative-pg` controller logs in `cnpg-system`. Look for `reconcile` errors or leader election issues.
  - **Backup Logs**: Check the `barman-cloud` logs in `cnpg-system` if backups are failing.

## 2. AI Gateway (Namespace: `envoy-ai-gateway-system`)
- **Kind**: `Deployment` (`ai-gateway-controller`)
- **Focus**: Manages model routing and traffic shaping.
- **Investigation**:
  - **Logs**: Monitor `ai-gateway-controller` logs for any rejected configurations or errors connecting to upstream providers.
  - **Ingress**: Verify that the envoy proxy is correctly receiving updates from the controller.

## 3. Lightbridge Usage Monitoring (Namespace: `converse`)
- **Kind**: `Deployment` (`lightbridge-usage-main`)
- **Focus**: The critical path for cost tracking and usage recording.
- **Investigation**:
  - **Ingestion Integrity**: Scan logs for `discarded metrics`, `buffer full`, or `failed to write to DB`. Any loss of usage data is a high-severity event.
  - **DB Connection**: Ensure the usage pod is correctly authenticated with the `lightbridge-usage-db` cluster.

## 4. External Secrets (Namespace: `external-secrets-system`)
- **Kind**: `ExternalSecret`, `SecretStore`
- **Focus**: Manages synchronization of secrets from external providers.
- **Investigation**: 
  - Check `kubectl get externalsecret -A`.
  - If status `SecretSynced` is NOT `True`, check the `external-secrets` pod logs for authentication errors with the provider.

## 5. Authorization (Namespace: `authorino-system`, `converse-gateway`)
- **Kind**: `AuthConfig`
- **Focus**: Kuadrant/Authorino policies for API security.
- **Investigation**: 
  - If API requests (Lightbridge) are returning 403/401 unexpectedly, verify the `AuthConfig` resources in `converse-gateway`.

## 6. LibreChat Context
- **Kind**: `Deployment` (librechat), `StatefulSet` (librechat-db)
- **Focus**: The application depends on MongoDB (`librechat-db`) and Meilisearch (`librechat-search`).
- **Investigation**:
  - Verify that the `librechat-search` pod has successfully initialized its index.
  - If `librechat` is crashing, check for database connection timeout logs.
