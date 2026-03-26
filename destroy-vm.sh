#!/bin/bash
# =============================================================================
# Destroy Neo4j VM Deployment
# =============================================================================
# Usage: ./destroy-vm.sh [PROJECT_ID] [ZONE] [INSTANCE_NAME]
# =============================================================================

set -euo pipefail

PROJECT_ID="${1:-alpfr-splunk-integration}"
ZONE="${2:-us-east4-a}"
INSTANCE_NAME="${3:-neo4j-vm}"
FIREWALL_RULE_NAME="allow-neo4j-vm"

echo "============================================="
echo "  Destroying Neo4j VM Deployment"
echo "============================================="
echo "  Instance: ${INSTANCE_NAME}"
echo "  Zone:     ${ZONE}"
echo "============================================="
echo ""

read -p "Are you sure? This will delete the VM and all data. [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo "[1/2] Deleting VM instance..."
gcloud compute instances delete "${INSTANCE_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet \
  || echo "  Instance not found or already deleted."

echo "[2/2] Deleting firewall rule..."
gcloud compute firewall-rules delete "${FIREWALL_RULE_NAME}" \
  --project="${PROJECT_ID}" \
  --quiet \
  || echo "  Firewall rule not found or already deleted."

echo ""
echo "Cleanup complete."
