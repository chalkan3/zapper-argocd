# Zapper ArgoCD GitOps Repository

[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange)](https://argo-cd.readthedocs.io/)
[![Helm](https://img.shields.io/badge/Helm-Official%20Charts-blue)](https://helm.sh/)
[![K8s](https://img.shields.io/badge/Kubernetes-K3s-326CE5)](https://k3s.io/)

Este repositório contém a configuração GitOps para deploy de infraestrutura de dados com ArgoCD usando **Helm charts oficiais**.

> 💡 **Novo aqui?** Comece lendo [SUMMARY.txt](SUMMARY.txt) para uma visão geral visual ou use [INDEX.md](INDEX.md) para navegar pela documentação.

## Stack de Tecnologias

- **ArgoCD**: Gerenciamento GitOps
- **K3s**: Cluster Kubernetes lightweight
- **ClickHouse Operator**: Banco de dados analítico em modo cluster com Keeper
- **CloudNativePG**: PostgreSQL operado com dummy data
- **PeerDB**: ETL via CDC (Change Data Capture)
- **Temporal**: Workflow engine (dependência do PeerDB)

## Estrutura do Repositório

```
.
├── apps/                           # ArgoCD Applications
│   ├── clickhouse.yaml             # ClickHouse Operator + Cluster
│   ├── cloudnative-pg.yaml         # CloudNativePG Operator + Cluster
│   ├── peerdb-dependencies.yaml    # PostgreSQL + Temporal (Helm)
│   └── peerdb.yaml                 # PeerDB deployment
├── helm-values/                    # Valores customizados e CRDs
│   ├── clickhouse-cluster.yaml     # ClickHouseInstallation CRD
│   └── postgres-cluster.yaml       # PostgreSQL Cluster CRD
├── manifests/                      # Manifests Kubernetes
│   └── peerdb/                     # PeerDB deployment e service
├── bootstrap/                      # Bootstrap do ArgoCD
│   └── argocd-install.yaml
└── docs/                           # Documentação
    ├── PEERDB_SETUP.md
    ├── ARCHITECTURE.md
    └── CHECKLIST.md
```

## Helm Charts Utilizados

Este repositório usa **Helm charts oficiais** via ArgoCD:

- **ClickHouse Operator**: `altinity/clickhouse-operator` (v0.23.6)
- **CloudNativePG**: `cloudnative-pg/cloudnative-pg` (v0.21.6)
- **PostgreSQL**: `bitnami/postgresql` (v15.5.20)
- **Temporal**: `temporal/temporal` (v0.45.1)
- **PeerDB**: Manifests customizados (sem Helm chart oficial)

## Pré-requisitos

1. Cluster K3s instalado (control-plane + workers)
2. kubectl configurado
3. Helm 3+ instalado

## Instalação

### 1. Instalar K3s (se necessário)

```bash
# Control plane
curl -sfL https://get.k3s.io | sh -

# Workers (executar em cada node)
curl -sfL https://get.k3s.io | K3S_URL=https://control-plane:6443 K3S_TOKEN=<token> sh -
```

### 2. Instalar ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar ArgoCD estar pronto
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Obter senha inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 3. Expor ArgoCD UI (opcional)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Acesse: https://localhost:8080
# User: admin
# Password: obtido no passo anterior
```

### 4. Configurar repositório Git

Antes de aplicar, atualize as URLs do repositório em `apps/*.yaml`:

```bash
# Substituir YOUR_USERNAME pelo seu usuário GitHub
sed -i '' 's/YOUR_USERNAME/seu-usuario/g' apps/*.yaml
```

### 5. Push para o Git

```bash
git init
git add .
git commit -m "Initial GitOps setup"
git remote add origin https://github.com/seu-usuario/zapper-argocd.git
git push -u origin main
```

### 6. Deploy das aplicações via ArgoCD

```bash
# Aplicar as Applications
kubectl apply -f apps/

# Ou usar o quickstart
./quickstart.sh
```

## Ordem de Deploy

As aplicações serão deployadas automaticamente pelo ArgoCD:

1. **clickhouse-operator** → Helm chart oficial do Altinity
2. **clickhouse-cluster** → CRD ClickHouseInstallation com Keeper
3. **cloudnative-pg-operator** → Helm chart oficial
4. **postgres-cluster** → CRD Cluster do CloudNativePG
5. **peerdb-postgresql** → Helm chart Bitnami PostgreSQL
6. **peerdb-temporal** → Helm chart oficial do Temporal
7. **peerdb** → Manifests customizados (server + flow-workers)

## Configuração do PeerDB

Após o deploy, acesse a interface do PeerDB para configurar:

1. Port-forward do PeerDB:
```bash
kubectl port-forward -n peerdb svc/peerdb 3000:3000
```

2. Acesse http://localhost:3000

3. Configure os Sources:
   - **PostgreSQL Source**: CloudNativePG endpoint
   - **ClickHouse Source**: ClickHouse cluster endpoint

4. Crie o Mirror PG → CH através da interface

## ClickHouse Cluster

O ClickHouse será deployado em modo cluster com:
- 2+ shards para distribuição de dados
- Replicação com ClickHouse Keeper
- Alta disponibilidade

Acesso ao ClickHouse:
```bash
kubectl port-forward -n clickhouse svc/clickhouse 8123:8123 9000:9000
```

## CloudNativePG

PostgreSQL com:
- Cluster de 3 réplicas
- Backup automático
- Dummy data pré-carregado

Acesso ao PostgreSQL:
```bash
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432

# Credenciais estão no secret
kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### Verificar status das aplicações
```bash
kubectl get applications -n argocd
```

### Logs dos componentes
```bash
# ClickHouse
kubectl logs -n clickhouse -l app=clickhouse

# CloudNativePG
kubectl logs -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster

# PeerDB
kubectl logs -n peerdb -l app=peerdb

# Temporal
kubectl logs -n peerdb -l app.kubernetes.io/name=temporal
```

## Arquitetura

```
┌─────────────────┐         CDC          ┌─────────────────┐
│  CloudNativePG  │ ────────────────────> │   ClickHouse    │
│   (PostgreSQL)  │      via PeerDB       │    (Cluster)    │
└─────────────────┘                       └─────────────────┘
        │                                          │
        │                                          │
        v                                          v
   Dummy Data                              Sharded + Keeper
   3 replicas                              2+ shards
```

## Limpeza

```bash
# Remover todas as aplicações
kubectl delete -f apps/

# Remover ArgoCD
kubectl delete namespace argocd
```
