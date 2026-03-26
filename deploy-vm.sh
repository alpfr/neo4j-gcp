#!/bin/bash
# =============================================================================
# Neo4j Deployment to GCP Compute Engine VM
# =============================================================================
# Usage: ./deploy-vm.sh [PROJECT_ID] [ZONE] [INSTANCE_NAME]
#
# Defaults:
#   PROJECT_ID:    alpfr-splunk-integration
#   ZONE:          us-east4-a
#   INSTANCE_NAME: neo4j-vm
# =============================================================================

set -euo pipefail

# Configuration
PROJECT_ID="${1:-alpfr-splunk-integration}"
ZONE="${2:-us-east4-a}"
INSTANCE_NAME="${3:-neo4j-vm}"
MACHINE_TYPE="e2-medium"
BOOT_DISK_SIZE="50GB"
NEO4J_IMAGE="neo4j:5-community"
NEO4J_HTTP_PORT=7474
NEO4J_BOLT_PORT=7687
FIREWALL_RULE_NAME="allow-neo4j-vm"

echo "============================================="
echo "  Neo4j VM Deployment"
echo "============================================="
echo "  Project:  ${PROJECT_ID}"
echo "  Zone:     ${ZONE}"
echo "  Instance: ${INSTANCE_NAME}"
echo "  Machine:  ${MACHINE_TYPE}"
echo "============================================="
echo ""

# -----------------------------------------------------------------------------
# Step 1: Set project
# -----------------------------------------------------------------------------
echo "[Step 1/6] Setting GCP project..."
gcloud config set project "${PROJECT_ID}"

# -----------------------------------------------------------------------------
# Step 2: Create VM with container
# -----------------------------------------------------------------------------
echo "[Step 2/6] Creating Compute Engine VM with Neo4j container..."
gcloud compute instances create-with-container "${INSTANCE_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --boot-disk-size="${BOOT_DISK_SIZE}" \
  --container-image="${NEO4J_IMAGE}" \
  --container-env="NEO4J_AUTH=neo4j/PassW0rdOne,NEO4J_server_config_strict__validation_enabled=false,NEO4J_server_default__listen__address=0.0.0.0" \
  --container-mount-disk="mount-path=/data,name=neo4j-data" \
  --tags=neo4j-vm \
  --metadata=google-logging-enabled=true \
  || echo "  VM may already exist. Continuing..."

# -----------------------------------------------------------------------------
# Step 3: Create firewall rules
# -----------------------------------------------------------------------------
echo "[Step 3/6] Creating firewall rules for Neo4j ports..."
gcloud compute firewall-rules create "${FIREWALL_RULE_NAME}" \
  --project="${PROJECT_ID}" \
  --allow=tcp:${NEO4J_HTTP_PORT},tcp:${NEO4J_BOLT_PORT} \
  --source-ranges=0.0.0.0/0 \
  --target-tags=neo4j-vm \
  --description="Allow Neo4j Browser and Bolt protocol" \
  || echo "  Firewall rule may already exist. Continuing..."

# -----------------------------------------------------------------------------
# Step 4: Wait for VM to be ready
# -----------------------------------------------------------------------------
echo "[Step 4/6] Waiting for VM to be ready..."
sleep 10

# Get the external IP
EXTERNAL_IP=$(gcloud compute instances describe "${INSTANCE_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "  External IP: ${EXTERNAL_IP}"

# -----------------------------------------------------------------------------
# Step 5: Wait for Neo4j to start
# -----------------------------------------------------------------------------
echo "[Step 5/6] Waiting for Neo4j to start (this may take 30-60 seconds)..."
MAX_RETRIES=12
RETRY_COUNT=0
while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
  if curl -s -o /dev/null -w "%{http_code}" "http://${EXTERNAL_IP}:${NEO4J_HTTP_PORT}" 2>/dev/null | grep -q "200"; then
    echo "  Neo4j is ready!"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "  Waiting... (attempt ${RETRY_COUNT}/${MAX_RETRIES})"
  sleep 10
done

if [ ${RETRY_COUNT} -eq ${MAX_RETRIES} ]; then
  echo "  WARNING: Neo4j may still be starting. Check manually."
fi

# -----------------------------------------------------------------------------
# Step 6: Print connection details
# -----------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  Neo4j Deployment Complete"
echo "============================================="
echo ""
echo "  Neo4j Browser:  http://${EXTERNAL_IP}:${NEO4J_HTTP_PORT}"
echo "  Bolt URI:        bolt://${EXTERNAL_IP}:${NEO4J_BOLT_PORT}"
echo ""
echo "  Username:        neo4j"
echo "  Password:        PassW0rdOne"
echo ""
echo "  VM Instance:     ${INSTANCE_NAME}"
echo "  Zone:            ${ZONE}"
echo ""
echo "  SSH into VM:"
echo "    gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID}"
echo ""
echo "  View container logs:"
echo "    gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID} -- 'sudo docker logs \$(sudo docker ps -q)'"
echo ""
echo "============================================="
