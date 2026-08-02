#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# EMERGENCY RECOVERY COMMANDS
# Copy-paste individual blocks only after reviewing.
# ============================================================

# 1. Check cluster wide status
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A

# 2. Check namespace resources
kubectl get pods -n <NAMESPACE> -o wide
kubectl get svc -n <NAMESPACE>
kubectl get endpoints -n <NAMESPACE>
kubectl get ingress -n <NAMESPACE>
kubectl get events -n <NAMESPACE> --sort-by=.metadata.creationTimestamp

# 3. Restart app and worker deployments
kubectl rollout restart deploy <DEPLOYMENT_NAME> -n <NAMESPACE>
kubectl rollout restart deploy <WORKER_DEPLOYMENT_NAME> -n <NAMESPACE>

# 4. Verify rollout
kubectl rollout status deploy/<DEPLOYMENT_NAME> -n <NAMESPACE>
kubectl rollout status deploy/<WORKER_DEPLOYMENT_NAME> -n <NAMESPACE>

# 5. Pull latest logs
kubectl logs deploy/<DEPLOYMENT_NAME> -n <NAMESPACE> --tail=200
kubectl logs deploy/<WORKER_DEPLOYMENT_NAME> -n <NAMESPACE> --tail=200

# 6. Pull previous crash logs from current app pod
POD=$(kubectl get pod -n <NAMESPACE> -l service=<SERVICE_LABEL_VALUE> -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n <NAMESPACE> --previous

# 7. Describe application pod
kubectl describe pod "$POD" -n <NAMESPACE>

# 8. Verify Redis
kubectl get pods -n <NAMESPACE> -l app.kubernetes.io/name=redis
kubectl get endpoints redis-master -n <NAMESPACE> -o wide
kubectl exec -n <NAMESPACE> redis-master-0 -- redis-cli PING

# 9. Verify Cloud SQL connectivity from app pod
kubectl exec -it "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c \
  'nc -vz $DB_POSTGRESDB_HOST $DB_POSTGRESDB_PORT'

# 10. Verify Redis connectivity from app pod
kubectl exec -it "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c \
  'nc -vz $QUEUE_BULL_REDIS_HOST $QUEUE_BULL_REDIS_PORT'

# 11. Create temporary curl pod and test public health endpoint
kubectl run curl-test -n <NAMESPACE> --rm -it \
  --image=curlimages/curl \
  --restart=Never -- \
  sh -c "curl -k -v --connect-timeout 5 --max-time 45 https://<DOMAIN_NAME>/healthz"

# 12. Recreate namespace if deleted
kubectl create namespace <NAMESPACE> --dry-run=client -o yaml | kubectl apply -f -

# 13. Recreate database secret
kubectl create secret generic <DB_SECRET_NAME> \
  -n <NAMESPACE> \
  --from-literal=host=<DB_HOST> \
  --from-literal=port=5432 \
  --from-literal=database=<DB_NAME> \
  --from-literal=user=<DB_USER> \
  --from-literal=password=<DB_PASSWORD>

# 14. Reapply manifests in safe order
kubectl apply -f configmap.yaml
kubectl apply -f backendconfig.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f cronjob.yaml

# 15. Final verification
kubectl get pods -n <NAMESPACE> -o wide
kubectl get svc -n <NAMESPACE>
kubectl get ingress -n <NAMESPACE>
