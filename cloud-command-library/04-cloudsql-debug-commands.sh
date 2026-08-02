#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CLOUD SQL / POSTGRES DEBUG COMMANDS
# Replace placeholders before running.
# ============================================================

# 1. List Cloud SQL instances
gcloud sql instances list --project <PROJECT_ID>

# 2. List databases for an instance
gcloud sql databases list \
  --instance=<DB_INSTANCE_NAME> \
  --project <PROJECT_ID>

# 3. Create database secret for Kubernetes
# Never publish real passwords in GitHub.
kubectl create secret generic <DB_SECRET_NAME> \
  -n <NAMESPACE> \
  --from-literal=host=<DB_HOST> \
  --from-literal=port=5432 \
  --from-literal=database=<DB_NAME> \
  --from-literal=user=<DB_USER> \
  --from-literal=password=<DB_PASSWORD>

# 4. Check if secret exists
kubectl get secret <DB_SECRET_NAME> -n <NAMESPACE>

# 5. View application pod name
POD=$(kubectl get pod -n <NAMESPACE> -l service=<SERVICE_LABEL_VALUE> -o jsonpath='{.items[0].metadata.name}')
echo "$POD"

# 6. Check Cloud SQL connectivity from app container using env vars
kubectl exec -it "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c \
  'nc -vz $DB_POSTGRESDB_HOST $DB_POSTGRESDB_PORT'

# 7. Check Cloud SQL connectivity with explicit placeholder host
kubectl exec -it "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c \
  'nc -vz <DB_HOST> 5432'

# 8. Cloud SQL proxy logs
kubectl logs deploy/<DEPLOYMENT_NAME> \
  -c <CLOUDSQL_PROXY_CONTAINER> \
  -n <NAMESPACE> \
  --tail=200

# 9. App logs
kubectl logs deploy/<DEPLOYMENT_NAME> \
  -c <APP_CONTAINER> \
  -n <NAMESPACE> \
  --tail=200

# 10. Previous app crash logs
kubectl logs "$POD" \
  -c <APP_CONTAINER> \
  -n <NAMESPACE> \
  --previous

# 11. Describe pod for events and mount/env errors
kubectl describe pod "$POD" -n <NAMESPACE>

# 12. Common checks when database connection fails
kubectl get pods -n <NAMESPACE> -o wide
kubectl get svc -n <NAMESPACE>
kubectl get secret <DB_SECRET_NAME> -n <NAMESPACE>
kubectl logs deploy/<DEPLOYMENT_NAME> -c <CLOUDSQL_PROXY_CONTAINER> -n <NAMESPACE> --tail=200
kubectl logs deploy/<DEPLOYMENT_NAME> -c <APP_CONTAINER> -n <NAMESPACE> --tail=200
