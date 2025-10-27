# Zapper ArgoCD GitOps Repository

[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange)](https://argo-cd.readthedocs.io/)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1689?logo=helm)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![K3s](https://img.shields.io/badge/K3s-Compatible-FFC61C?logo=k3s)](https://k3s.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Maintenance](https://img.shields.io/badge/Maintained-Yes-green.svg)](https://github.com/chalkan3/zapper-argocd/commits/main)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> Repositório GitOps completo para deploy de infraestrutura de dados com **ClickHouse** (cluster mode), **PostgreSQL** (CloudNativePG), **PeerDB** (CDC/ETL), **Temporal** (workflows) e **Prometheus/Grafana** (monitoring).

## ⭐ Features

- ✅ **GitOps Completo** - ArgoCD sincroniza tudo automaticamente do Git
- ✅ **ClickHouse Cluster** - 2 shards, 2 replicas, 3 Keepers (HA)
- ✅ **PostgreSQL HA** - CloudNativePG com 3 instâncias + dummy data
- ✅ **CDC em Tempo Real** - PeerDB para replicação PG → CH
- ✅ **Auto-scaling** - 9 HPAs configurados (CPU/Memory)
- ✅ **Node Affinity** - Pods distribuídos em 5 workers específicos
- ✅ **Monitoring Stack** - Prometheus, Grafana, Alertmanager
- ✅ **Dashboards Prontos** - Kubernetes, ClickHouse, PostgreSQL, CDC
- ✅ **Testes E2E** - Script automatizado de validação
- ✅ **Scripts Úteis** - Quickstart, setup, cleanup, testes

---

## 📋 Índice

1. [Stack de Tecnologias](#stack-de-tecnologias)
2. [Arquitetura](#arquitetura)
3. [Estrutura do Repositório](#estrutura-do-reposit%C3%B3rio)
4. [Componentes Deployados](#componentes-deployados)
5. [Quick Start](#quick-start)
6. [Instalação Detalhada](#instala%C3%A7%C3%A3o-detalhada)
7. [Configuração de Node Affinity](#configura%C3%A7%C3%A3o-de-node-affinity)
8. [HPAs (Auto-scaling)](#hpas-auto-scaling)
9. [Configuração do CDC (PeerDB)](#configura%C3%A7%C3%A3o-do-cdc-peerdb)
10. [Monitoramento (Prometheus & Grafana)](#monitoramento-prometheus--grafana)
11. [Testes](#testes)
12. [Comandos Úteis](#comandos-%C3%BAteis)
13. [Troubleshooting](#troubleshooting)
14. [Limpeza](#limpeza)

---

## Stack de Tecnologias

- **ArgoCD**: Gerenciamento GitOps e sincronização automática
- **K3s**: Cluster Kubernetes lightweight
- **ClickHouse Operator**: Banco analítico em modo cluster (2 shards, 2 replicas, Keeper)
- **CloudNativePG**: PostgreSQL operado com 3 instâncias + dummy data
- **PeerDB**: CDC/ETL para replicação PostgreSQL → ClickHouse
- **Temporal**: Workflow engine (dependência do PeerDB)
- **Prometheus**: Coleta de métricas
- **Grafana**: Visualização e dashboards
- **HPAs**: Auto-scaling automático baseado em CPU/memória

---

## Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                        ArgoCD                                │
│              (Sincroniza do Git → Cluster)                   │
└──────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
        ┌───────▼──────┐ ┌─▼─────────┐ ┌▼────────────┐
        │  ClickHouse  │ │PostgreSQL │ │   PeerDB    │
        │   Operator   │ │ Operator  │ │             │
        └───────┬──────┘ └─┬─────────┘ └┬────────────┘
                │           │            │
        ┌───────▼──────┐ ┌─▼─────────┐ ┌▼────────────┐
        │  ClickHouse  │ │PostgreSQL │ │  PeerDB     │
        │   Cluster    │ │  Cluster  │ │  Server +   │
        │              │ │           │ │  Workers    │
        │ 2 shards     │ │3 instances│ │             │
        │ 2 replicas   │ │Dummy Data │ │  + Deps:    │
        │ 3 keepers    │ │           │ │  - Postgres │
        └──────────────┘ └───────────┘ │  - Temporal │
                │            │          └─────────────┘
                │            │                 │
                │       CDC (PeerDB)           │
                │◄───────────┴─────────────────┘
                │
        ┌───────▼──────────────────────────────┐
        │      Prometheus + Grafana            │
        │  (Métricas e Dashboards)             │
        └──────────────────────────────────────┘

Worker Distribution:
├── worker-1, worker-2: PostgreSQL pods
├── worker-3: ClickHouse pods
└── worker-4, worker-5: PeerDB pods
```

---

## Estrutura do Repositório

```
zapper-argocd/
├── apps/                              ← ArgoCD Applications (10 total)
│   ├── clickhouse.yaml                 (Operator + Cluster)
│   ├── cloudnative-pg.yaml             (Operator + Cluster)
│   ├── peerdb-dependencies.yaml        (PostgreSQL + Temporal)
│   ├── peerdb.yaml                     (PeerDB server + workers)
│   ├── hpa.yaml                        (HPAs para auto-scaling)
│   └── monitoring.yaml                 (Prometheus + Grafana + ServiceMonitors)
│
├── helm-values/                       ← Configurações Helm e CRDs
│   ├── clickhouse-cluster.yaml         (2 shards, 2 replicas, node affinity)
│   ├── postgres-cluster.yaml           (3 instances, dummy data, CDC, node affinity)
│   ├── clickhouse-operator-values.yaml
│   ├── cloudnative-pg-values.yaml
│   ├── peerdb-values.yaml
│   ├── postgresql-values.yaml
│   ├── temporal-values.yaml
│   └── monitoring/
│       └── kube-prometheus-stack-values.yaml
│
├── manifests/                         ← Kubernetes YAML
│   ├── peerdb/
│   │   ├── deployment.yaml             (server + flow-workers com node affinity)
│   │   └── service.yaml
│   ├── hpa/
│   │   ├── peerdb-hpa.yaml             (2 HPAs)
│   │   ├── postgres-hpa.yaml           (2 HPAs)
│   │   ├── clickhouse-hpa.yaml         (1 HPA)
│   │   └── temporal-hpa.yaml           (4 HPAs)
│   └── monitoring/
│       ├── servicemonitor-postgres.yaml
│       ├── servicemonitor-clickhouse.yaml
│       ├── servicemonitor-peerdb.yaml
│       ├── servicemonitor-temporal.yaml
│       └── grafana-dashboards-configmap.yaml
│
├── quickstart.sh                      ← Instalação rápida
├── test-e2e.sh                        ← Testes automatizados
├── Makefile                           ← Comandos úteis
└── README.md                          ← Este arquivo
```

---

## Componentes Deployados

| Componente | Namespace | Tipo | Versão | Pods | Storage |
|------------|-----------|------|--------|------|---------|
| ClickHouse Operator | `clickhouse` | Helm | 0.23.6 | 1 | - |
| ClickHouse Cluster | `clickhouse` | CRD | 23.8 | 4 (2 shards × 2 replicas) | 100Gi cada |
| ClickHouse Keeper | `clickhouse` | CRD | 23.8 | 3 | 10Gi cada |
| CloudNativePG Operator | `cloudnative-pg` | Helm | 0.21.6 | 1 | - |
| PostgreSQL Cluster | `cloudnative-pg` | CRD | 16 | 3 | 20Gi cada |
| PostgreSQL (metadata) | `peerdb` | Helm | 15 | 1 | 8Gi |
| Temporal | `peerdb` | Helm | 0.45.1 | 4+ | 10Gi |
| PeerDB | `peerdb` | Manifests | latest | 3 (1 server + 2 workers) | - |
| Prometheus | `monitoring` | Helm | 57.2.0 | 1 | 50Gi |
| Grafana | `monitoring` | Helm | 57.2.0 | 1 | 10Gi |
| Alertmanager | `monitoring` | Helm | 57.2.0 | 1 | 10Gi |

**Total: 10 ArgoCD Applications, 9 HPAs, 4 ServiceMonitors**

---

## ⚡ Quick Start

```bash
# 1. Clonar repositório
git clone https://github.com/chalkan3/zapper-argocd.git
cd zapper-argocd

# 2. Executar quickstart (instala tudo)
./scripts/quickstart.sh

# Ou manualmente:
make install          # Instala ArgoCD + Deploy apps
make setup-nodes      # Configura node affinity (opcional)
make test             # Valida instalação

# 3. Aguardar todos os pods (5-10 min)
kubectl get pods --all-namespaces -w

# 4. Acessar serviços
make port-forward-argocd    # https://localhost:8080 (ArgoCD)
make port-forward-peerdb    # http://localhost:3000 (PeerDB)
make port-forward-grafana   # http://localhost:3001 (Grafana)
```

### Comandos Úteis

```bash
make help                    # Ver todos os comandos disponíveis
make status                  # Status de todos os componentes
make test                    # Rodar testes E2E
make get-all-passwords       # Ver todas as credenciais
make clean                   # Remover tudo (interativo)
```

**Credenciais padrão:**
- **ArgoCD**: admin / (secret: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`)
- **Grafana**: admin / admin123
- **ClickHouse**: admin / admin123
- **PostgreSQL (app)**: app_user / (secret: `kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d`)

---

## Instalação Detalhada

### Pré-requisitos

1. **Cluster K3s** com 1 control-plane + 5 workers (ou mínimo 1 control-plane)
2. **kubectl** configurado
3. **Helm 3+** instalado
4. **Git** configurado

### 1. Instalar K3s (se necessário)

```bash
# Control plane
curl -sfL https://get.k3s.io | sh -

# Copiar kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Workers (executar em cada node)
# Obter token: sudo cat /var/lib/rancher/k3s/server/node-token
curl -sfL https://get.k3s.io | K3S_URL=https://<control-plane-ip>:6443 K3S_TOKEN=<token> sh -

# Verificar nodes
kubectl get nodes
```

### 2. Instalar ArgoCD

```bash
# Criar namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar pods prontos
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Obter senha inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # Nova linha

# Port-forward (opcional)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
# Acesse: https://localhost:8080 (admin / senha acima)
```

### 3. Deploy das Applications

```bash
# Aplicar todas as Applications
kubectl apply -f apps/

# Ou usar o Makefile
make deploy-apps

# Monitorar sync
kubectl get applications -n argocd -w
```

### 4. Aguardar Sync Completo

```bash
# Verificar status
kubectl get applications -n argocd

# Esperado: SYNC STATUS = Synced, HEALTH = Healthy
# clickhouse-operator           Synced     Healthy
# clickhouse-cluster            Synced     Healthy
# cloudnative-pg-operator       Synced     Healthy
# postgres-cluster              Synced     Healthy
# peerdb-postgresql             Synced     Healthy
# peerdb-temporal               Synced     Healthy
# peerdb                        Synced     Healthy
# hpa                           Synced     Healthy
# kube-prometheus-stack         Synced     Healthy
# monitoring-servicemonitors    Synced     Healthy

# Verificar todos os pods
kubectl get pods --all-namespaces
```

---

## Configuração de Node Affinity

Para distribuir os pods corretamente nos 5 workers:

### 1. Labeling dos Nodes

```bash
# Worker 1 e 2: PostgreSQL
kubectl label node worker-1 workload=postgres
kubectl label node worker-2 workload=postgres

# Worker 3: ClickHouse
kubectl label node worker-3 workload=clickhouse

# Worker 4 e 5: PeerDB
kubectl label node worker-4 workload=peerdb
kubectl label node worker-5 workload=peerdb

# Verificar labels
kubectl get nodes --show-labels | grep workload
```

### 2. Taints (Opcional - para dedicar nodes)

```bash
# PostgreSQL nodes (workers 1-2)
kubectl taint node worker-1 workload=postgres:NoSchedule
kubectl taint node worker-2 workload=postgres:NoSchedule

# ClickHouse node (worker 3)
kubectl taint node worker-3 workload=clickhouse:NoSchedule

# PeerDB nodes (workers 4-5)
kubectl taint node worker-4 workload=peerdb:NoSchedule
kubectl taint node worker-5 workload=peerdb:NoSchedule
```

### 3. Forçar Reschedule (se pods já estiverem rodando)

```bash
# PostgreSQL
kubectl rollout restart statefulset -n cloudnative-pg postgres-cluster

# ClickHouse
kubectl rollout restart statefulset -n clickhouse

# PeerDB
kubectl rollout restart deployment -n peerdb peerdb
kubectl rollout restart deployment -n peerdb peerdb-flow-worker
```

### 4. Verificar Distribuição

```bash
# Ver pods por node
kubectl get pods -o wide --all-namespaces | grep -E "postgres|clickhouse|peerdb" | awk '{print $1, $2, $8}'

# Esperado:
# cloudnative-pg  postgres-cluster-1        worker-1
# cloudnative-pg  postgres-cluster-2        worker-2
# cloudnative-pg  postgres-cluster-3        worker-1 ou worker-2
# clickhouse      clickhouse-...            worker-3
# peerdb          peerdb-server-...         worker-4
# peerdb          peerdb-flow-worker-...    worker-5
```

---

## HPAs (Auto-scaling)

9 HPAs configurados para auto-scaling baseado em CPU e memória:

| HPA | Namespace | Target | Min | Max | CPU Target | Memory Target |
|-----|-----------|--------|-----|-----|------------|---------------|
| peerdb-hpa | peerdb | peerdb | 1 | 5 | 75% | 80% |
| peerdb-flow-worker-hpa | peerdb | peerdb-flow-worker | 2 | 10 | 75% | 80% |
| postgres-cluster-hpa | cloudnative-pg | postgres-cluster | 3 | 5 | 75% | - |
| peerdb-postgresql-hpa | peerdb | peerdb-postgresql | 1 | 3 | 75% | 80% |
| clickhouse-cluster-hpa | clickhouse | clickhouse-cluster | 4 | 8 | 70% | 80% |
| temporal-frontend-hpa | peerdb | temporal-frontend | 1 | 3 | 75% | - |
| temporal-history-hpa | peerdb | temporal-history | 1 | 5 | 75% | - |
| temporal-matching-hpa | peerdb | temporal-matching | 1 | 3 | 75% | - |
| temporal-worker-hpa | peerdb | temporal-worker | 1 | 5 | 75% | - |

### Verificar HPAs

```bash
# Ver todos os HPAs
kubectl get hpa --all-namespaces

# Ver métricas atuais
kubectl top pods -n peerdb
kubectl top pods -n cloudnative-pg
kubectl top pods -n clickhouse

# Monitorar scaling
watch kubectl get hpa --all-namespaces
```

### Instalar Metrics Server (se necessário)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Para K3s, adicionar --kubelet-insecure-tls
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

---

## Configuração do CDC (PeerDB)

### 🚀 Configuração Automática (Recomendado)

O CDC mirror é configurado **automaticamente** via Kubernetes Job após o deploy:

```bash
# O Job executa automaticamente, mas você pode verificar:
kubectl get job -n peerdb peerdb-setup-mirror

# Ou executar manualmente:
make setup-cdc

# Ou usando o script:
./scripts/setup-peerdb-mirror.sh
```

**O que é configurado automaticamente:**
- ✅ PostgreSQL Peer (source): `postgres-source`
- ✅ ClickHouse Peer (destination): `clickhouse-destination`
- ✅ CDC Mirror: `pg-to-ch-mirror`
- ✅ Tabelas: `users`, `orders`, `events`
- ✅ Initial snapshot + real-time CDC

### 📋 Verificar Configuração Automática

```bash
# 1. Verificar status do Job
kubectl logs -n peerdb job/peerdb-setup-mirror

# 2. Acessar PeerDB UI para ver mirrors
kubectl port-forward -n peerdb svc/peerdb 3000:3000
# http://localhost:3000
```

### 🔧 Configuração Manual (Opcional)

Se preferir configurar manualmente via UI:

#### 1. Acessar PeerDB UI

```bash
kubectl port-forward -n peerdb svc/peerdb 3000:3000
```

Acesse: **http://localhost:3000**

#### 2. Obter Credenciais

```bash
# PostgreSQL (CloudNativePG) - Source
PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)
echo "PostgreSQL Password: $PGPASSWORD"

# ClickHouse - Destination
# User: admin
# Pass: admin123
```

#### 3. Criar PostgreSQL Peer (Source)

Na UI do PeerDB:

1. Clique em **"Peers"** → **"New Peer"**
2. Selecione **"PostgreSQL"**
3. Preencha:
   - **Name**: `postgres-source`
   - **Host**: `postgres-cluster-rw.cloudnative-pg.svc.cluster.local`
   - **Port**: `5432`
   - **Database**: `app_db`
   - **User**: `app_user`
   - **Password**: `[senha obtida acima]`
4. Clique em **"Validate"** → **"Create"**

#### 4. Criar ClickHouse Peer (Destination)

1. Clique em **"Peers"** → **"New Peer"**
2. Selecione **"ClickHouse"**
3. Preencha:
   - **Name**: `clickhouse-destination`
   - **Host**: `chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local`
   - **Port**: `9000`
   - **Database**: `default`
   - **User**: `admin`
   - **Password**: `admin123`
4. Clique em **"Validate"** → **"Create"**

#### 5. Criar Mirror (CDC Stream)

1. Clique em **"Mirrors"** → **"New Mirror"**
2. Preencha:
   - **Name**: `pg-to-ch-mirror`
   - **Source Peer**: `postgres-source`
   - **Destination Peer**: `clickhouse-destination`
   - **Mode**: `CDC`
3. Selecione tabelas:
   - ☑ `users`
   - ☑ `orders`
   - ☑ `events`
4. Clique em **"Create Mirror"**

---

### ✅ Verificar Replicação

#### 1. Verificar Dummy Data

```bash
# PostgreSQL
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432 &

PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM users;"
# Esperado: 4

PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM orders;"
# Esperado: 5

PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM events;"
# Esperado: 4
```

#### 2. Verificar Replicação no ClickHouse

Aguardar 1-2 minutos para sincronização inicial:

```bash
# ClickHouse
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000 &

clickhouse-client --host localhost --port 9000 --user admin --password admin123 \
  --query "SELECT COUNT(*) FROM users;"
# Esperado: 4

clickhouse-client --host localhost --port 9000 --user admin --password admin123 \
  --query "SELECT COUNT(*) FROM orders;"
# Esperado: 5

clickhouse-client --host localhost --port 9000 --user admin --password admin123 \
  --query "SELECT COUNT(*) FROM events;"
# Esperado: 4
```

#### 3. Testar CDC em Tempo Real

```bash
# Inserir novo registro no PostgreSQL
PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c \
  "INSERT INTO users (username, email) VALUES ('realtime_test', 'realtime@example.com');"

# Aguardar 10-30 segundos

# Verificar no ClickHouse
clickhouse-client --host localhost --port 9000 --user admin --password admin123 \
  --query "SELECT * FROM users WHERE username='realtime_test';"
# Deve aparecer! ✅
```

---

## Monitoramento (Prometheus & Grafana)

### Acessar Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80
```

Acesse: **http://localhost:3001**

**Credenciais:**
- **User**: `admin`
- **Password**: `admin123`

### Dashboards Disponíveis

#### Kubernetes (Pasta: Default)

1. **Kubernetes Cluster** (ID: 7249) - Visão geral do cluster
2. **Node Exporter Full** (ID: 1860) - Métricas dos nodes
3. **Kubernetes Pods** (ID: 6417) - Status dos pods
4. **Kubernetes Deployments** (ID: 8588) - Deployments
5. **ArgoCD** (ID: 14584) - Status do ArgoCD

#### ClickHouse (Pasta: ClickHouse)

1. **ClickHouse Overview** (ID: 882) - Queries, inserts, latência

#### PostgreSQL (Pasta: PostgreSQL)

1. **PostgreSQL Database** (ID: 9628) - TPS, conexões, locks, replication lag

#### PeerDB (Pasta: PeerDB)

1. **PeerDB Overview** (Custom) - CPU/memória dos workers, requests
2. **CDC Replication Metrics** (Custom) - Replication lag, mirror throughput, WAL

#### Temporal (Pasta: Temporal)

1. **Temporal Workflows** (Custom) - Workflows ativos, execution rate, failures

### Acessar Prometheus

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Acesse: **http://localhost:9090**

### Queries Prometheus Úteis

```promql
# CPU de todos os pods
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# PostgreSQL replication lag
pg_replication_lag_seconds

# ClickHouse queries/sec
rate(ClickHouseProfileEvents_Query[5m])

# PeerDB flow workers CPU
rate(container_cpu_usage_seconds_total{namespace="peerdb", pod=~"peerdb-flow-worker-.*"}[5m])

# Temporal workflows ativos
temporal_workflow_running_total
```

### Acessar Alertmanager

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

Acesse: **http://localhost:9093**

---

## Testes

### Teste Automatizado E2E

```bash
./test-e2e.sh
```

Este script verifica:
- ✅ 10 ArgoCD Applications (Synced)
- ✅ PostgreSQL (3 pods + dummy data)
- ✅ ClickHouse (4 pods + 3 keepers)
- ✅ PeerDB (3 pods)
- ✅ Temporal (4+ pods)
- ✅ Monitoring (Prometheus, Grafana, Alertmanager)
- ✅ 9 HPAs configurados
- ✅ Node affinity (pods nos workers corretos)
- ✅ Metrics Server

### Testes Manuais

#### 1. Testar PostgreSQL (Dummy Data)

```bash
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432 &

export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)

psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM users;"   # Esperado: 4
psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM orders;"  # Esperado: 5
psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM events;"  # Esperado: 4
```

#### 2. Testar ClickHouse (Cluster)

```bash
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000 &

clickhouse-client --host localhost --port 9000 --user admin --password admin123

# Verificar cluster
SELECT * FROM system.clusters WHERE cluster = 'clickhouse-cluster';
-- Esperado: 4 linhas (2 shards × 2 replicas)

# Verificar keeper
SELECT * FROM system.zookeeper WHERE path = '/';
-- Esperado: múltiplas entradas
```

#### 3. Testar Temporal (UI)

```bash
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080
```

Acesse: **http://localhost:8088**

#### 4. Testar CDC (Replicação em Tempo Real)

```bash
# PostgreSQL: Inserir dado
PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c \
  "INSERT INTO users (username, email) VALUES ('cdc_test', 'cdc@example.com');"

# Aguardar 30 segundos

# ClickHouse: Verificar replicação
clickhouse-client --host localhost --port 9000 --user admin --password admin123 \
  --query "SELECT * FROM users WHERE username='cdc_test';"
# Deve aparecer! ✅
```

#### 5. Testar HPAs (Auto-scaling)

```bash
# Ver status dos HPAs
kubectl get hpa --all-namespaces

# Gerar carga (inserir muitos dados)
PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c \
  "INSERT INTO users (username, email) SELECT 'user_' || generate_series(1, 100000), 'email_' || generate_series(1, 100000);"

# Monitorar scaling
watch kubectl get hpa peerdb-flow-worker-hpa -n peerdb
# Você deve ver REPLICAS aumentando: 2 → 3 → 4...
```

---

## Comandos Úteis

### Status e Monitoramento

```bash
# Status geral
kubectl get applications -n argocd
kubectl get pods --all-namespaces
kubectl get hpa --all-namespaces

# Ou usar Makefile
make status
```

### Port Forwards

```bash
# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443
# https://localhost:8080

# PeerDB
kubectl port-forward -n peerdb svc/peerdb 3000:3000
# http://localhost:3000

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80
# http://localhost:3001

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090

# ClickHouse
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000 8123:8123
# Native: localhost:9000, HTTP: localhost:8123

# PostgreSQL
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432
# localhost:5432

# Temporal UI
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080
# http://localhost:8088

# Ou usar Makefile
make port-forward-argocd
make port-forward-peerdb
make port-forward-grafana
```

### Logs

```bash
# ClickHouse
kubectl logs -n clickhouse -l app=clickhouse --tail=100

# PostgreSQL
kubectl logs -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster --tail=100

# PeerDB
kubectl logs -n peerdb -l app=peerdb --tail=100
kubectl logs -n peerdb deployment/peerdb-flow-worker --tail=100

# Temporal
kubectl logs -n peerdb -l app.kubernetes.io/name=temporal --tail=100

# Prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100

# Ou usar Makefile
make logs-clickhouse
make logs-postgres
make logs-peerdb
make logs-temporal
```

### Credenciais

```bash
# ArgoCD
echo "User: admin"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo

# PostgreSQL (CloudNativePG)
echo "User: app_user"
echo "Database: app_db"
echo "Host: postgres-cluster-rw.cloudnative-pg.svc.cluster.local"
echo "Port: 5432"
kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d
echo

# ClickHouse
echo "User: admin"
echo "Password: admin123"
echo "Host: chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local"
echo "Port: 9000 (Native), 8123 (HTTP)"

# Grafana
echo "User: admin"
echo "Password: admin123"
```

### Modificar Configurações

```bash
# Aumentar shards do ClickHouse
# Editar: helm-values/clickhouse-cluster.yaml
# layout.shardsCount: 4
git add helm-values/clickhouse-cluster.yaml
git commit -m "Increase ClickHouse shards to 4"
git push
# ArgoCD sincroniza automaticamente

# Aumentar instâncias do PostgreSQL
# Editar: helm-values/postgres-cluster.yaml
# instances: 5
git add helm-values/postgres-cluster.yaml
git commit -m "Increase PostgreSQL instances to 5"
git push

# Escalar PeerDB workers (manual - não GitOps)
kubectl scale deployment -n peerdb peerdb-flow-worker --replicas=5
```

---

## Troubleshooting

### Application não sincroniza

```bash
# Ver detalhes
kubectl describe application <name> -n argocd

# Ver diff
kubectl get application <name> -n argocd -o yaml

# Forçar sync
kubectl patch application <name> -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Sync via ArgoCD CLI
argocd app sync <name>
```

### Pods não sobem

```bash
# Ver eventos
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Logs do pod
kubectl logs -n <namespace> <pod-name>

# Descrever pod
kubectl describe pod -n <namespace> <pod-name>

# Ver status do pod
kubectl get pod -n <namespace> <pod-name> -o yaml
```

### CDC não funciona

```bash
# 1. Verificar wal_level no PostgreSQL
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SHOW wal_level;"
# Deve ser: logical

# 2. Verificar max_wal_senders
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SHOW max_wal_senders;"
# Deve ser: 10

# 3. Verificar publication
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SELECT * FROM pg_publication;"

# 4. Verificar replication slot
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SELECT * FROM pg_replication_slots;"

# 5. Verificar REPLICA IDENTITY
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SELECT relname, relreplident FROM pg_class WHERE relname IN ('users', 'orders', 'events');"
# Deve ser: f (FULL)

# 6. Logs do PeerDB
kubectl logs -n peerdb deployment/peerdb-flow-worker --tail=100

# 7. Verificar Temporal workflows
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080
# Acesse: http://localhost:8088
```

### HPAs não escalam

```bash
# 1. Verificar metrics-server
kubectl get deployment metrics-server -n kube-system
kubectl logs -n kube-system deployment/metrics-server

# 2. Verificar métricas
kubectl top nodes
kubectl top pods -n peerdb

# 3. Ver eventos do HPA
kubectl describe hpa peerdb-flow-worker-hpa -n peerdb

# 4. Verificar target metrics
kubectl get hpa peerdb-flow-worker-hpa -n peerdb -o yaml
```

### Pods não vão para workers corretos (Node Affinity)

```bash
# 1. Verificar labels dos nodes
kubectl get nodes --show-labels | grep workload

# 2. Verificar taints
kubectl describe node worker-1 | grep Taints

# 3. Ver eventos do pod
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events

# 4. Forçar reschedule
kubectl rollout restart statefulset -n cloudnative-pg postgres-cluster
kubectl rollout restart deployment -n peerdb peerdb-flow-worker
```

### Grafana não carrega dashboards

```bash
# 1. Verificar sidecar
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana -c grafana-sc-dashboard

# 2. Verificar ConfigMaps
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# 3. Recarregar Grafana
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

# 4. Verificar datasource
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s http://localhost:3000/api/datasources
```

### Prometheus não coleta métricas

```bash
# 1. Verificar targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Acesse: http://localhost:9090/targets

# 2. Verificar ServiceMonitors
kubectl get servicemonitors --all-namespaces

# 3. Ver logs do Prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100

# 4. Verificar configuração
kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus -o yaml
```

### Verificar Status Completo

```bash
# 1. ArgoCD Applications
kubectl get applications -n argocd
# Esperado: 10 applications, SYNC STATUS = Synced, HEALTH = Healthy

# 2. Pods
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
# Esperado: vazio (todos Running)

# 3. PVCs
kubectl get pvc --all-namespaces
# Esperado: Bound

# 4. Services
kubectl get svc --all-namespaces

# 5. HPAs
kubectl get hpa --all-namespaces
# Esperado: 9 HPAs

# 6. ServiceMonitors
kubectl get servicemonitors --all-namespaces
# Esperado: 4 ServiceMonitors
```

---

## Limpeza

### Remover Componentes

```bash
# Remover Applications (ArgoCD vai deletar os recursos)
kubectl delete -f apps/

# Aguardar finalização
kubectl get applications -n argocd -w

# Remover namespaces manualmente (se necessário)
kubectl delete namespace clickhouse cloudnative-pg peerdb monitoring

# Remover ArgoCD
kubectl delete namespace argocd

# Ou usar Makefile
make clean
```

### Remover Node Labels e Taints

```bash
# Remover labels
kubectl label node worker-1 workload-
kubectl label node worker-2 workload-
kubectl label node worker-3 workload-
kubectl label node worker-4 workload-
kubectl label node worker-5 workload-

# Remover taints
kubectl taint node worker-1 workload-
kubectl taint node worker-2 workload-
kubectl taint node worker-3 workload-
kubectl taint node worker-4 workload-
kubectl taint node worker-5 workload-
```

---

## Recursos Adicionais

### Documentação Oficial

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ClickHouse Operator](https://github.com/Altinity/clickhouse-operator)
- [CloudNativePG](https://cloudnative-pg.io/)
- [PeerDB Documentation](https://docs.peerdb.io/)
- [Temporal Documentation](https://docs.temporal.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

### Grafana Dashboards

- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [ClickHouse Dashboards](https://grafana.com/grafana/dashboards/?search=clickhouse)
- [PostgreSQL Dashboards](https://grafana.com/grafana/dashboards/?search=postgresql)

### Helm Charts

- [Prometheus Community Charts](https://github.com/prometheus-community/helm-charts)
- [Altinity ClickHouse Operator](https://github.com/Altinity/clickhouse-operator)
- [CloudNativePG Helm Chart](https://github.com/cloudnative-pg/charts)
- [Bitnami PostgreSQL](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Temporal Helm Chart](https://github.com/temporalio/helm-charts)

---

## Licença

MIT

---

## Contribuições

Contribuições são bem-vindas! Por favor, abra uma issue ou PR.

---

## Suporte

Para problemas ou dúvidas:
1. Verifique a seção [Troubleshooting](#troubleshooting)
2. Execute `./test-e2e.sh` para diagnóstico automático
3. Verifique logs dos componentes
4. Abra uma issue no GitHub

---

**Última atualização**: 2025-10-27
**Versão**: 2.0.0
