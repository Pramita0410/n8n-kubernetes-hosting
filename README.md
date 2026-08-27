# What It Took to Run Self-Hosted n8n in a Production Cloud Environment

Building a production-ready n8n platform on Google Cloud using Kubernetes, Redis, PostgreSQL, private networking, TLS, and automated recovery processes.

> If you've ever been asked to "just deploy n8n", this guide covers what it actually takes to run it securely and reliably in production.

---

## Introduction

The goal was simple: provide a centralized platform where teams could automate workflows, integrate systems, and eliminate one-off scripts running across different environments.

What started as an application deployment quickly became a platform engineering project involving:

- GKE (Google Kubernetes Engine)
- Cloud SQL PostgreSQL
- Redis Queue Mode
- Private Networking & Cloud NAT
- HTTPS/TLS
- Helm Deployments
- Backup & Disaster Recovery

By the end, I wasn't just hosting n8n. I had built a scalable, secure automation platform.

---

## Architecture

### Initial Idea

```text
Users → n8n
```

### Production Architecture

<img width="591" height="861" alt="image" src="https://github.com/user-attachments/assets/678e4dba-8a38-43eb-a92b-f3297fb480fa" />

### Infrastructure Components

| Component | Service | Purpose |
|------------|------------|------------|
| Compute | GKE | Runs application and worker pods |
| Database | Cloud SQL PostgreSQL | Stores workflows, credentials, execution history |
| Queue | Redis | Handles workflow execution |
| Networking | Private Nodes + Cloud NAT | Secure outbound connectivity |
| Load Balancer | GCP HTTPS LB | Routes external traffic |
| TLS | Managed Certificates | HTTPS encryption |
| Registry | Artifact Registry | Stores custom images |
| Storage | Cloud Storage | Backup storage |

---

## Why GKE?

While n8n can run on a single VM, Kubernetes provides:

- Self-healing workloads
- Rolling deployments
- Horizontal scaling
- Consistent infrastructure management

| Concern | VM | GKE |
|----------|----------|----------|
| Failures | Manual recovery | Automatic restarts |
| Scaling | Manual | Horizontal scaling |
| Deployments | Downtime risk | Rolling updates |
| Consistency | Configuration drift | Declarative setup |

```
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

---

## Private Networking & Cloud NAT

All Kubernetes nodes run without public IP addresses.

Benefits:

- Reduced attack surface
- Improved security posture
- Better compliance alignment

The challenge is that private nodes still need outbound internet access for:

- API integrations
- Package updates
- External webhooks

Cloud NAT solves that problem by allowing outbound traffic while keeping nodes private.

```
Private Nodes → Cloud NAT → Internet
```

---

## PostgreSQL (Cloud SQL)

Containers are temporary. Application data is not.

Cloud SQL PostgreSQL stores:

- Workflow definitions
- Credentials
- User accounts
- Execution history
- Application settings

### Connectivity Validation

```bash
kubectl exec -it deployment/n8n \
-- nc -zv DB_HOST 5432
```

---

## Redis Queue Mode

Redis became one of the most important components in the environment.

Without Redis:

```text
n8n
 └── Executes everything
```

With Redis Queue Mode:

```text
n8n UI
   │
 Redis
   │
 ┌───┬───┬───┐
 W1  W2  W3
```

Benefits:

- Parallel execution
- Worker isolation
- Improved reliability
- Independent scaling

---

## TLS & HTTPS

One of the most time-consuming parts of the deployment was certificate provisioning.

Most certificate problems turned out to be:

- DNS issues
- Ingress issues
- Backend health issues

Not TLS itself.

### Certificate Troubleshooting

<img width="591" height="861" alt="image" src="https://github.com/user-attachments/assets/846a6fb0-aacb-4b2c-80c6-9947d621b78d" />



```bash
kubectl get ingress
kubectl describe managedcertificate CERT_NAME
```

### Quick Checklist

- DNS points to Load Balancer IP
- Managed certificate attached
- Pods healthy
- Static IP assigned
- Backend health checks passing

---

## Helm Deployments

Helm simplified deployment management significantly.

```bash
helm install n8n ./chart

helm upgrade n8n ./chart

helm rollback n8n REVISION
```

Benefits:

- Version control
- Rollbacks
- Consistent deployments
- Environment templating

---

## Custom Container Images

The standard n8n image was extended to support:

- Community Nodes
- Internal CA Certificates
- Python Dependencies
- Task Runner Configuration

```bash
docker build -t REGISTRY/n8n:TAG .
docker push REGISTRY/n8n:TAG
```

---

## Backup Strategy

Workflows and credentials are exported regularly and stored securely.

```bash
n8n export:workflow --all

n8n export:credentials --all
```

Additional backups include:

- Helm values
- Kubernetes manifests
- Database backups

The goal is simple:

> Rebuild the platform and restore workflows with minimal downtime.

---

## Operations

Daily checks take only a few minutes.

```bash
kubectl get pods

kubectl get ingress

kubectl logs deployment/n8n
```

Common operational tasks include:

- Scaling workers
- Reviewing logs
- Deploying updates
- Validating backups

---

## Disaster Recovery

### Recovery Overview

<img width="765" height="229" alt="image" src="https://github.com/user-attachments/assets/0787017a-bdc5-4fe9-80c7-d7b1629b7c65" />



### Scenarios Covered

- Pod failure
- Deployment deletion
- Namespace recovery
- Database restoration

Because workflows, credentials, and infrastructure definitions are backed up separately, the environment can be rebuilt without recreating workflows manually.

---

## Lessons Learned

- Deploying n8n is easy; operating it in production is not.
- Networking takes longer than expected.
- DNS causes more TLS issues than TLS itself.
- Redis Queue Mode is worth implementing early.
- Managed cloud services reduce operational overhead.
- Backups are only useful if they can be restored.
- Documentation becomes critical during incidents.
- Platform engineering extends far beyond the application layer.

---

## Technology Stack

- n8n
- Google Kubernetes Engine (GKE)
- Cloud SQL PostgreSQL
- Redis (Memorystore)
- Cloud NAT
- Helm
- Docker
- Artifact Registry
- Cloud Storage
- GCP Load Balancer

---

## Final Thoughts

This project started as an n8n deployment and evolved into a complete platform engineering exercise covering infrastructure, networking, security, scalability, monitoring, and recovery.

The application was only one piece of the solution. Building a reliable platform around it was the real challenge.
