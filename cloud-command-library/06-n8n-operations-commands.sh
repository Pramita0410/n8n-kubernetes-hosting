#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# N8N OPERATIONS COMMANDS
# Public-safe placeholders included.
# ============================================================

# 1. Clone n8n Kubernetes hosting repository
# Replace with your own fork if needed.
git clone <N8N_KUBERNETES_REPOSITORY_URL> -b <BRANCH_NAME>
cd <LOCAL_REPOSITORY_FOLDER>

# 2. Apply namespace
kubectl apply -f namespace.yaml

# 3. Apply all manifests
kubectl apply -f .

# 4. Get n8n service
kubectl get service <N8N_SERVICE_NAME> -n <NAMESPACE>

# 5. Get n8n service YAML
kubectl get service <N8N_SERVICE_NAME> -n <NAMESPACE> -o yaml

# 6. Get n8n pods
kubectl get pods -n <NAMESPACE> -o wide

# 7. App logs
kubectl logs deploy/<N8N_DEPLOYMENT_NAME> \
  -c <N8N_CONTAINER_NAME> \
  -n <NAMESPACE> \
  --tail=200

# 8. Cloud SQL proxy logs if used
kubectl logs deploy/<N8N_DEPLOYMENT_NAME> \
  -c <CLOUDSQL_PROXY_CONTAINER> \
  -n <NAMESPACE> \
  --tail=200

# 9. Shell inside n8n pod
kubectl exec -it deploy/<N8N_DEPLOYMENT_NAME> \
  -n <NAMESPACE> -- sh

# 10. Restart n8n web deployment
kubectl rollout restart deploy <N8N_DEPLOYMENT_NAME> -n <NAMESPACE>

# 11. Restart n8n worker deployment
kubectl rollout restart deploy <N8N_WORKER_DEPLOYMENT_NAME> -n <NAMESPACE>

# 12. Test Redis from n8n pod using environment variables
POD=$(kubectl get pod -n <NAMESPACE> -l service=<N8N_SERVICE_LABEL_VALUE> -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it "$POD" -n <NAMESPACE> -c <N8N_CONTAINER_NAME> -- sh -c \
  'nc -vz $QUEUE_BULL_REDIS_HOST $QUEUE_BULL_REDIS_PORT'

# 13. Test PostgreSQL from n8n pod using environment variables
kubectl exec -it "$POD" -n <NAMESPACE> -c <N8N_CONTAINER_NAME> -- sh -c \
  'nc -vz $DB_POSTGRESDB_HOST $DB_POSTGRESDB_PORT'

# 14. Create n8n runner auth secret
# Replace the token with your own generated value.
# Never commit the real token to GitHub.
kubectl create secret generic <N8N_RUNNERS_AUTH_SECRET_NAME> \
  -n <NAMESPACE> \
  --from-literal=token=<N8N_RUNNERS_AUTH_TOKEN>

# 15. Export workflows from inside n8n container
n8n export:workflow \
  --all \
  --output=/backups/workflows.json

# 16. Export credentials from inside n8n container
n8n export:credentials \
  --all \
  --output=/backups/credentials.json

# 17. Import workflows
n8n import:workflow \
  --input=/tmp/workflows.json

# 18. Import credentials
n8n import:credentials \
  --input=/tmp/credentials.json
