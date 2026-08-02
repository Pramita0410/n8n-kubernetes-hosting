#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# KUBERNETES DEBUG COMMANDS
# Copy-paste individual commands as needed.
# ============================================================

# 1. Show all pods across all namespaces
kubectl get pods -A

# 2. Show pods in one namespace
kubectl get pods -n <NAMESPACE>

# 3. Show pods with node placement and IPs
kubectl get pods -n <NAMESPACE> -o wide

# 4. Show services
kubectl get svc -n <NAMESPACE>

# 5. Show service YAML
kubectl get service <SERVICE_NAME> -n <NAMESPACE> -o yaml

# 6. Show ingress
kubectl get ingress -n <NAMESPACE>

# 7. Describe pods by label
kubectl describe pod -l service=<SERVICE_LABEL_VALUE> -n <NAMESPACE> | sed -n '1,200p'

# 8. Describe one pod
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# 9. Get previous crash logs
kubectl logs <POD_NAME> -n <NAMESPACE> --previous

# 10. Get deployment logs
kubectl logs deploy/<DEPLOYMENT_NAME> -n <NAMESPACE> --tail=200

# 11. Get logs from a specific container in a deployment
kubectl logs deploy/<DEPLOYMENT_NAME> -c <CONTAINER_NAME> -n <NAMESPACE> --tail=200

# 12. Restart application deployment
kubectl rollout restart deploy <DEPLOYMENT_NAME> -n <NAMESPACE>

# 13. Restart worker deployment
kubectl rollout restart deploy <WORKER_DEPLOYMENT_NAME> -n <NAMESPACE>

# 14. Check rollout status
kubectl rollout status deploy/<DEPLOYMENT_NAME> -n <NAMESPACE>

# 15. Open shell inside deployment
kubectl exec -it deploy/<DEPLOYMENT_NAME> -n <NAMESPACE> -- sh

# 16. Get web pod name by label
POD=$(kubectl get pod -n <NAMESPACE> -l service=<SERVICE_LABEL_VALUE> -o jsonpath='{.items[0].metadata.name}')
echo "$POD"

# 17. Describe web pod
kubectl describe pod "$POD" -n <NAMESPACE>

# 18. Get worker pod name by label
WPOD=$(kubectl get pod -n <NAMESPACE> -l app=<WORKER_APP_LABEL_VALUE> -o jsonpath='{.items[0].metadata.name}')
echo "$WPOD"

# 19. Describe worker pod
kubectl describe pod "$WPOD" -n <NAMESPACE>

# 20. Run a temporary shell pod for debugging
kubectl run debug-shell -n <NAMESPACE> --rm -it \
  --image=curlimages/curl \
  --restart=Never -- sh

# 21. Exec back into temporary debug pod if still running
kubectl exec -n <NAMESPACE> -it debug-shell -- sh

# 22. Common quick checks
kubectl get events -n <NAMESPACE> --sort-by=.metadata.creationTimestamp
kubectl get endpoints -n <NAMESPACE>
kubectl get configmap -n <NAMESPACE>
kubectl get secret -n <NAMESPACE>
