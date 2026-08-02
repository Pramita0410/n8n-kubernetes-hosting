#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# REDIS HELM COMMANDS
# Based on Redis install, verify, upgrade, and emergency checks.
# ============================================================

# 1. Add Bitnami Helm repo
helm repo add bitnami https://charts.bitnami.com/bitnami

# 2. Update Helm repos
helm repo update

# 3. Install Redis without auth for internal cluster testing
# Review security requirements before using this pattern.
helm install redis bitnami/redis \
  -n <NAMESPACE> \
  --set auth.enabled=false \
  --set architecture=standalone

# 4. Install Redis with persistence and resource controls
helm install redis bitnami/redis \
  -n <NAMESPACE> \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.persistence.enabled=true \
  --set master.persistence.size=1Gi \
  --set master.resources.requests.cpu=100m \
  --set master.resources.requests.memory=256Mi \
  --set master.resources.limits.cpu=500m \
  --set master.resources.limits.memory=512Mi

# 5. Upgrade Redis using a values file
helm upgrade redis bitnami/redis \
  -n <NAMESPACE> \
  -f <REDIS_VALUES_FILE>

# 6. Upgrade or install Redis using a pinned chart version
helm upgrade --install redis bitnami/redis \
  -n <NAMESPACE> \
  --version <CHART_VERSION> \
  -f <REDIS_VALUES_FILE>

# 7. Verify Redis pods
kubectl get pods -n <NAMESPACE> \
  -l app.kubernetes.io/name=redis

# 8. Verify Redis service
kubectl get svc -n <NAMESPACE> \
  -l app.kubernetes.io/name=redis

# 9. Verify Redis endpoints
kubectl get endpoints redis-master -n <NAMESPACE> -o wide

# 10. Test Redis with temporary Redis CLI pod
kubectl run rcli -n <NAMESPACE> --rm -it \
  --image=redis:7.2-alpine \
  --restart=Never -- \
  sh -lc 'redis-cli -h redis-master -p 6379 ping'

# Expected output:
# PONG

# 11. Test Redis from the application pod
POD=$(kubectl get pod -n <NAMESPACE> -l service=<SERVICE_LABEL_VALUE> -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c \
  'nc -vz $QUEUE_BULL_REDIS_HOST $QUEUE_BULL_REDIS_PORT'

# 12. Direct Redis PING from redis-master-0
kubectl exec -n <NAMESPACE> redis-master-0 -- redis-cli PING

# 13. Redis failure checks
kubectl get pods -n <NAMESPACE> -l app.kubernetes.io/name=redis
kubectl get svc -n <NAMESPACE> -l app.kubernetes.io/name=redis
kubectl get endpoints redis-master -n <NAMESPACE> -o wide
kubectl describe pod redis-master-0 -n <NAMESPACE>
kubectl logs redis-master-0 -n <NAMESPACE> --tail=200
