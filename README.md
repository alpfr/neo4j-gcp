# Neo4j on GKE — Design, Architecture & Deployment Guide

## Overview

This project deploys a Neo4j graph database on Google Kubernetes Engine (GKE) using Cloud Build for CI/CD automation. The deployment runs in the `neo4j-gcp` namespace with persistent storage, a LoadBalancer service for external access, and a Python client for database connectivity.

## Architecture

```
                         ┌─────────────────────────────────────────────┐
                         │              Google Cloud Platform           │
                         │                                             │
┌──────────┐             │  ┌───────────────────────────────────────┐  │
│  Client   │────────────┼──│  LoadBalancer (34.86.132.248)         │  │
│ (Browser/ │  HTTP:7474 │  │    ├── Port 7474 → Neo4j Browser     │  │
│  App)     │  Bolt:7687 │  │    └── Port 7687 → Bolt Protocol     │  │
└──────────┘             │  └──────────────┬────────────────────────┘  │
                         │                 │                           │
                         │  ┌──────────────▼────────────────────────┐  │
                         │  │  GKE Cluster (neo4j-cluster)          │  │
                         │  │  Zone: us-east4-a                     │  │
                         │  │  Nodes: 2x e2-medium                  │  │
                         │  │                                       │  │
                         │  │  ┌─────────────────────────────────┐  │  │
                         │  │  │  Namespace: neo4j-gcp            │  │  │
                         │  │  │                                  │  │  │
                         │  │  │  ┌───────────┐  ┌────────────┐  │  │  │
                         │  │  │  │ StatefulSet│  │  Service   │  │  │  │
                         │  │  │  │  neo4j-0   │  │ neo4j-http │  │  │  │
                         │  │  │  │           │  │ (LB)       │  │  │  │
                         │  │  │  └─────┬─────┘  └────────────┘  │  │  │
                         │  │  │        │                         │  │  │
                         │  │  │  ┌─────▼─────┐  ┌────────────┐  │  │  │
                         │  │  │  │    PVC     │  │  Secret    │  │  │  │
                         │  │  │  │ 10Gi SSD   │  │ neo4j-auth │  │  │  │
                         │  │  │  └───────────┘  └────────────┘  │  │  │
                         │  │  │                                  │  │  │
                         │  │  │  ┌───────────┐  ┌────────────┐  │  │  │
                         │  │  │  │ CronJob   │  │ PodMonitor │  │  │  │
                         │  │  │  │ Backup 2AM│  │ :2004/metrics│ │  │  │
                         │  │  │  └───────────┘  └────────────┘  │  │  │
                         │  │  └─────────────────────────────────┘  │  │
                         │  │                                       │  │
                         │  │  ┌─────────────────────────────────┐  │  │
                         │  │  │  cert-manager + Ingress (TLS)   │  │  │
                         │  │  │  HTTPS → neo4j.example.com      │  │  │
                         │  │  └─────────────────────────────────┘  │  │
                         │  └───────────────────────────────────────┘  │
                         │                                             │
                         │  ┌───────────────────────────────────────┐  │
                         │  │  Cloud Build (CI/CD Pipeline)         │  │
                         │  │    1. Pull neo4j:5-community          │  │
                         │  │    2. Tag & push to GCR               │  │
                         │  │    3. Create GKE cluster               │  │
                         │  │    4. Get credentials                  │  │
                         │  │    5. Install cert-manager             │  │
                         │  │    6. Create namespace                 │  │
                         │  │    7. Deploy K8s manifests             │  │
                         │  └───────────────────────────────────────┘  │
                         │                                             │
                         │  ┌───────────────────────────────────────┐  │
                         │  │  Container Registry (GCR)             │  │
                         │  │    gcr.io/PROJECT_ID/neo4j:latest     │  │
                         │  └───────────────────────────────────────┘  │
                         └─────────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| **Cloud Build** | CI/CD pipeline that pulls the Neo4j image, pushes to GCR, provisions the GKE cluster, and deploys all K8s resources |
| **GKE Cluster** | 2-node cluster (`e2-medium`) in `us-east4-a` running the Neo4j workload |
| **StatefulSet** | Manages the Neo4j pod with stable network identity and persistent storage |
| **PersistentVolumeClaim** | 10Gi disk for Neo4j data persistence across pod restarts |
| **LoadBalancer Service** | Exposes Neo4j Browser (7474) and Bolt protocol (7687) externally |
| **Secret** | Stores Neo4j authentication credentials |
| **ConfigMap** | Neo4j server configuration (memory, listen addresses) |
| **cert-manager** | Automated TLS certificate provisioning via Let's Encrypt |
| **Ingress (TLS)** | HTTPS termination for Neo4j Browser with nginx ingress |
| **PodMonitoring** | Prometheus metrics export to Google Cloud Monitoring (port 2004) |
| **CronJob (Backup)** | Daily database dump at 2:00 AM with 7-day retention |
| **Python Client** | Sample script demonstrating Bolt protocol connectivity |

## Directory Structure

```
neo4j-gke/
├── cloudbuild.yaml          # Cloud Build CI/CD pipeline
├── deploy-vm.sh             # Deploy Neo4j to Compute Engine VM
├── destroy-vm.sh            # Tear down VM deployment
├── neo4j_client.py          # Python client for Neo4j access
├── load_sample_data.py      # Load 20 sample records
├── INSTALLATION.md          # Step-by-step installation guide
├── README.md                # This file
└── k8s/
    ├── namespace.yaml       # neo4j-gcp namespace
    ├── configmap.yaml       # Neo4j server configuration
    ├── secret.yaml          # Neo4j authentication credentials
    ├── deployment.yaml      # StatefulSet with PVC
    ├── service.yaml         # LoadBalancer service
    ├── cert-manager.yaml    # Let's Encrypt ClusterIssuer + Certificate
    ├── ingress-tls.yaml     # HTTPS Ingress with TLS termination
    ├── monitoring.yaml      # PodMonitoring + metrics ConfigMap
    └── backup-cronjob.yaml  # Daily backup CronJob with 7-day retention
```

## Prerequisites

- Google Cloud SDK (`gcloud`) installed and authenticated
- `kubectl` CLI installed
- GCP project with billing enabled
- APIs enabled: Container Registry, Kubernetes Engine, Cloud Build
- Python 3.11+ with `neo4j` package (for the client script)

## Deployment

### Option 1: Automated via Cloud Build (full pipeline)

This creates the cluster, pushes the image to GCR, and deploys everything:

```bash
cd neo4j-gke
gcloud builds submit --config=cloudbuild.yaml --project=alpfr-splunk-integration .
```

### Option 2: Manual deployment to an existing cluster

```bash
# Connect to the cluster
gcloud container clusters get-credentials neo4j-cluster \
  --zone=us-east4-a \
  --project=alpfr-splunk-integration

# Create namespace first, then deploy all resources
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

# Verify deployment
kubectl get pods -n neo4j-gcp
kubectl get svc neo4j-http -n neo4j-gcp
```

### Firewall Rules

Open Neo4j ports if not already configured:

```bash
gcloud compute firewall-rules create allow-neo4j-lb \
  --allow=tcp:7474,tcp:7687 \
  --source-ranges=0.0.0.0/0 \
  --project=alpfr-splunk-integration \
  --network=default
```

## Accessing Neo4j

### Browser UI

Open `http://<EXTERNAL_IP>:7474` in your browser.

Get the external IP:

```bash
kubectl get svc neo4j-http -n neo4j-gcp
```

### Bolt Connection

Connect via the Bolt protocol for application access:

- **URI:** `bolt://<EXTERNAL_IP>:7687`
- **Username:** `neo4j`
- **Password:** (stored in `k8s/secret.yaml`)

### Python Client

```bash
pip install neo4j
python3.11 neo4j_client.py
```

The client script demonstrates:
- Connecting to Neo4j via Bolt protocol
- Creating nodes
- Querying data
- Retrieving node counts

## Configuration

### Resource Limits

Defined in `k8s/deployment.yaml`:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 250m | 500m |
| Memory | 512Mi | 1Gi |
| Storage | 10Gi (PVC) | — |

### Neo4j Settings

Configurable via `k8s/configmap.yaml`:

| Setting | Value |
|---------|-------|
| Heap initial size | 256m |
| Heap max size | 512m |
| Page cache size | 256m |
| Listen address | 0.0.0.0 |

## Sample Data

Load 20 sample records with relationships into the database:

```bash
pip install neo4j
python3.11 load_sample_data.py
```

This creates:
- **20 Person nodes** with `name`, `age`, and `role` properties
- **20 relationships** across 3 types:

| Relationship | Description |
|---|---|
| `MANAGES` | Manager → direct report hierarchy |
| `COLLABORATES_WITH` | Peer-to-peer collaboration links |
| `REPORTS_TO` | Dotted-line reporting |

### Sample Data (People)

| Name | Age | Role |
|------|-----|------|
| Bob | 25 | Engineer |
| Carol | 34 | Designer |
| Dave | 28 | Engineer |
| Eve | 41 | Manager |
| Frank | 33 | Analyst |
| Grace | 29 | Engineer |
| Hank | 45 | Director |
| Ivy | 27 | Designer |
| Jack | 38 | Manager |
| Karen | 31 | Analyst |
| Leo | 26 | Engineer |
| Mia | 36 | Manager |
| Nick | 24 | Intern |
| Olivia | 32 | Engineer |
| Paul | 40 | Architect |
| Quinn | 29 | Analyst |
| Rachel | 35 | Designer |
| Sam | 42 | Director |
| Tina | 30 | Engineer |
| Uma | 27 | Intern |

### Visualizing the Graph

Open the Neo4j browser at `http://<EXTERNAL_IP>:7474` and run:

```cypher
-- Show all nodes and relationships
MATCH (n)-[r]->(m) RETURN n, r, m

-- Show org chart (management hierarchy)
MATCH (m)-[:MANAGES]->(e) RETURN m, e

-- Show collaborations
MATCH (a)-[:COLLABORATES_WITH]->(b) RETURN a, b

-- Show a specific person and all connections
MATCH (p:Person {name: "Hank"})-[r]-(connected) RETURN p, r, connected
```

## TLS/HTTPS

TLS is handled by cert-manager with Let's Encrypt certificates and an nginx Ingress.

### Setup

1. Update `k8s/cert-manager.yaml` — replace `admin@example.com` with your email
2. Update `k8s/cert-manager.yaml` and `k8s/ingress-tls.yaml` — replace `neo4j.example.com` with your domain
3. Point your DNS A record to the Ingress external IP
4. cert-manager automatically provisions and renews the TLS certificate

### Access via HTTPS

```
https://neo4j.example.com       # Neo4j Browser
bolt+s://neo4j.example.com:7687 # Encrypted Bolt
```

## Monitoring

Neo4j exports Prometheus metrics on port 2004. Google Cloud Managed Prometheus (GMP) scrapes these via `PodMonitoring`.

### Metrics available

- Transaction counts and latency
- Page cache hit/miss ratios
- Heap and off-heap memory usage
- Bolt connection counts
- Query execution times

### View metrics

In GCP Console: **Monitoring > Metrics Explorer**, query:

```
neo4j_database_transaction_committed_total
neo4j_page_cache_hits_total
neo4j_vm_heap_used
neo4j_bolt_connections_running
```

## Backups

A CronJob runs daily at 2:00 AM to dump the Neo4j database.

### How it works

- Uses `neo4j-admin database dump` to create a consistent backup
- Stores backups on a dedicated 20Gi PVC (`neo4j-backups`)
- Automatically cleans up backups older than 7 days
- Retains the last 3 successful and 3 failed job records

### Manual backup

```bash
kubectl create job --from=cronjob/neo4j-backup manual-backup -n neo4j-gcp
```

### Check backup status

```bash
kubectl get jobs -n neo4j-gcp
kubectl logs job/manual-backup -n neo4j-gcp
```

### Restore from backup

```bash
# Scale down Neo4j
kubectl scale statefulset neo4j --replicas=0 -n neo4j-gcp

# Run restore (replace TIMESTAMP with backup folder name)
kubectl run neo4j-restore --rm -it \
  --image=neo4j:5-community \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "restore",
        "image": "neo4j:5-community",
        "command": ["neo4j-admin", "database", "load", "neo4j", "--from-path=/backups/TIMESTAMP", "--overwrite-destination"],
        "volumeMounts": [
          {"name": "data", "mountPath": "/data"},
          {"name": "backups", "mountPath": "/backups"}
        ]
      }],
      "volumes": [
        {"name": "data", "persistentVolumeClaim": {"claimName": "data-neo4j-0"}},
        {"name": "backups", "persistentVolumeClaim": {"claimName": "neo4j-backups"}}
      ]
    }
  }' -n neo4j-gcp

# Scale back up
kubectl scale statefulset neo4j --replicas=1 -n neo4j-gcp
```

## Operations

### View logs

```bash
kubectl logs neo4j-0 -n neo4j-gcp
```

### Restart Neo4j

```bash
kubectl delete pod neo4j-0 -n neo4j-gcp
```

The StatefulSet automatically recreates the pod with the same PVC.

### Scale (Enterprise only)

The Community edition supports a single instance. For clustering, use Neo4j Enterprise.

### Delete deployment

```bash
kubectl delete -f k8s/
kubectl delete pvc data-neo4j-0 -n neo4j-gcp
```

### Delete cluster

```bash
gcloud container clusters delete neo4j-cluster \
  --zone=us-east4-a \
  --project=alpfr-splunk-integration
```
