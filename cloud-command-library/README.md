# Cloud Command Library

Copy-paste friendly command snippets for GKE, Kubernetes, Redis, Cloud SQL, Ingress, and n8n operations.

> **Public GitHub note:** All real project values have been replaced with placeholders like `<PROJECT_ID>`, `<CLUSTER_NAME>`, `<NAMESPACE>`, `<DB_HOST>`, `<DOMAIN_NAME>`, and `<SECRET_VALUE>`.
>
> Do not commit real service account keys, tokens, domains, internal IPs, project IDs, or passwords.

## Folder Contents

```text
cloud-command-library/
├── README.md
├── 00-placeholders.env
├── 01-gke-cluster-setup.sh
├── 02-kubernetes-debug-commands.sh
├── 03-redis-helm-commands.sh
├── 04-cloudsql-debug-commands.sh
├── 05-ingress-loadbalancer-debug.sh
├── 06-n8n-operations-commands.sh
└── 07-emergency-recovery-commands.sh
```

## How to Use

1. Open `00-placeholders.env`.
2. Replace placeholder values with your own environment values.
3. Copy commands from each `.sh` file as needed.
4. Do **not** run the full file blindly against production.
5. Review every command before executing.

## Placeholder Examples

```bash
<PROJECT_ID>
<CLUSTER_NAME>
<REGION>
<ZONE>
<NAMESPACE>
<DEPLOYMENT_NAME>
<WORKER_DEPLOYMENT_NAME>
<DB_HOST>
<DB_PORT>
<REDIS_HOST>
<DOMAIN_NAME>
<SERVICE_NAME>
<INGRESS_NAME>
<BACKEND_CONFIG_NAME>
<SECRET_NAME>
<SECRET_VALUE>
```
