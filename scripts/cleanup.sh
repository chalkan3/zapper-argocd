#!/bin/bash

# Cleanup script for Zapper ArgoCD
# Removes all deployed resources

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║            CLEANUP - ZAPPER ARGOCD GITOPS                 ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will DELETE all deployed resources!${NC}"
echo -e "${YELLOW}   - All ArgoCD Applications${NC}"
echo -e "${YELLOW}   - PostgreSQL databases and data${NC}"
echo -e "${YELLOW}   - ClickHouse clusters and data${NC}"
echo -e "${YELLOW}   - PeerDB mirrors and metadata${NC}"
echo -e "${YELLOW}   - Prometheus metrics and Grafana dashboards${NC}"
echo ""
read -p "Are you ABSOLUTELY sure? Type 'yes' to continue: " -r
echo

if [[ ! $REPLY == "yes" ]]; then
  echo -e "${GREEN}Aborted. No changes made.${NC}"
  exit 0
fi

echo ""
echo -e "${BLUE}Starting cleanup...${NC}"
echo ""

# Remove ArgoCD Applications
echo -e "${YELLOW}1️⃣  Removing ArgoCD Applications...${NC}"
kubectl delete -f apps/ 2>/dev/null || echo "   Applications already removed"

echo -e "${YELLOW}   Waiting for Applications to be deleted...${NC}"
sleep 10

# Remove namespaces
echo -e "${YELLOW}2️⃣  Removing namespaces...${NC}"
kubectl delete namespace clickhouse 2>/dev/null || echo "   clickhouse namespace not found"
kubectl delete namespace cloudnative-pg 2>/dev/null || echo "   cloudnative-pg namespace not found"
kubectl delete namespace peerdb 2>/dev/null || echo "   peerdb namespace not found"
kubectl delete namespace monitoring 2>/dev/null || echo "   monitoring namespace not found"

echo -e "${YELLOW}   Waiting for namespaces to be deleted (this may take a while)...${NC}"
sleep 20

# Remove ArgoCD (optional)
echo ""
echo -e "${YELLOW}3️⃣  Do you want to remove ArgoCD as well?${NC}"
read -p "Remove ArgoCD? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  kubectl delete namespace argocd 2>/dev/null || echo "   ArgoCD already removed"
  echo -e "${GREEN}✅ ArgoCD removed${NC}"
else
  echo -e "${YELLOW}⚠️  ArgoCD kept${NC}"
fi

# Remove node labels and taints (optional)
echo ""
echo -e "${YELLOW}4️⃣  Do you want to remove node labels and taints?${NC}"
read -p "Clean up node labels/taints? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "  Removing labels..."
  kubectl label node worker-1 workload- 2>/dev/null || echo "    worker-1 not found"
  kubectl label node worker-2 workload- 2>/dev/null || echo "    worker-2 not found"
  kubectl label node worker-3 workload- 2>/dev/null || echo "    worker-3 not found"
  kubectl label node worker-4 workload- 2>/dev/null || echo "    worker-4 not found"
  kubectl label node worker-5 workload- 2>/dev/null || echo "    worker-5 not found"

  echo -e "  Removing taints..."
  kubectl taint node worker-1 workload- 2>/dev/null || echo "    worker-1 not tainted"
  kubectl taint node worker-2 workload- 2>/dev/null || echo "    worker-2 not tainted"
  kubectl taint node worker-3 workload- 2>/dev/null || echo "    worker-3 not tainted"
  kubectl taint node worker-4 workload- 2>/dev/null || echo "    worker-4 not tainted"
  kubectl taint node worker-5 workload- 2>/dev/null || echo "    worker-5 not tainted"

  echo -e "${GREEN}✅ Node labels and taints removed${NC}"
else
  echo -e "${YELLOW}⚠️  Node labels/taints kept${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  CLEANUP COMPLETE!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Verification:${NC}"
echo "kubectl get namespaces | grep -E 'clickhouse|cloudnative-pg|peerdb|monitoring|argocd'"
echo "kubectl get applications -n argocd 2>/dev/null"
echo "kubectl get nodes --show-labels | grep workload"
