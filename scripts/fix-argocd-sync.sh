#!/bin/bash

# Script para corrigir status "Unknown" do ArgoCD
# Força sync e hard refresh de todas Applications

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  ArgoCD Sync Status Fix Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Check if argocd namespace exists
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}Error: argocd namespace not found${NC}"
    exit 1
fi

# Get all applications
echo -e "${YELLOW}📋 Listing all ArgoCD Applications...${NC}"
echo ""
kubectl get applications -n argocd
echo ""

# Ask for confirmation
read -p "Do you want to fix sync status for ALL applications? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🔄 Step 1: Hard Refresh all Applications${NC}"
echo -e "${YELLOW}This will force ArgoCD to recalculate sync status...${NC}"
echo ""

# Hard refresh all applications
kubectl get applications -n argocd -o name | while read app; do
    app_name=$(echo $app | cut -d'/' -f2)
    echo -e "  ${GREEN}→${NC} Hard refresh: ${app_name}"

    kubectl patch $app -n argocd \
        --type merge \
        -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
        2>/dev/null || echo -e "    ${RED}✗ Failed${NC}"
done

echo ""
echo -e "${GREEN}✓ Hard refresh completed${NC}"
echo ""
echo -e "${YELLOW}⏳ Waiting 10 seconds for ArgoCD to process...${NC}"
sleep 10

echo ""
echo -e "${BLUE}🔄 Step 2: Force Sync all Applications${NC}"
echo -e "${YELLOW}This will sync Git state to cluster...${NC}"
echo ""

# Check if argocd CLI is available
if command -v argocd &> /dev/null; then
    # Use argocd CLI
    kubectl get applications -n argocd -o name | while read app; do
        app_name=$(echo $app | cut -d'/' -f2)
        echo -e "  ${GREEN}→${NC} Force sync: ${app_name}"

        argocd app sync $app_name --force 2>/dev/null || \
            echo -e "    ${YELLOW}! Skipped (may need manual sync)${NC}"
    done
else
    # Use kubectl patch
    echo -e "${YELLOW}Note: argocd CLI not found, using kubectl patch method${NC}"
    echo ""

    kubectl get applications -n argocd -o name | while read app; do
        app_name=$(echo $app | cut -d'/' -f2)
        echo -e "  ${GREEN}→${NC} Triggering sync: ${app_name}"

        kubectl patch $app -n argocd \
            --type merge \
            -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' \
            2>/dev/null || echo -e "    ${RED}✗ Failed${NC}"
    done
fi

echo ""
echo -e "${GREEN}✓ Sync operations triggered${NC}"
echo ""
echo -e "${YELLOW}⏳ Waiting 15 seconds for sync to complete...${NC}"
sleep 15

echo ""
echo -e "${BLUE}📊 Step 3: Checking final status${NC}"
echo ""
kubectl get applications -n argocd
echo ""

# Count status
unknown_count=$(kubectl get applications -n argocd -o json | jq -r '.items[] | select(.status.sync.status == "Unknown") | .metadata.name' | wc -l)
synced_count=$(kubectl get applications -n argocd -o json | jq -r '.items[] | select(.status.sync.status == "Synced") | .metadata.name' | wc -l)
total_count=$(kubectl get applications -n argocd -o json | jq '.items | length')

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Total Applications: ${BLUE}${total_count}${NC}"
echo -e "Synced:            ${GREEN}${synced_count}${NC}"
echo -e "Unknown:           ${YELLOW}${unknown_count}${NC}"
echo ""

if [ "$unknown_count" -eq 0 ]; then
    echo -e "${GREEN}✅ All applications are synced!${NC}"
else
    echo -e "${YELLOW}⚠️  Some applications still show 'Unknown' status${NC}"
    echo ""
    echo -e "Applications with 'Unknown' status:"
    kubectl get applications -n argocd -o json | \
        jq -r '.items[] | select(.status.sync.status == "Unknown") | "  - " + .metadata.name'
    echo ""
    echo -e "${YELLOW}Manual steps to fix:${NC}"
    echo ""
    echo "1. Check if resources already exist in cluster:"
    echo "   kubectl get all -n <namespace>"
    echo ""
    echo "2. Delete and recreate the Application (keeps resources):"
    echo "   kubectl delete application <app-name> -n argocd"
    echo "   kubectl apply -f apps/<app-file>.yaml"
    echo ""
    echo "3. Or use ArgoCD UI to force sync:"
    echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
    echo "   Visit: https://localhost:8080"
    echo ""
fi

echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "For more help, see: ${BLUE}TROUBLESHOOTING.md${NC}"
echo ""
