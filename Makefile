.PHONY: help install-argocd deploy-apps sync-all clean port-forward-argocd port-forward-peerdb port-forward-clickhouse

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

install-argocd: ## Install ArgoCD in the cluster
	@echo "Installing ArgoCD..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
	@echo ""
	@echo "ArgoCD installed successfully!"
	@echo ""
	@echo "Get admin password with:"
	@echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

deploy-apps: ## Deploy all applications via ArgoCD
	@echo "Deploying applications..."
	kubectl apply -f apps/
	@echo "Applications deployed! Check status with: kubectl get applications -n argocd"

sync-all: ## Sync all ArgoCD applications
	@echo "Syncing all applications..."
	kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

clean: ## Remove all applications and ArgoCD
	@echo "Removing all applications..."
	kubectl delete -f apps/ --ignore-not-found=true
	@echo "Removing ArgoCD..."
	kubectl delete namespace argocd --ignore-not-found=true
	kubectl delete namespace clickhouse --ignore-not-found=true
	kubectl delete namespace cloudnative-pg --ignore-not-found=true
	kubectl delete namespace peerdb --ignore-not-found=true

port-forward-argocd: ## Port-forward ArgoCD UI to localhost:8080
	@echo "Port-forwarding ArgoCD UI to https://localhost:8080"
	@echo "Username: admin"
	@echo "Password: Run 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d'"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

port-forward-peerdb: ## Port-forward PeerDB UI to localhost:3000
	@echo "Port-forwarding PeerDB UI to http://localhost:3000"
	kubectl port-forward -n peerdb svc/peerdb 3000:3000

port-forward-clickhouse: ## Port-forward ClickHouse to localhost:8123 and localhost:9000
	@echo "Port-forwarding ClickHouse to localhost:8123 (HTTP) and localhost:9000 (Native)"
	kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-cluster-0-0 8123:8123 9000:9000

port-forward-postgres: ## Port-forward CloudNativePG to localhost:5432
	@echo "Port-forwarding PostgreSQL to localhost:5432"
	kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432

status: ## Show status of all applications
	@echo "=== ArgoCD Applications ==="
	kubectl get applications -n argocd
	@echo ""
	@echo "=== ClickHouse Pods ==="
	kubectl get pods -n clickhouse
	@echo ""
	@echo "=== CloudNativePG Pods ==="
	kubectl get pods -n cloudnative-pg
	@echo ""
	@echo "=== PeerDB Pods ==="
	kubectl get pods -n peerdb

logs-clickhouse: ## Show ClickHouse logs
	kubectl logs -n clickhouse -l app=clickhouse --tail=100 -f

logs-postgres: ## Show PostgreSQL logs
	kubectl logs -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster --tail=100 -f

logs-peerdb: ## Show PeerDB logs
	kubectl logs -n peerdb -l app=peerdb --tail=100 -f

logs-temporal: ## Show Temporal logs
	kubectl logs -n peerdb -l app.kubernetes.io/name=temporal --tail=100 -f
