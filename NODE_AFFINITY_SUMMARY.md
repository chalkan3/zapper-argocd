# 🎯 Node Affinity & HPA - Resumo Executivo

## ✅ Configuração Completa

Todo o repositório foi configurado para:
1. **Node Affinity**: Pods deployados em workers específicos
2. **HPA**: Auto-scaling baseado em CPU e memória

---

## 📊 Distribuição de Workers (5 nodes)

```
Worker 1-2  → PostgreSQL      (label: workload=postgres)
Worker 3    → ClickHouse      (label: workload=clickhouse)
Worker 4-5  → PeerDB          (label: workload=peerdb)
```

### Tabela de Distribuição

| Workers | Label | Pods | Componentes |
|---------|-------|------|-------------|
| 1-2 | `postgres` | 3 | CloudNativePG (1 primary + 2 standby) |
| 3 | `clickhouse` | 7 | ClickHouse (4 pods) + Keeper (3 pods) |
| 4-5 | `peerdb` | 8+ | PeerDB + PostgreSQL + Temporal |

**Total**: ~18+ pods distribuídos em 5 workers

---

## 🚀 Quick Start

### 1. Adicionar Labels aos Workers

```bash
# PostgreSQL workers
kubectl label node worker-1 workload=postgres
kubectl label node worker-2 workload=postgres

# ClickHouse worker
kubectl label node worker-3 workload=clickhouse

# PeerDB workers
kubectl label node worker-4 workload=peerdb
kubectl label node worker-5 workload=peerdb
```

### 2. Adicionar Taints (Opcional)

```bash
kubectl taint node worker-1 workload=postgres:NoSchedule
kubectl taint node worker-2 workload=postgres:NoSchedule
kubectl taint node worker-3 workload=clickhouse:NoSchedule
kubectl taint node worker-4 workload=peerdb:NoSchedule
kubectl taint node worker-5 workload=peerdb:NoSchedule
```

### 3. Deploy

```bash
kubectl apply -f apps/
```

### 4. Verificar

```bash
# Ver distribuição de pods
kubectl get pods -o wide --all-namespaces | grep -E "clickhouse|postgres|peerdb"

# Ver HPAs
kubectl get hpa --all-namespaces
```

---

## 📈 HPAs Configurados (9 HPAs)

| HPA | Min | Max | CPU | Memory |
|-----|-----|-----|-----|--------|
| PeerDB Server | 1 | 5 | 70% | 80% |
| PeerDB Flow Workers | 2 | 10 | 75% | 80% |
| CloudNativePG | 3 | 5 | 70% | 80% |
| PeerDB PostgreSQL | 1 | 3 | 75% | 80% |
| ClickHouse | 4 | 8 | 70% | 75% |
| Temporal Frontend | 1 | 5 | 70% | 80% |
| Temporal History | 1 | 5 | 70% | 80% |
| Temporal Matching | 1 | 5 | 70% | 80% |
| Temporal Worker | 1 | 10 | 75% | 80% |

---

## 📁 Arquivos Modificados

### Node Affinity Adicionado

✅ `helm-values/postgres-cluster.yaml` - CloudNativePG
✅ `helm-values/clickhouse-cluster.yaml` - ClickHouse + Keeper
✅ `manifests/peerdb/deployment.yaml` - PeerDB Server + Workers
✅ `apps/peerdb-dependencies.yaml` - PostgreSQL + Temporal

### HPAs Criados

✅ `manifests/hpa/peerdb-hpa.yaml`
✅ `manifests/hpa/postgres-hpa.yaml`
✅ `manifests/hpa/clickhouse-hpa.yaml`
✅ `manifests/hpa/temporal-hpa.yaml`

### Application Adicionada

✅ `apps/hpa.yaml` - ArgoCD Application para HPAs

---

## 🔧 Pré-requisitos

### Metrics Server

HPAs requerem o Metrics Server:

```bash
# Verificar
kubectl get deployment metrics-server -n kube-system

# Instalar (se necessário)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Nota**: K3s já inclui metrics-server por padrão.

---

## 📊 Exemplo de Distribuição Final

```
worker-1 (postgres):
  ├── postgres-cluster-1 (primary)
  └── postgres-cluster-3 (standby)

worker-2 (postgres):
  └── postgres-cluster-2 (standby)

worker-3 (clickhouse):
  ├── clickhouse-0-0-0 (shard 1, replica 1)
  ├── clickhouse-0-1-0 (shard 1, replica 2)
  ├── clickhouse-1-0-0 (shard 2, replica 1)
  ├── clickhouse-1-1-0 (shard 2, replica 2)
  ├── clickhouse-keeper-0
  ├── clickhouse-keeper-1
  └── clickhouse-keeper-2

worker-4 (peerdb):
  ├── peerdb-server-xxx
  ├── peerdb-postgresql-0
  ├── peerdb-temporal-frontend-xxx
  └── peerdb-temporal-history-xxx

worker-5 (peerdb):
  ├── peerdb-flow-worker-xxx-1
  ├── peerdb-flow-worker-xxx-2
  ├── peerdb-temporal-matching-xxx
  └── peerdb-temporal-worker-xxx
```

---

## 🎯 Total de Applications

Agora são **8 Applications** (era 7):

1. clickhouse-operator
2. clickhouse-cluster
3. cloudnative-pg-operator
4. postgres-cluster
5. peerdb-postgresql
6. peerdb-temporal
7. peerdb
8. **hpa** ← NOVO

---

## 📚 Documentação Completa

→ **NODE_AFFINITY_SETUP.md** - Guia completo com troubleshooting

---

## ✅ Checklist Rápido

- [ ] Aplicar labels nos 5 workers
- [ ] (Opcional) Aplicar taints nos workers
- [ ] Deploy: `kubectl apply -f apps/`
- [ ] Verificar distribuição: `kubectl get pods -o wide --all-namespaces`
- [ ] Verificar HPAs: `kubectl get hpa --all-namespaces`
- [ ] Monitorar: `kubectl top pods -n peerdb`

---

**Status**: ✅ **COMPLETO** - Node Affinity + HPA configurados
