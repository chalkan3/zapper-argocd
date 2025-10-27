# 🏷️ Node Affinity & HPA Setup Guide

## Visão Geral

Este repositório configura **node affinity** para garantir que os pods sejam deployados em workers específicos e **HPA (Horizontal Pod Autoscaler)** para auto-scaling.

---

## 📊 Distribuição de Workers

### Arquitetura de 5 Workers

```
┌─────────────────────────────────────────────────────────┐
│                    Control Plane                        │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Worker 1     │   │ Worker 2     │   │ Worker 3     │
│ postgres     │   │ postgres     │   │ clickhouse   │
│              │   │              │   │              │
│ - CNPG (3x)  │   │ - CNPG (3x)  │   │ - CH Shard1  │
└──────────────┘   └──────────────┘   │ - CH Shard2  │
                                       │ - CH Keeper  │
                                       └──────────────┘
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐
│ Worker 4     │   │ Worker 5     │
│ peerdb       │   │ peerdb       │
│              │   │              │
│ - PeerDB     │   │ - PeerDB     │
│ - Postgres   │   │ - Flow Work  │
│ - Temporal   │   │ - Temporal   │
└──────────────┘   └──────────────┘
```

### Distribuição de Pods

| Worker Node(s) | Label | Componentes | Pods Estimados |
|----------------|-------|-------------|----------------|
| Worker 1-2 | `workload=postgres` | CloudNativePG | 3 (1 primary + 2 standby) |
| Worker 3 | `workload=clickhouse` | ClickHouse Cluster + Keeper | 7 (4 CH + 3 Keeper) |
| Worker 4-5 | `workload=peerdb` | PeerDB + PostgreSQL + Temporal | 8+ (1 server + 2 workers + 1 pg + 4 temporal) |

---

## 🔧 Passo 1: Preparar os Worker Nodes

### 1.1 Listar Workers

```bash
kubectl get nodes --selector='!node-role.kubernetes.io/control-plane'
```

Output esperado:
```
NAME       STATUS   ROLE    AGE   VERSION
worker-1   Ready    <none>  1d    v1.28.0
worker-2   Ready    <none>  1d    v1.28.0
worker-3   Ready    <none>  1d    v1.28.0
worker-4   Ready    <none>  1d    v1.28.0
worker-5   Ready    <none>  1d    v1.28.0
```

### 1.2 Adicionar Labels aos Workers

#### PostgreSQL Workers (2 nodes)

```bash
kubectl label node worker-1 workload=postgres
kubectl label node worker-2 workload=postgres
```

#### ClickHouse Worker (1 node)

```bash
kubectl label node worker-3 workload=clickhouse
```

#### PeerDB Workers (2 nodes)

```bash
kubectl label node worker-4 workload=peerdb
kubectl label node worker-5 workload=peerdb
```

### 1.3 Adicionar Taints (Opcional mas Recomendado)

Taints garantem que **APENAS** os pods designados sejam deployados nos workers:

```bash
# PostgreSQL nodes
kubectl taint node worker-1 workload=postgres:NoSchedule
kubectl taint node worker-2 workload=postgres:NoSchedule

# ClickHouse node
kubectl taint node worker-3 workload=clickhouse:NoSchedule

# PeerDB nodes
kubectl taint node worker-4 workload=peerdb:NoSchedule
kubectl taint node worker-5 workload=peerdb:NoSchedule
```

### 1.4 Verificar Labels e Taints

```bash
# Ver labels
kubectl get nodes --show-labels | grep workload

# Ver taints
kubectl describe nodes | grep -A5 Taints
```

---

## 📋 Passo 2: Node Affinity Configurado

Todos os componentes já estão configurados com node affinity:

### PostgreSQL (CloudNativePG)

**Arquivo:** `helm-values/postgres-cluster.yaml:13-28`

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values:
                - postgres

tolerations:
  - key: workload
    operator: Equal
    value: postgres
    effect: NoSchedule
```

**Resultado:** Pods serão deployados **APENAS** em worker-1 e worker-2

### ClickHouse Cluster + Keeper

**Arquivo:** `helm-values/clickhouse-cluster.yaml:49-75`

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values:
                - clickhouse

tolerations:
  - key: workload
    operator: Equal
    value: clickhouse
    effect: NoSchedule
```

**Resultado:** Todos os pods ClickHouse (cluster + keeper) serão deployados **APENAS** em worker-3

### PeerDB + Dependencies

**Arquivos:**
- `manifests/peerdb/deployment.yaml:21-37` (PeerDB Server)
- `manifests/peerdb/deployment.yaml:103-119` (Flow Workers)
- `apps/peerdb-dependencies.yaml:29-45` (PostgreSQL)
- `apps/peerdb-dependencies.yaml:103-119` (Temporal)

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values:
                - peerdb

tolerations:
  - key: workload
    operator: Equal
    value: peerdb
    effect: NoSchedule
```

**Resultado:** Todos os pods PeerDB serão deployados **APENAS** em worker-4 e worker-5

---

## 📈 Passo 3: HPA (Horizontal Pod Autoscaler)

### 3.1 Pré-requisitos

O Metrics Server deve estar instalado no cluster:

```bash
# Verificar se está instalado
kubectl get deployment metrics-server -n kube-system

# Se não estiver, instalar
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Para K3s, o metrics-server já vem instalado por padrão.

### 3.2 HPAs Configurados

| Componente | Namespace | Min Replicas | Max Replicas | CPU Target | Memory Target |
|------------|-----------|--------------|--------------|------------|---------------|
| **PeerDB Server** | peerdb | 1 | 5 | 70% | 80% |
| **PeerDB Flow Workers** | peerdb | 2 | 10 | 75% | 80% |
| **CloudNativePG** | cloudnative-pg | 3 | 5 | 70% | 80% |
| **PeerDB PostgreSQL** | peerdb | 1 | 3 | 75% | 80% |
| **ClickHouse Cluster** | clickhouse | 4 | 8 | 70% | 75% |
| **Temporal Frontend** | peerdb | 1 | 5 | 70% | 80% |
| **Temporal History** | peerdb | 1 | 5 | 70% | 80% |
| **Temporal Matching** | peerdb | 1 | 5 | 70% | 80% |
| **Temporal Worker** | peerdb | 1 | 10 | 75% | 80% |

### 3.3 Arquivos HPA

Todos os HPAs estão em `manifests/hpa/`:

- `peerdb-hpa.yaml` - PeerDB Server + Flow Workers
- `postgres-hpa.yaml` - CloudNativePG + PeerDB PostgreSQL
- `clickhouse-hpa.yaml` - ClickHouse Cluster
- `temporal-hpa.yaml` - Temporal components

### 3.4 Comportamento de Scaling

#### Scale Up (Rápido)
- **PeerDB Flow Workers**: Até 100% ou +3 pods a cada 15s
- **Temporal Workers**: Até 100% ou +3 pods a cada 15s
- **Outros**: Até 100% a cada 30-60s

#### Scale Down (Conservador)
- **Databases**: 1 pod a cada 5-10 minutos (cautious)
- **Workers**: 50% a cada 60s
- **Stabilization**: 5-10 minutos antes de scale down

---

## 🚀 Passo 4: Deploy

### 4.1 Aplicar Node Labels

```bash
# Execute os comandos do Passo 1.2
```

### 4.2 Deploy Aplicações

```bash
# Deploy todas as applications (incluindo HPA)
kubectl apply -f apps/
```

### 4.3 Verificar Distribuição de Pods

```bash
# Ver em qual node cada pod está
kubectl get pods -o wide --all-namespaces | grep -E "clickhouse|cloudnative-pg|peerdb"
```

Output esperado:
```
NAMESPACE        NAME                          NODE       STATUS
clickhouse       clickhouse-0-0-0              worker-3   Running
clickhouse       clickhouse-0-1-0              worker-3   Running
clickhouse       clickhouse-keeper-0           worker-3   Running
cloudnative-pg   postgres-cluster-1            worker-1   Running
cloudnative-pg   postgres-cluster-2            worker-2   Running
cloudnative-pg   postgres-cluster-3            worker-1   Running
peerdb           peerdb-server-xxx             worker-4   Running
peerdb           peerdb-flow-worker-xxx        worker-5   Running
peerdb           peerdb-postgresql-0           worker-4   Running
peerdb           peerdb-temporal-frontend-xxx  worker-5   Running
```

### 4.4 Verificar HPAs

```bash
# Ver todos os HPAs
kubectl get hpa --all-namespaces

# Ver detalhes de um HPA
kubectl describe hpa peerdb-flow-worker-hpa -n peerdb
```

Output esperado:
```
NAME                      REFERENCE                        TARGETS         MINPODS   MAXPODS   REPLICAS
peerdb-server-hpa         Deployment/peerdb-server         20%/70%, 30%/80%   1         5         1
peerdb-flow-worker-hpa    Deployment/peerdb-flow-worker    45%/75%, 50%/80%   2         10        2
```

---

## 🔍 Troubleshooting

### Pods não vão para os nodes corretos

```bash
# 1. Verificar labels
kubectl get nodes --show-labels | grep workload

# 2. Ver eventos do pod
kubectl describe pod <pod-name> -n <namespace>

# 3. Ver scheduler events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep FailedScheduling
```

Possíveis causas:
- Labels não aplicados nos nodes
- Typo no label name
- Tolerations não configuradas (se taints foram aplicados)

### HPA não escala

```bash
# 1. Verificar metrics server
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes

# 2. Ver status do HPA
kubectl describe hpa <hpa-name> -n <namespace>

# 3. Ver métricas atuais
kubectl top pods -n <namespace>
```

Possíveis causas:
- Metrics server não instalado
- Resources (requests/limits) não configurados nos pods
- Target muito alto (ex: 95% nunca será atingido)

### ClickHouse não distribui entre shards

```bash
# Verificar distribuição
kubectl exec -n clickhouse clickhouse-0-0-0 -- clickhouse-client --query "SELECT * FROM system.clusters"

# Ver tabelas distribuídas
kubectl exec -n clickhouse clickhouse-0-0-0 -- clickhouse-client --query "SHOW TABLES"
```

Para tabelas serem distribuídas, devem usar `Distributed` engine:
```sql
CREATE TABLE distributed_table ON CLUSTER clickhouse-cluster
ENGINE = Distributed('clickhouse-cluster', 'default', 'local_table', rand())
```

---

## 📊 Monitoramento

### Verificar uso de recursos

```bash
# Por namespace
kubectl top pods -n clickhouse
kubectl top pods -n cloudnative-pg
kubectl top pods -n peerdb

# Por node
kubectl top nodes
```

### Ver distribuição de pods por node

```bash
kubectl get pods -o wide --all-namespaces --sort-by=.spec.nodeName
```

### Logs de scaling

```bash
# HPA events
kubectl get events -n <namespace> | grep HorizontalPodAutoscaler

# Logs do kube-controller-manager
kubectl logs -n kube-system <controller-manager-pod> | grep -i scale
```

---

## 🎯 Testes de Auto-Scaling

### Testar HPA do PeerDB Flow Workers

```bash
# 1. Gerar carga (inserir muitos dados no PostgreSQL)
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432 &

PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c "
  INSERT INTO users (username, email)
  SELECT
    'user_' || generate_series(1, 100000),
    'user_' || generate_series(1, 100000) || '@example.com'
"

# 2. Observar HPA
watch kubectl get hpa peerdb-flow-worker-hpa -n peerdb

# 3. Ver pods sendo criados
watch kubectl get pods -n peerdb -l component=flow-worker
```

---

## ⚙️ Customização

### Alterar limites do HPA

Edite `manifests/hpa/<component>-hpa.yaml`:

```yaml
spec:
  minReplicas: 2      # ← Alterar mínimo
  maxReplicas: 20     # ← Alterar máximo
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 60  # ← Alterar threshold
```

### Mudar node assignment

```bash
# Remover label
kubectl label node worker-X workload-

# Adicionar novo label
kubectl label node worker-X workload=new-value
```

### Desabilitar taints

```bash
kubectl taint node worker-X workload-
```

---

## 📝 Resumo de Comandos

```bash
# === Setup Inicial ===
# Adicionar labels
kubectl label node worker-{1,2} workload=postgres
kubectl label node worker-3 workload=clickhouse
kubectl label node worker-{4,5} workload=peerdb

# Adicionar taints (opcional)
kubectl taint node worker-{1,2} workload=postgres:NoSchedule
kubectl taint node worker-3 workload=clickhouse:NoSchedule
kubectl taint node worker-{4,5} workload=peerdb:NoSchedule

# === Verificação ===
# Ver distribuição
kubectl get pods -o wide --all-namespaces | grep -E "clickhouse|postgres|peerdb"

# Ver HPAs
kubectl get hpa --all-namespaces

# Ver uso de recursos
kubectl top pods -n peerdb
kubectl top nodes

# === Monitoramento ===
# Ver métricas em tempo real
watch kubectl get hpa -n peerdb
watch kubectl top pods -n peerdb
```

---

## 📚 Referências

- [Kubernetes Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Kubernetes Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)

---

**Total de Workers**: 5
**Total de Labels**: 3 (postgres, clickhouse, peerdb)
**Total de HPAs**: 9
