# Neo4j on GKE — Step-by-Step Installation Guide

## Step 1: Prerequisites

### 1.1 Install required CLI tools

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Install kubectl
gcloud components install kubectl

# Install Python neo4j driver
pip install neo4j
```

### 1.2 Enable required GCP APIs

```bash
gcloud services enable container.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  --project=alpfr-splunk-integration
```

### 1.3 Authenticate with GCP

```bash
gcloud auth login
gcloud config set project alpfr-splunk-integration
```

---

## Step 2: Clone the Repository

```bash
git clone https://github.com/alpfr/neo4j-gcp.git
cd neo4j-gcp
```

---

## Step 3: Configure Settings

### 3.1 Update project ID

Replace `PROJECT_ID` in `k8s/deployment.yaml` if using GCR image:

```bash
# If using GCR image instead of Docker Hub directly
sed -i '' 's/PROJECT_ID/alpfr-splunk-integration/g' k8s/deployment.yaml
```

### 3.2 Update Neo4j password

Edit `k8s/secret.yaml`:

```yaml
stringData:
  auth: "neo4j/YOUR_SECURE_PASSWORD"
```

### 3.3 (Optional) Configure TLS domain

Edit `k8s/cert-manager.yaml`:
- Replace `admin@example.com` with your email
- Replace `neo4j.example.com` with your domain

Edit `k8s/ingress-tls.yaml`:
- Replace `neo4j.example.com` with your domain

---

## Step 4: Deploy

### Option A: Automated deployment via Cloud Build

This is the recommended approach. It handles everything in one command:

```bash
gcloud builds submit --config=cloudbuild.yaml --project=alpfr-splunk-integration .
```

**What this does:**
1. Pulls `neo4j:5-community` from Docker Hub
2. Tags and pushes to Google Container Registry
3. Creates a 2-node GKE cluster (`neo4j-cluster`) in `us-east4-a`
4. Installs cert-manager for TLS
5. Creates the `neo4j-gcp` namespace
6. Deploys all Kubernetes resources

**Expected duration:** ~10-15 minutes

### Option B: Manual step-by-step deployment

#### 4B.1 Create the GKE cluster

```bash
gcloud container clusters create neo4j-cluster \
  --zone=us-east4-a \
  --num-nodes=2 \
  --machine-type=e2-medium \
  --disk-size=50GB \
  --project=alpfr-splunk-integration
```

#### 4B.2 Get cluster credentials

```bash
gcloud container clusters get-credentials neo4j-cluster \
  --zone=us-east4-a \
  --project=alpfr-splunk-integration
```

#### 4B.3 Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=Available deployment/cert-manager-webhook \
  -n cert-manager --timeout=120s
```

#### 4B.4 Create namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

#### 4B.5 Deploy all resources

```bash
kubectl apply -f k8s/
```

---

## Step 5: Open Firewall Ports

```bash
gcloud compute firewall-rules create allow-neo4j-lb \
  --allow=tcp:7474,tcp:7687 \
  --source-ranges=0.0.0.0/0 \
  --project=alpfr-splunk-integration \
  --network=default
```

> **Security note:** For production, replace `0.0.0.0/0` with your IP range (e.g., `203.0.113.0/24`).

---

## Step 6: Verify Deployment

### 6.1 Check pod status

```bash
kubectl get pods -n neo4j-gcp
```

Expected output:
```
NAME      READY   STATUS    RESTARTS   AGE
neo4j-0   1/1     Running   0          2m
```

### 6.2 Get the external IP

```bash
kubectl get svc neo4j-http -n neo4j-gcp
```

Expected output:
```
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                         AGE
neo4j-http   LoadBalancer   34.118.229.128   34.86.132.248   7474:31798/TCP,7687:30411/TCP   5m
```

> **Note:** The `EXTERNAL-IP` may show `<pending>` for 1-2 minutes while the load balancer provisions.

### 6.3 Check pod logs

```bash
kubectl logs neo4j-0 -n neo4j-gcp
```

Look for: `Started.` or `Remote interface available at http://0.0.0.0:7474/`

---

## Step 7: Access Neo4j Browser

Open your browser and navigate to:

```
http://<EXTERNAL_IP>:7474
```

Login credentials:
- **Username:** `neo4j`
- **Password:** the password set in `k8s/secret.yaml`

---

## Step 8: Connect via Bolt Protocol

### 8.1 Update the Python client

Edit `neo4j_client.py` — replace the IP with your external IP:

```python
URI = "bolt://<EXTERNAL_IP>:7687"
AUTH = ("neo4j", "YOUR_PASSWORD")
```

### 8.2 Run the client

```bash
python3.11 neo4j_client.py
```

Expected output:
```
Connected to Neo4j successfully.
Created node: Alice
  Name: Alice, Age: 30
Total nodes in database: 1
Connection closed.
```

---

## Step 9: Load Sample Data

```bash
python3.11 load_sample_data.py
```

Expected output:
```
Connected to Neo4j.
  Created: Bob (Engineer, age 25)
  Created: Carol (Designer, age 34)
  ...
  Relationship: Eve -[MANAGES]-> Bob
  Relationship: Eve -[MANAGES]-> Carol
  ...
Total Person nodes: 21
Total relationships: 20
Done.
```

### Visualize the graph

In the Neo4j browser, run:

```cypher
MATCH (n)-[r]->(m) RETURN n, r, m
```

---

## Step 10: (Optional) Enable TLS/HTTPS

### 10.1 Install nginx ingress controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
```

### 10.2 Get the Ingress external IP

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### 10.3 Configure DNS

Point your domain's A record to the Ingress external IP:

```
neo4j.example.com → <INGRESS_EXTERNAL_IP>
```

### 10.4 Apply TLS resources

```bash
kubectl apply -f k8s/cert-manager.yaml
kubectl apply -f k8s/ingress-tls.yaml
```

### 10.5 Verify certificate

```bash
kubectl get certificate neo4j-tls -n neo4j-gcp
```

Expected: `READY = True` (may take 1-2 minutes)

### 10.6 Access via HTTPS

```
https://neo4j.example.com          # Neo4j Browser
bolt+s://neo4j.example.com:7687    # Encrypted Bolt
```

---

## Step 11: (Optional) Verify Monitoring

### 11.1 Check PodMonitoring

```bash
kubectl get podmonitoring -n neo4j-gcp
```

### 11.2 View metrics in GCP Console

1. Go to **GCP Console > Monitoring > Metrics Explorer**
2. Query any of these metrics:

```
neo4j_database_transaction_committed_total
neo4j_page_cache_hits_total
neo4j_vm_heap_used
neo4j_bolt_connections_running
```

---

## Step 12: (Optional) Verify Backups

### 12.1 Check CronJob

```bash
kubectl get cronjob -n neo4j-gcp
```

Expected output:
```
NAME           SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
neo4j-backup   0 2 * * *   False     0        <none>          5m
```

### 12.2 Trigger a manual backup

```bash
kubectl create job --from=cronjob/neo4j-backup manual-backup -n neo4j-gcp
```

### 12.3 Check backup status

```bash
kubectl get jobs -n neo4j-gcp
kubectl logs job/manual-backup -n neo4j-gcp
```

---

## Troubleshooting

### Pod stuck in Pending

```bash
kubectl describe pod neo4j-0 -n neo4j-gcp
```

Common causes:
- **Insufficient cpu/memory:** Reduce resource requests in `k8s/deployment.yaml`
- **PVC not binding:** Check `kubectl get pvc -n neo4j-gcp`

### Pod in CrashLoopBackOff

```bash
kubectl logs neo4j-0 -n neo4j-gcp --previous
```

Common causes:
- **Unrecognized config setting:** Add `NEO4J_server_config_strict__validation_enabled=false` to env
- **OOMKilled:** Increase memory limit in `k8s/deployment.yaml`
- **Corrupt data:** Delete the PVC and recreate: `kubectl delete pvc data-neo4j-0 -n neo4j-gcp`

### Cannot connect to Neo4j Browser

1. Verify pod is running: `kubectl get pods -n neo4j-gcp`
2. Verify service has external IP: `kubectl get svc neo4j-http -n neo4j-gcp`
3. Check firewall rules: `gcloud compute firewall-rules list --project=alpfr-splunk-integration`

### LoadBalancer EXTERNAL-IP stuck on pending

```bash
kubectl describe svc neo4j-http -n neo4j-gcp
```

This usually resolves in 1-2 minutes. If it persists, check GCP quotas for external IPs.

---

## Cleanup

### Remove Neo4j deployment only

```bash
kubectl delete -f k8s/
kubectl delete pvc data-neo4j-0 -n neo4j-gcp
kubectl delete pvc neo4j-backups -n neo4j-gcp
kubectl delete namespace neo4j-gcp
```

### Delete the entire GKE cluster

```bash
gcloud container clusters delete neo4j-cluster \
  --zone=us-east4-a \
  --project=alpfr-splunk-integration
```

### Delete firewall rules

```bash
gcloud compute firewall-rules delete allow-neo4j-lb \
  --project=alpfr-splunk-integration
```
