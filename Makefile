.PHONY: help install-argocd deploy-apps sync-all clean status test setup-nodes

# Colors
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
NC := \033[0m

help: ## Show this help
	@echo "$(BLUE)Zapper ArgoCD GitOps - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-30s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  1. make install-argocd"
	@echo "  2. make deploy-apps"
	@echo "  3. make setup-nodes (optional, if you have 5 workers)"
	@echo "  4. make status"
	@echo "  5. make test"
	@echo ""

# ===================================
# Installation
# ===================================

install-argocd: ## Install ArgoCD in the cluster
	@echo "$(BLUE)Installing ArgoCD...$(NC)"
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "$(YELLOW)Waiting for ArgoCD to be ready...$(NC)"
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
	@echo ""
	@echo "$(GREEN)✅ ArgoCD installed successfully!$(NC)"
	@echo ""
	@echo "Get admin password:"
	@echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

install: install-argocd deploy-apps ## Full installation (ArgoCD + Apps)
	@echo ""
	@echo "$(GREEN)✅ Full installation complete!$(NC)"
	@echo "$(YELLOW)Run 'make test' to verify everything is working$(NC)"

deploy-apps: ## Deploy all applications via ArgoCD
	@echo "$(BLUE)Deploying applications...$(NC)"
	@kubectl apply -f apps/
	@echo "$(GREEN)✅ Applications deployed!$(NC)"
	@echo "Check status: kubectl get applications -n argocd"

quickstart: ## Run quickstart script (installs everything)
	@./scripts/quickstart.sh

# ===================================
# Configuration
# ===================================

setup-nodes: ## Setup node affinity (labels and taints)
	@./scripts/setup-node-affinity.sh

setup-cdc: ## Setup PeerDB CDC mirror automatically
	@./scripts/setup-peerdb-mirror.sh

# ===================================
# Status & Monitoring
# ===================================

status: ## Show status of all applications and pods
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║             ZAPPER ARGOCD - STATUS OVERVIEW               ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)ArgoCD Applications:$(NC)"
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "$(YELLOW)ClickHouse Pods:$(NC)"
	@kubectl get pods -n clickhouse 2>/dev/null || echo "ClickHouse not deployed"
	@echo ""
	@echo "$(YELLOW)PostgreSQL Pods:$(NC)"
	@kubectl get pods -n cloudnative-pg 2>/dev/null || echo "PostgreSQL not deployed"
	@echo ""
	@echo "$(YELLOW)PeerDB Pods:$(NC)"
	@kubectl get pods -n peerdb 2>/dev/null || echo "PeerDB not deployed"
	@echo ""
	@echo "$(YELLOW)Monitoring Pods:$(NC)"
	@kubectl get pods -n monitoring 2>/dev/null || echo "Monitoring not deployed"
	@echo ""
	@echo "$(YELLOW)HPAs:$(NC)"
	@kubectl get hpa --all-namespaces 2>/dev/null || echo "No HPAs found"

test: ## Run end-to-end tests
	@./scripts/test-e2e.sh

fix-sync: ## Fix ArgoCD sync status (Unknown → Synced)
	@./scripts/fix-argocd-sync.sh

watch: ## Watch all pods in real-time
	@watch -n 2 'kubectl get pods --all-namespaces | grep -E "NAMESPACE|clickhouse|cloudnative-pg|peerdb|monitoring"'

top: ## Show resource usage
	@echo "$(YELLOW)Node Resources:$(NC)"
	@kubectl top nodes 2>/dev/null || echo "Metrics server not installed"
	@echo ""
	@echo "$(YELLOW)Pod Resources (Top 20):$(NC)"
	@kubectl top pods --all-namespaces 2>/dev/null | head -20 || echo "Metrics server not installed"

# ===================================
# Port Forwarding
# ===================================

port-forward-argocd: ## Port-forward ArgoCD UI to localhost:8080
	@echo "$(BLUE)Port-forwarding ArgoCD UI to https://localhost:8080$(NC)"
	@echo "$(YELLOW)Username: admin$(NC)"
	@echo "$(YELLOW)Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d$(NC)"
	@kubectl port-forward svc/argocd-server -n argocd 8080:443

port-forward-peerdb: ## Port-forward PeerDB UI to localhost:3000
	@echo "$(BLUE)Port-forwarding PeerDB UI to http://localhost:3000$(NC)"
	@kubectl port-forward -n peerdb svc/peerdb 3000:3000

port-forward-grafana: ## Port-forward Grafana to localhost:3001
	@echo "$(BLUE)Port-forwarding Grafana to http://localhost:3001$(NC)"
	@echo "$(YELLOW)Username: admin$(NC)"
	@echo "$(YELLOW)Password: admin123$(NC)"
	@kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80

port-forward-prometheus: ## Port-forward Prometheus to localhost:9090
	@echo "$(BLUE)Port-forwarding Prometheus to http://localhost:9090$(NC)"
	@kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

port-forward-clickhouse: ## Port-forward ClickHouse to localhost:8123 and localhost:9000
	@echo "$(BLUE)Port-forwarding ClickHouse...$(NC)"
	@echo "$(YELLOW)HTTP: localhost:8123$(NC)"
	@echo "$(YELLOW)Native: localhost:9000$(NC)"
	@kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 8123:8123 9000:9000

port-forward-postgres: ## Port-forward PostgreSQL to localhost:5432
	@echo "$(BLUE)Port-forwarding PostgreSQL to localhost:5432$(NC)"
	@echo "$(YELLOW)Get password: kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d$(NC)"
	@kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432

port-forward-temporal: ## Port-forward Temporal UI to localhost:8088
	@echo "$(BLUE)Port-forwarding Temporal UI to http://localhost:8088$(NC)"
	@kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080

port-forward-all: ## Port-forward all services (run in separate terminals)
	@echo "$(YELLOW)Run these commands in separate terminals:$(NC)"
	@echo "  make port-forward-argocd"
	@echo "  make port-forward-peerdb"
	@echo "  make port-forward-grafana"
	@echo "  make port-forward-prometheus"
	@echo "  make port-forward-clickhouse"
	@echo "  make port-forward-postgres"
	@echo "  make port-forward-temporal"

# ===================================
# Logs
# ===================================

logs-clickhouse: ## Show ClickHouse logs (follow)
	@kubectl logs -n clickhouse -l app=clickhouse --tail=100 -f

logs-postgres: ## Show PostgreSQL logs (follow)
	@kubectl logs -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster --tail=100 -f

logs-peerdb: ## Show PeerDB logs (follow)
	@kubectl logs -n peerdb -l app=peerdb --tail=100 -f

logs-peerdb-worker: ## Show PeerDB flow-worker logs (follow)
	@kubectl logs -n peerdb deployment/peerdb-flow-worker --tail=100 -f

logs-temporal: ## Show Temporal logs (follow)
	@kubectl logs -n peerdb -l app.kubernetes.io/name=temporal --tail=100 -f

logs-prometheus: ## Show Prometheus logs (follow)
	@kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100 -f

logs-grafana: ## Show Grafana logs (follow)
	@kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100 -f

logs-argocd: ## Show ArgoCD logs (follow)
	@kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100 -f

# ===================================
# Sync & Refresh
# ===================================

sync-all: ## Sync all ArgoCD applications
	@echo "$(BLUE)Syncing all applications...$(NC)"
	@kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
	@echo "$(GREEN)✅ All applications synced!$(NC)"

refresh: sync-all ## Alias for sync-all

restart-clickhouse: ## Restart ClickHouse pods
	@kubectl rollout restart statefulset -n clickhouse 2>/dev/null || echo "ClickHouse not found"

restart-postgres: ## Restart PostgreSQL pods
	@kubectl rollout restart statefulset -n cloudnative-pg postgres-cluster 2>/dev/null || echo "PostgreSQL not found"

restart-peerdb: ## Restart PeerDB pods
	@kubectl rollout restart deployment -n peerdb peerdb peerdb-flow-worker 2>/dev/null || echo "PeerDB not found"

# ===================================
# Credentials
# ===================================

get-argocd-password: ## Get ArgoCD admin password
	@echo "$(YELLOW)ArgoCD Password:$(NC)"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
	@echo ""

get-postgres-password: ## Get PostgreSQL app_user password
	@echo "$(YELLOW)PostgreSQL Password:$(NC)"
	@kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d
	@echo ""

get-all-passwords: ## Get all passwords
	@echo "$(BLUE)═══ Credentials ═══$(NC)"
	@echo ""
	@echo "$(YELLOW)ArgoCD:$(NC)"
	@echo "  User: admin"
	@echo -n "  Pass: "
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "Not installed"
	@echo ""
	@echo ""
	@echo "$(YELLOW)PostgreSQL (CloudNativePG):$(NC)"
	@echo "  User: app_user"
	@echo "  DB: app_db"
	@echo -n "  Pass: "
	@kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "Not installed"
	@echo ""
	@echo ""
	@echo "$(YELLOW)ClickHouse:$(NC)"
	@echo "  User: admin"
	@echo "  Pass: admin123"
	@echo ""
	@echo "$(YELLOW)Grafana:$(NC)"
	@echo "  User: admin"
	@echo "  Pass: admin123"

# ===================================
# Cleanup
# ===================================

clean: ## Remove all applications (interactive)
	@./scripts/cleanup.sh

clean-apps: ## Remove only applications (keep ArgoCD)
	@echo "$(YELLOW)Removing all applications...$(NC)"
	@kubectl delete -f apps/ --ignore-not-found=true
	@echo "$(GREEN)✅ Applications removed$(NC)"

clean-all: ## Force remove everything (no prompts)
	@echo "$(RED)Force removing everything...$(NC)"
	@kubectl delete -f apps/ --ignore-not-found=true 2>/dev/null || true
	@kubectl delete namespace clickhouse cloudnative-pg peerdb monitoring argocd --ignore-not-found=true
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

# ===================================
# Development
# ===================================

validate: ## Validate YAML files
	@echo "$(BLUE)Validating YAML files...$(NC)"
	@find apps/ helm-values/ manifests/ -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \; > /dev/null
	@echo "$(GREEN)✅ All YAML files are valid$(NC)"

shell-clickhouse: ## Open shell in ClickHouse pod
	@kubectl exec -it -n clickhouse $$(kubectl get pods -n clickhouse -l app=clickhouse -o jsonpath='{.items[0].metadata.name}') -- clickhouse-client

shell-postgres: ## Open psql shell in PostgreSQL pod
	@kubectl exec -it -n cloudnative-pg postgres-cluster-1 -- psql -U app_user -d app_db

shell-peerdb: ## Open shell in PeerDB pod
	@kubectl exec -it -n peerdb $$(kubectl get pods -n peerdb -l app=peerdb -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

# ===================================
# Info
# ===================================

info: ## Show cluster and application info
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║           ZAPPER ARGOCD - CLUSTER INFORMATION             ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Cluster Info:$(NC)"
	@kubectl cluster-info | head -2
	@echo ""
	@echo "$(YELLOW)Nodes:$(NC)"
	@kubectl get nodes
	@echo ""
	@echo "$(YELLOW)Namespaces:$(NC)"
	@kubectl get namespaces | grep -E "NAME|argocd|clickhouse|cloudnative-pg|peerdb|monitoring"
	@echo ""
	@echo "$(YELLOW)Storage Classes:$(NC)"
	@kubectl get storageclass
	@echo ""
	@echo "$(YELLOW)PVCs:$(NC)"
	@kubectl get pvc --all-namespaces 2>/dev/null | head -10 || echo "No PVCs found"

version: ## Show versions of deployed components
	@echo "$(YELLOW)Component Versions:$(NC)"
	@echo "  ArgoCD: $$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | cut -d':' -f2 || echo 'Not installed')"
	@echo "  ClickHouse Operator: 0.23.6"
	@echo "  CloudNativePG: 0.21.6"
	@echo "  Prometheus Stack: 57.2.0"
