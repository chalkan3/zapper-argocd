#!/bin/bash

set -e

echo "=================================="
echo "Zapper ArgoCD GitOps Quick Start"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
echo ""

# Step 1: Install ArgoCD
echo "Step 1: Installing ArgoCD..."
echo "----------------------------"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo -e "${GREEN}✓ ArgoCD installed successfully${NC}"
echo ""

# Get ArgoCD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Admin Credentials:"
echo "  URL: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""

# Step 2: Update repository URL in app manifests
echo "Step 2: Update repository URL"
echo "------------------------------"
echo ""
echo -e "${YELLOW}IMPORTANT: You need to update the repository URL in apps/*.yaml files${NC}"
echo ""
echo "Please replace 'YOUR_USERNAME' with your actual GitHub username in:"
echo "  - apps/01-clickhouse-operator.yaml"
echo "  - apps/02-cloudnative-pg-operator.yaml"
echo "  - apps/03-peerdb-dependencies.yaml"
echo "  - apps/04-peerdb.yaml"
echo "  - apps/05-hpa.yaml"
echo "  - apps/06-monitoring.yaml"
echo "  - apps/07-peerdb-setup.yaml"
echo ""
echo "Or if you're using a different git repository, update the repoURL accordingly."
echo ""
read -p "Press Enter after you've updated the repository URLs..."
echo ""

# Step 3: Deploy applications
echo "Step 3: Deploying applications via ArgoCD..."
echo "--------------------------------------------"

kubectl apply -f apps/

echo -e "${GREEN}✓ Applications submitted to ArgoCD${NC}"
echo ""

# Step 4: Wait for applications to sync
echo "Step 4: Waiting for applications to sync..."
echo "-------------------------------------------"
echo ""
echo "This may take several minutes. You can monitor progress with:"
echo "  kubectl get applications -n argocd -w"
echo ""

# Wait a bit for apps to be created
sleep 10

# Check application status
echo "Current application status:"
kubectl get applications -n argocd
echo ""

# Step 5: Show next steps
echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Monitor ArgoCD applications:"
echo "   kubectl get applications -n argocd -w"
echo ""
echo "2. Access ArgoCD UI:"
echo "   make port-forward-argocd"
echo "   Then visit: https://localhost:8080"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "3. Wait for all applications to be 'Healthy' and 'Synced'"
echo ""
echo "4. Configure PeerDB for CDC (after all apps are healthy):"
echo "   See PEERDB_SETUP.md for detailed instructions"
echo "   Quick start:"
echo "     make port-forward-peerdb"
echo "     Visit: http://localhost:3000"
echo ""
echo "5. Access services:"
echo "   - ClickHouse: make port-forward-clickhouse (ports 8123, 9000)"
echo "   - PostgreSQL: make port-forward-postgres (port 5432)"
echo "   - PeerDB: make port-forward-peerdb (port 3000)"
echo ""
echo "For more commands, run: make help"
echo ""
echo "=================================="
