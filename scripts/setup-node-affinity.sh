#!/bin/bash

# Setup Node Affinity for Zapper ArgoCD
# This script labels and taints nodes for workload distribution

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         SETUP NODE AFFINITY - ZAPPER ARGOCD              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if nodes exist
echo -e "${YELLOW}Checking available nodes...${NC}"
NODES=$(kubectl get nodes --no-headers | awk '{print $1}')
NODE_COUNT=$(echo "$NODES" | wc -l | tr -d ' ')

echo -e "${GREEN}Found $NODE_COUNT nodes:${NC}"
echo "$NODES"
echo ""

if [ "$NODE_COUNT" -lt 5 ]; then
  echo -e "${YELLOW}⚠️  WARNING: Less than 5 worker nodes found.${NC}"
  echo -e "${YELLOW}   Recommended: 5 workers (2 postgres, 1 clickhouse, 2 peerdb)${NC}"
  echo ""
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Label nodes
echo -e "${YELLOW}Step 1: Labeling nodes...${NC}"

# PostgreSQL workers
echo -e "  Labeling worker-1 and worker-2 for ${GREEN}PostgreSQL${NC}"
kubectl label node worker-1 workload=postgres --overwrite 2>/dev/null || echo "    worker-1 not found, skipping..."
kubectl label node worker-2 workload=postgres --overwrite 2>/dev/null || echo "    worker-2 not found, skipping..."

# ClickHouse worker
echo -e "  Labeling worker-3 for ${GREEN}ClickHouse${NC}"
kubectl label node worker-3 workload=clickhouse --overwrite 2>/dev/null || echo "    worker-3 not found, skipping..."

# PeerDB workers
echo -e "  Labeling worker-4 and worker-5 for ${GREEN}PeerDB${NC}"
kubectl label node worker-4 workload=peerdb --overwrite 2>/dev/null || echo "    worker-4 not found, skipping..."
kubectl label node worker-5 workload=peerdb --overwrite 2>/dev/null || echo "    worker-5 not found, skipping..."

echo -e "${GREEN}✅ Nodes labeled successfully!${NC}"
echo ""

# Taint nodes (optional)
echo -e "${YELLOW}Step 2: Do you want to taint nodes (dedicate them exclusively)?${NC}"
read -p "This will prevent other pods from running on these nodes (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "  Tainting nodes..."

  kubectl taint node worker-1 workload=postgres:NoSchedule --overwrite 2>/dev/null || echo "    worker-1 not found"
  kubectl taint node worker-2 workload=postgres:NoSchedule --overwrite 2>/dev/null || echo "    worker-2 not found"
  kubectl taint node worker-3 workload=clickhouse:NoSchedule --overwrite 2>/dev/null || echo "    worker-3 not found"
  kubectl taint node worker-4 workload=peerdb:NoSchedule --overwrite 2>/dev/null || echo "    worker-4 not found"
  kubectl taint node worker-5 workload=peerdb:NoSchedule --overwrite 2>/dev/null || echo "    worker-5 not found"

  echo -e "${GREEN}✅ Nodes tainted successfully!${NC}"
else
  echo -e "${YELLOW}⚠️  Skipping taints (nodes will not be dedicated)${NC}"
fi
echo ""

# Verify
echo -e "${YELLOW}Step 3: Verifying node labels...${NC}"
kubectl get nodes --show-labels | grep workload || echo "No labels found!"
echo ""

# Reschedule pods
echo -e "${YELLOW}Step 4: Do you want to reschedule existing pods?${NC}"
read -p "This will restart pods to match node affinity (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "  Rescheduling PostgreSQL..."
  kubectl rollout restart statefulset -n cloudnative-pg postgres-cluster 2>/dev/null || echo "    PostgreSQL not found"

  echo -e "  Rescheduling ClickHouse..."
  kubectl rollout restart statefulset -n clickhouse 2>/dev/null || echo "    ClickHouse not found"

  echo -e "  Rescheduling PeerDB..."
  kubectl rollout restart deployment -n peerdb peerdb 2>/dev/null || echo "    PeerDB not found"
  kubectl rollout restart deployment -n peerdb peerdb-flow-worker 2>/dev/null || echo "    PeerDB flow-worker not found"

  echo -e "${GREEN}✅ Pods rescheduling initiated!${NC}"
  echo -e "${YELLOW}   Monitor with: kubectl get pods -o wide --all-namespaces${NC}"
else
  echo -e "${YELLOW}⚠️  Skipping pod reschedule${NC}"
fi
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    SETUP COMPLETE!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Verify pod distribution: kubectl get pods -o wide --all-namespaces | grep -E 'postgres|clickhouse|peerdb'"
echo "2. Check node labels: kubectl get nodes --show-labels | grep workload"
echo "3. Monitor pod startup: kubectl get pods --all-namespaces -w"
