#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# INGRESS / LOAD BALANCER / HEALTH CHECK DEBUG COMMANDS
# Commands focus on service, endpoint, backend config, and curl tests.
# ============================================================

# 1. Get service
kubectl get svc <SERVICE_NAME> -n <NAMESPACE>

# 2. Get service YAML
kubectl get service <SERVICE_NAME> -n <NAMESPACE> -o yaml

# 3. Get all services in namespace
kubectl get svc -n <NAMESPACE>

# 4. Get ingress
kubectl get ingress -n <NAMESPACE>

# 5. Describe ingress
kubectl describe ingress <INGRESS_NAME> -n <NAMESPACE>

# 6. Get endpoints
kubectl get endpoints -n <NAMESPACE>

# 7. Get specific service endpoints
kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE> -o wide

# 8. Annotate service with backend config
kubectl annotate svc <SERVICE_NAME> -n <NAMESPACE> \
  cloud.google.com/backend-config='{"ports":{"443":"<BACKEND_CONFIG_NAME>"}}' \
  --overwrite

# 9. Check health check sidecar logs by label
kubectl logs -n <NAMESPACE> \
  -l app=<HEALTHCHECK_LABEL> \
  -c <HEALTHCHECK_CONTAINER> \
  --tail=200 | grep "GoogleHC"

# 10. Create temporary curl pod for in-cluster HTTPS testing
kubectl run test-https -n <NAMESPACE> --rm -it \
  --image=curlimages/curl \
  --restart=Never -- \
  curl -vk https://<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local:443/

# 11. Create interactive curl pod
kubectl run curl-test -n <NAMESPACE> --rm -it \
  --image=curlimages/curl \
  --restart=Never -- sh

# 12. Exec back into curl pod if needed
kubectl exec -n <NAMESPACE> -it curl-test -- sh

# 13. Curl app health endpoint with timeout
kubectl run curl-test -n <NAMESPACE> --rm -it \
  --image=curlimages/curl \
  --restart=Never -- \
  sh -c "curl -k -v --connect-timeout 5 --max-time 45 https://<DOMAIN_NAME>/healthz"

# 14. Local DNS check
nslookup <DOMAIN_NAME>

# 15. Local HTTPS check
curl -vk https://<DOMAIN_NAME>/healthz

# 16. If load balancer is failing, check these in order
kubectl get pods -n <NAMESPACE> -o wide
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o yaml
kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE> -o wide
kubectl describe ingress <INGRESS_NAME> -n <NAMESPACE>
kubectl logs deploy/<DEPLOYMENT_NAME> -n <NAMESPACE> --tail=200
