#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# GKE CLUSTER SETUP COMMANDS
# Replace placeholders before running.
# ============================================================

# 1. Authenticate to Google Cloud
gcloud auth login

# 2. Check active account
gcloud auth list

# 3. Set active project
gcloud config set project <PROJECT_ID>

# 4. Confirm project configuration
gcloud config list

# 5. Optional: activate service account
# Never commit real key files to GitHub.
gcloud auth activate-service-account <SERVICE_ACCOUNT_EMAIL> \
  --key-file=<SERVICE_ACCOUNT_KEY_FILE>

# 6. Create an autopilot cluster example
# Use this only when Autopilot fits your workload.
gcloud container clusters create-auto <CLUSTER_NAME> \
  --location <REGION> \
  --project <PROJECT_ID>

# 7. Create a standard private GKE cluster example
# This command mirrors a production-style private cluster setup.
gcloud container clusters create <CLUSTER_NAME> \
  --project=<PROJECT_ID> \
  --region=<REGION> \
  --release-channel=regular \
  --network=<VPC_NETWORK_NAME> \
  --subnetwork=<SUBNET_NAME> \
  --cluster-secondary-range-name=<PODS_SECONDARY_RANGE_NAME> \
  --services-secondary-range-name=<SERVICES_SECONDARY_RANGE_NAME> \
  --machine-type=e2-medium \
  --num-nodes=1 \
  --image-type=COS_CONTAINERD \
  --disk-type=pd-balanced \
  --disk-size=100 \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=3 \
  --enable-private-nodes \
  --max-surge-upgrade=1 \
  --max-unavailable-upgrade=0

# 8. Connect kubectl to the cluster
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region <REGION> \
  --project <PROJECT_ID>

# 9. Verify cluster access
kubectl config current-context
kubectl get nodes
kubectl get pods -A

# 10. If control plane uses authorized networks, allow your current IP
export CLUSTER=<CLUSTER_NAME>
export REGION=<REGION>
export PROJECT=<PROJECT_ID>
export MY_IP=$(curl -s ifconfig.me)

gcloud container clusters update "$CLUSTER" \
  --region "$REGION" \
  --project "$PROJECT" \
  --enable-master-authorized-networks \
  --master-authorized-networks="${MY_IP}/32"

# 11. Create namespace
kubectl create namespace <NAMESPACE> --dry-run=client -o yaml | kubectl apply -f -

# 12. Apply Kubernetes manifests from current directory
kubectl apply -f namespace.yaml
kubectl apply -f .

# 13. Verify application resources
kubectl get pods -n <NAMESPACE> -o wide
kubectl get svc -n <NAMESPACE>
kubectl get ingress -n <NAMESPACE>
