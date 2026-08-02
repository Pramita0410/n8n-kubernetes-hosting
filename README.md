# What It Took to Run Self-Hosted n8n in a Production Cloud Environment

**From "just deploy n8n" to a production-ready platform powered by Kubernetes, Redis, PostgreSQL, TLS, and a healthy amount of humility.**

---

> *If you're reading this because someone handed you a platform and said "you own this now" — don't panic. I built this thing from zero, and I wrote this article so you wouldn't have to reverse-engineer my decisions at 2 AM.*

---

## Introduction

When our team decided to deploy the self-hosted Community Edition of n8n, the goal sounded fairly straightforward.

We wanted a centralized automation platform where teams could create workflows, integrate systems, and automate repetitive tasks — without maintaining dozens of scripts spread across different environments.

Simple enough. Or so I thought :)

What looked like an application deployment quickly turned into a platform engineering project involving Kubernetes, PostgreSQL, Redis, TLS certificates, private networking, Cloud NAT, ingress controllers, identity management, backups, and operational monitoring.

By the end of the project, I wasn't just hosting n8n.

I was building a platform.

And honestly, that's where the fun began.

---

## Who This Is For

- You're new to platform engineering and someone mentioned "GKE" in a meeting
- You've been asked to deploy n8n (or something like it) and the word "production" was used
- You inherited infrastructure and need to understand why things are the way they are
- You're curious what "self-hosted enterprise automation platform" actually means in practice

**Short answer for that last group:** It means I took a workflow tool, made it secure, scalable, and resilient enough for an enterprise to trust, and documented everything so the next person isn't lost.

---

## Table of Contents

1. [What We Were Building (and Why)](#what-we-were-building-and-why)
2. [The Architecture — From Napkin to Production](#the-architecture--from-napkin-to-production)
3. [Why Kubernetes (GKE)](#why-kubernetes-gke)
4. [Private Networking — Security First](#private-networking--security-first)
5. [Cloud NAT — Letting Private Things Talk](#cloud-nat--letting-private-things-talk)
6. [PostgreSQL — Because Data Should Survive Restarts](#postgresql--because-data-should-survive-restarts)
7. [Redis — The Quiet Hero](#redis--the-quiet-hero)
8. [TLS / HTTPS — The Real Villain](#tls--https--the-real-villain)
9. [Helm — Future You Will Be Grateful](#helm--future-you-will-be-grateful)
10. [The Container Image — Custom Builds](#the-container-image--custom-builds)
11. [Backups — Confidence Is Not a Recovery Strategy](#backups--confidence-is-not-a-recovery-strategy)
12. [Daily Operations](#daily-operations)
13. [Disaster Recovery](#disaster-recovery)
14. [Troubleshooting Playbook](#troubleshooting-playbook)
15. [Lessons Learned](#lessons-learned)
16. [Final Thoughts](#final-thoughts)

---


## What We Were Building (and Why)

The organization needed a centralized workflow automation platform. Think of it as a control center where teams could:

- Integrate APIs without writing custom scripts for each one
- Run scheduled jobs reliably
- Handle webhooks from external services
- Automate repetitive tasks across systems
- Reduce the "oh, that script lives on Dave's laptop" problem

We chose **n8n** — an open-source, self-hosted workflow automation tool. The self-hosted part was non-negotiable. The data stays in our cloud, under our control.

**The catch?** "Deploy n8n" is a sentence. "Build a platform teams can trust" is a project.

---

## The Architecture — From Napkin to Production

### What I Drew on Day One

```
Users → n8n
```

Clean. Simple. And as I quickly realized, nowhere near production-ready.

Once enterprise requirements entered the picture, the questions started stacking up:

- How do we secure access?
- How do we scale workflow execution?
- What happens if a node fails?
- Where does workflow history live?
- How do we handle TLS certificates?
- How do we back everything up?
- How do we recover after an outage?

Each question added another component to the architecture. That simple two-box diagram grew into something significantly more involved.

### What I Actually Built

<img width="591" height="861" alt="image" src="https://github.com/user-attachments/assets/678e4dba-8a38-43eb-a92b-f3297fb480fa" />


### Component Summary

| Component | Service | Purpose |
|-----------|---------|---------|
| Compute | GKE (Google Kubernetes Engine) | Runs the application containers |
| Database | Cloud SQL PostgreSQL | Stores workflows, history, credentials |
| Queue | Redis (Memorystore) | Distributes workflow execution across workers |
| Networking | Private Nodes + Cloud NAT | Keeps servers hidden, allows outbound calls |
| Ingress | GCP HTTPS Load Balancer | Routes user traffic to the app |
| TLS | Internal Managed Certificate | HTTPS encryption |
| Storage | Cloud Storage (GCS) | Backup storage |
| Images | Artifact Registry | Custom Docker images |
| Deployment | Helm | Manages Kubernetes deployments |

My original architecture had three boxes. My final architecture needed its own zoom level.

---

## Why Kubernetes (GKE)

Could I have deployed n8n on a single VM? Absolutely. Would it run? Probably. Would I want to operate it long-term?

Not really.

Here's why GKE won:

| Concern | VM Approach | GKE Approach |
|---------|------------|--------------|
| Server crashes | Manual restart, potential data loss | Auto-heals, restarts pods automatically |
| Traffic increases | Manually add servers | Horizontal scaling with one command |
| Deploying updates | SSH in, pray, restart | Rolling deployments, zero downtime |
| Resource management | Over-provision or under-provision | Right-sized, adjustable |
| Consistency | Snowflake server drift | Declarative configuration |

### Creating the Cluster

```bash
gcloud container clusters create YOUR_CLUSTER_NAME \
  --project YOUR_PROJECT_ID \
  --region YOUR_REGION \
  --enable-private-nodes \
  --enable-ip-alias \
  --enable-shielded-nodes \
  --workload-pool=YOUR_PROJECT_ID.svc.id.goog
```

**Key flags explained:**

- `--enable-private-nodes`: Nodes have no public IP (more on this below)
- `--enable-ip-alias`: Required for VPC-native networking
- `--enable-shielded-nodes`: Verifies node integrity at boot
- `--workload-pool`: Enables Workload Identity (no service account key files needed)

### Verifying Your Cluster

```bash
# Get cluster credentials
gcloud container clusters get-credentials YOUR_CLUSTER_NAME \
  --zone YOUR_ZONE \
  --project YOUR_PROJECT_ID

# Check nodes are ready
kubectl get nodes

# Check all running pods
kubectl get pods -A

# Check services and ingress
kubectl get svc -A
kubectl get ingress -A
```

> 💡 **For newcomers:** If `kubectl get nodes` shows nodes in `Ready` state, your cluster is alive. Everything else builds on top of this.

---

## Private Networking — Security First

### The Philosophy

**Users should access the application. Nobody should access the servers.**

Private nodes mean:
- No public IPs on any Kubernetes node
- Reduced attack surface
- Better compliance posture
- Harder for external threats to reach infrastructure

### The Tradeoff

Private infrastructure is *extremely* good at being private. At one point my cluster was so private it couldn't talk to the internet at all.

```
Private Cluster  ✕  Internet
```

Not ideal when your workflows need to call Microsoft APIs, webhook endpoints, and package repositories.


---

### Verifying It Works

```bash
# Exec into a pod and test outbound connectivity
kubectl exec -it deployment/YOUR_DEPLOYMENT -n YOUR_NAMESPACE -- curl https://google.com

# Test DNS resolution
kubectl exec -it deployment/YOUR_DEPLOYMENT -n YOUR_NAMESPACE -- nslookup google.com
```

If both commands succeed, your private nodes can reach the outside world. Your workflows can call external APIs.

### Troubleshooting Cloud NAT

If outbound connections fail:
1. Verify the router is in the same region as your cluster
2. Check firewall rules aren't blocking egress
3. Verify DNS resolution works (sometimes it's just DNS)

---

## PostgreSQL — Because Data Should Survive Restarts

### Why You Need an External Database

Containers are temporary. They start, they stop, they get replaced. If your data lives inside a container, it dies with the container.

n8n stores:
- Workflow definitions
- Execution history
- User accounts
- Encrypted credentials
- Application settings

All of this needs to survive pod restarts, deployments, and even cluster rebuilds.

### Cloud SQL Setup

We used **Cloud SQL for PostgreSQL** — a managed service that handles:
- Automated backups
- High availability
- Patching
- Monitoring

```bash
# Check your instance exists and is running
gcloud sql instances list

# List databases on the instance
gcloud sql databases list --instance=YOUR_DB_INSTANCE
```

### Connecting n8n to the Database

The connection details live in a Kubernetes secret:

```bash
kubectl create secret generic n8n-db-secret -n YOUR_NAMESPACE \
  --from-literal=host=YOUR_DB_HOST \
  --from-literal=port=5432 \
  --from-literal=database=YOUR_DB_NAME \
  --from-literal=user=YOUR_DB_USER \
  --from-literal=password=YOUR_DB_PASSWORD
```

### Testing Connectivity

```bash
# From inside a pod
kubectl exec -it deployment/YOUR_DEPLOYMENT -n YOUR_NAMESPACE -- nc -zv YOUR_DB_HOST 5432
```

If this returns `succeeded`, your app can talk to the database.

### Common Failures

| Symptom | Likely Cause |
|---------|-------------|
| Connection timeout | Firewall rules, VPC peering not set up |
| Authentication failed | Wrong password in secret |
| DNS resolution failed | Cloud SQL private IP not configured |
| SSL handshake error | Missing CA certificate |

> ⚡ **Key insight:** A healthy database isn't useful if your application can't reach it. Network connectivity is always step one.

---

## Redis — The Quiet Hero

### Why Redis Matters

Initially I questioned whether Redis was necessary.

**Without Redis (Regular Mode):**
```
n8n → handles everything
```

One process. All workflows. Every execution. If a long-running workflow hogs resources, everything else waits.

**With Redis (Queue Mode):**
```
n8n Web UI
     |
   Redis
     |
┌────┼────┐
W1   W2   W3  (Worker pods)
```

The web UI accepts requests. Redis queues them. Worker pods execute them independently.

### Benefits

- **Parallel execution** — multiple workflows run simultaneously
- **Worker isolation** — one bad workflow doesn't crash everything
- **Horizontal scaling** — need more capacity? Add workers
- **Better reliability** — if a worker dies, the job gets re-queued

### Key Environment Variables

```yaml
# In your deployment configuration
N8N_EXECUTIONS_MODE: queue
QUEUE_BULL_REDIS_HOST: YOUR_REDIS_HOST
QUEUE_BULL_REDIS_PORT: 6379
```

### Scaling Workers

```bash
# Scale to 3 workers
kubectl scale deployment n8n-worker --replicas=3 -n YOUR_NAMESPACE

# Check worker logs
kubectl logs deployment/n8n-worker -n YOUR_NAMESPACE --tail=50

# Verify Redis connectivity
kubectl exec -it deployment/YOUR_DEPLOYMENT -n YOUR_NAMESPACE -- nc -zv YOUR_REDIS_HOST 6379
```

Redis quietly became one of the most important pieces of the stack. The best infrastructure components are the ones nobody notices until they're gone.

Redis is gloriously boring. And that's a compliment.

---

## TLS / HTTPS — The Real Villain

Every project needs an antagonist. For this project, it was TLS.

### The Plan

1. Create an Ingress resource
2. Attach a managed certificate
3. Enable HTTPS

Simple, right?

### The Reality

```
Certificate Status: PROVISIONING
```

*One hour later:*

```
Certificate Status: PROVISIONING
```

*Three hours later:*

```
Certificate Status: PROVISIONING
```

### What I Learned

TLS issues are rarely TLS issues. They are usually:

- **DNS issues** — domain doesn't point to the load balancer IP
- **Ingress issues** — misconfigured routing rules
- **Load balancer issues** — backend not healthy
- **Timing issues** — GCP managed certs need the LB healthy first
- **Human issues** — usually me

### Ingress Configuration (Simplified)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: n8n-ingress
  namespace: YOUR_NAMESPACE
  annotations:
    networking.gke.io/managed-certificates: "YOUR_CERT_NAME"
    kubernetes.io/ingress.global-static-ip-name: "YOUR_STATIC_IP_NAME"
spec:
  rules:
  - host: YOUR_DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: n8n-service
            port:
              number: 5678
```

### Debugging TLS

```bash
# Check ingress status
kubectl get ingress -n YOUR_NAMESPACE

# Check certificate status
kubectl describe managedcertificate YOUR_CERT_NAME -n YOUR_NAMESPACE

# Check backend health
kubectl describe ingress n8n-ingress -n YOUR_NAMESPACE
```

### The Fix Checklist

If your cert is stuck in PROVISIONING:

1. ✅ DNS A record points to the Ingress external IP
2. ✅ Ingress has the managed certificate annotation
3. ✅ Backend pods are running and healthy
4. ✅ Health check endpoint is responding (usually `/healthz` or `/`)
5. ✅ Static IP is reserved and assigned
6. ⏳ Wait. Sometimes it just takes 5 minutes.

<img width="368" height="643" alt="image" src="https://github.com/user-attachments/assets/846a6fb0-aacb-4b2c-80c6-9947d621b78d" />

---

## Helm — Future You Will Be Grateful

As the project grew, so did the Kubernetes YAML. Before long I had enough YAML files to publish a short novel.

Helm packages everything into a manageable, versioned, rollback-able deployment.

### Core Commands

```bash
# Deploy
helm install n8n ./chart -n YOUR_NAMESPACE

# Upgrade (apply changes)
helm upgrade n8n ./chart -n YOUR_NAMESPACE

# Rollback (something went wrong)
helm rollback n8n REVISION_NUMBER -n YOUR_NAMESPACE

# Check history
helm history n8n -n YOUR_NAMESPACE

# Export current values (for backup)
helm get values n8n -n YOUR_NAMESPACE > helm-values-backup.yaml
```

### Why Helm Matters

- **Repeatability** — same deployment every time
- **Version control** — track what changed between releases
- **Rollbacks** — one command to undo a bad deployment
- **Templating** — one chart, multiple environments

Future me remains extremely grateful for this decision.

---

## The Container Image — Custom Builds

### Why Custom?

The official n8n Docker image is great. But enterprise needs additions:

- Custom community nodes
- Company CA certificates (for internal services)
- Python dependencies (for code nodes)
- Task runner configuration

### Repository Structure should ideally look like:

```
n8n-kubernetes-hosting/
├── build/
│   ├── Dockerfile              # Custom image definition
│   ├── requirements.txt        # Python packages for code nodes
│   ├── versions.env            # Pinned n8n version
│   ├── company-ca.crt          # Internal CA (for HTTPS to internal services)
│   ├── fullchain.crt           # Certificate chain
│   └── n8n-task-runners.json   # Task runner config
└── n8n-community/
    └── package.json            # Community node packages
```

### Build and Push

```bash
cd n8n-kubernetes-hosting/build

# Build the custom image
docker build -t YOUR_REGISTRY/n8n:YOUR_TAG .

# Push to Artifact Registry
docker push YOUR_REGISTRY/n8n:YOUR_TAG

# Update the deployment to use the new image
kubectl set image deployment/n8n n8n=YOUR_REGISTRY/n8n:YOUR_TAG -n YOUR_NAMESPACE
```

### Adding Community Nodes

1. Edit `n8n-community/package.json` — add the node package
2. Rebuild and push the image
3. Restart the deployment:

```bash
kubectl rollout restart deployment/n8n -n YOUR_NAMESPACE
```

> 💡 **Pro tip:** Pin your n8n version in `versions.env`. Uncontrolled version bumps in production are how you get surprise breaking changes on a Tuesday afternoon.

---

## Backups — Confidence Is Not a Recovery Strategy

If you don't have backups, you don't have a recovery plan. You have optimism.

### What Needs to Be Backed Up

- Workflow definitions (the automations your team builds)
- Credentials (encrypted — these power all your integrations)
- Helm values (your deployment configuration)
- Kubernetes manifests (your infrastructure definitions)

### Our Approach

We automated daily exports of workflows and credentials using n8n's built-in CLI:

```bash
# Export all workflows
n8n export:workflow --all --output=/backups/workflows.json

# Export all credentials
n8n export:credentials --all --output=/backups/credentials.json
```

These exports run on a schedule and get stored in a secure location with rolling retention.

### Exporting Kubernetes State

```bash
# Save current Helm values
helm get values n8n -n YOUR_NAMESPACE > helm-values.yaml

# Export key resources
kubectl get deployment -n YOUR_NAMESPACE -o yaml > deployment.yaml
kubectl get ingress -n YOUR_NAMESPACE -o yaml > ingress.yaml
kubectl get configmap -n YOUR_NAMESPACE -o yaml > configmap.yaml
kubectl get svc -n YOUR_NAMESPACE -o yaml > services.yaml
```

> ⚠️ **Never commit secrets to Git.** Export them separately, store securely (e.g., GCP Secret Manager), and document their names so they can be recreated.

The key principle: if your database disappears tomorrow, you should be able to rebuild the entire platform and re-import every workflow without losing a single automation.

---

## Daily Operations

### Morning Health Check (2 minutes)

```bash
# Are pods running?
kubectl get pods -n YOUR_NAMESPACE

# Any recent restarts?
kubectl get pods -n YOUR_NAMESPACE -o wide

# Is ingress healthy?
kubectl get ingress -n YOUR_NAMESPACE
```

### Viewing Logs

```bash
# Application logs
kubectl logs deployment/n8n -n YOUR_NAMESPACE --tail=100

# Worker logs (if using queue mode)
kubectl logs deployment/n8n-worker -n YOUR_NAMESPACE --tail=100
```

### Common Operational Tasks

| Task | Command |
|------|---------|
| Restart n8n | `kubectl rollout restart deployment/n8n -n YOUR_NAMESPACE` |
| Scale workers | `kubectl scale deployment n8n-worker --replicas=N -n YOUR_NAMESPACE` |
| Check a secret exists | `kubectl get secret SECRET_NAME -n YOUR_NAMESPACE` |
| Access n8n shell | `kubectl exec -it deployment/n8n -n YOUR_NAMESPACE -- sh` |

---

## Disaster Recovery

### Scenario 1: A Pod Crashes

**Action needed:** None. Kubernetes restarts it automatically.

**Data impact:** Zero. All data lives in Cloud SQL, not in the pod.

This is literally why we use Kubernetes.

### Scenario 2: Deployment Gets Deleted

```bash
kubectl apply -f k8s-manifests/deployment.yaml
kubectl apply -f k8s-manifests/service.yaml
```

Pods come back. Service routes traffic. Life continues.

### Scenario 3: The Entire Namespace Is Gone

This is the "someone ran `kubectl delete namespace` and we're all having a bad day" scenario.

**Recovery steps:**

```bash
# 1. Recreate the namespace
kubectl create namespace YOUR_NAMESPACE

# 2. Recreate secrets (values from secure storage)
kubectl create secret generic n8n-db-secret -n YOUR_NAMESPACE \
  --from-literal=host=YOUR_DB_HOST \
  --from-literal=port=5432 \
  --from-literal=database=YOUR_DB_NAME \
  --from-literal=user=YOUR_DB_USER \
  --from-literal=password=YOUR_DB_PASSWORD

# 3. Apply manifests in order
kubectl apply -f k8s-manifests/configmap.yaml
kubectl apply -f k8s-manifests/backendconfig.yaml
kubectl apply -f k8s-manifests/pvc.yaml
kubectl apply -f k8s-manifests/deployment.yaml
kubectl apply -f k8s-manifests/service.yaml
kubectl apply -f k8s-manifests/ingress.yaml
kubectl apply -f k8s-manifests/cronjob.yaml

# 4. Verify
kubectl get pods -n YOUR_NAMESPACE
kubectl get ingress -n YOUR_NAMESPACE
```

### Scenario 4: Database Lost — Restore Workflows

```bash
# Import workflows back into n8n
kubectl cp workflows.json POD_NAME:/tmp/workflows.json -n YOUR_NAMESPACE
kubectl exec -it POD_NAME -n YOUR_NAMESPACE -- n8n import:workflow --input=/tmp/workflows.json
kubectl exec -it POD_NAME -n YOUR_NAMESPACE -- n8n import:credentials --input=/tmp/credentials.json
```

<img width="765" height="229" alt="image" src="https://github.com/user-attachments/assets/0787017a-bdc5-4fe9-80c7-d7b1629b7c65" />

---

## Troubleshooting Playbook

### Quick Reference

| Symptom | First Check | Likely Fix |
|---------|------------|-----------|
| App not loading | `kubectl get pods` | Check pod logs, restart if CrashLoopBackOff |
| Workflows not executing | `kubectl logs deployment/n8n-worker` | Check Redis connectivity, worker health |
| 502 Bad Gateway | Pod health | Pod is starting, wait or check health endpoint |
| Can't connect to DB | Network from pod | Check Cloud SQL IP, firewall, secrets |
| Cert stuck PROVISIONING | DNS + Ingress | Verify DNS points to LB IP |
| Outbound calls failing | Cloud NAT | Check NAT config, firewall egress rules |

### The Debug Flow

```
1. kubectl get pods -n YOUR_NAMESPACE          → Are pods running?
2. kubectl logs deployment/n8n -n YOUR_NAMESPACE  → What's the error?
3. kubectl describe pod POD_NAME -n YOUR_NAMESPACE → Events and conditions?
4. nc -zv HOST PORT                              → Network connectivity?
5. curl https://google.com                       → Outbound internet?
```

---

## Lessons Learned

After building this from scratch, here's what stuck:

1. **Deploying the application was the easy part.** Building a platform people can trust is where engineering begins.

2. **Networking will consume more time than you expect.** Budget for it. Accept it. Make friends with `nslookup`.

3. **TLS issues are usually DNS issues.** And DNS issues are usually "I forgot to update the A record" issues.

4. **Redis Queue Mode is essential as you scale.** Start with it from day one. Retrofitting is painful.

5. **Private networking is worth the complexity.** The security posture improvement is significant.

6. **Backups should exist before you need them.** Not after. Not "I'll set that up next sprint."

7. **Helm pays for itself on the second deployment.** The first deployment feels like overhead. Every deployment after that feels like a gift.

8. **Platform engineering is everything around the application.** The app is 10% of the work. Security, networking, scaling, monitoring, backups, and reliability are the other 90%.

9. **Document everything.** The person reading your docs at 3 AM during an outage might be future you.

10. **Cloud-managed services are worth the cost.** Let Google manage your database. Let Google manage your Redis. Let Google manage your certificates. You have enough to worry about.

---

## Final Thoughts

When I started this project, I thought I was deploying n8n.

By the end, I had designed a platform.

The application itself was just the reason I opened the door. Everything behind that door — Kubernetes, networking, TLS, scaling, backups, disaster recovery — that was the real lesson.

Somewhere between my first `kubectl get pods` and my twentieth debugging session, I stopped thinking about hosting software and started thinking about **designing systems**.

And that's a much more interesting problem to solve.

---

### What You'll Need to Replicate This

| Tool | Purpose |
|------|---------|
| `gcloud` CLI | GCP resource management |
| `kubectl` | Kubernetes cluster management |
| `helm` | Application deployment |
| `docker` | Building custom images |
| A GCP project | Infrastructure home |
| Patience | Mandatory |

---

### Resources

- [n8n Documentation](https://docs.n8n.io/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Cloud NAT Documentation](https://cloud.google.com/nat/docs)
- [Helm Documentation](https://helm.sh/docs/)

---

*Thanks for reading. If this article helps you avoid even one TLS debugging session, I consider that a win.*

*And if you're the person who inherited this platform - welcome. You're going to be fine. The architecture is solid, the backups are running, and now you have the docs.*

---

> **About the Author**
> 
> Operations engineer who tries everything. Cloud infrastructure, automation, Kubernetes, and making complex systems work reliably in production.

---

**Tags:** #DevOps #GCP #Kubernetes #n8n #PlatformEngineering #CloudArchitecture #Automation

