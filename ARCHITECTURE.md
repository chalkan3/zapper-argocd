# Arquitetura do Sistema

## Visão Geral

Este sistema implementa uma pipeline de dados moderna baseada em CDC (Change Data Capture) usando GitOps para gerenciamento de infraestrutura.

```
┌─────────────────────────────────────────────────────────────────┐
│                         ArgoCD (GitOps)                         │
│                    Gerencia todo o cluster                      │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ├─────────────────────────────────┐
                                 │                                 │
                                 ▼                                 ▼
┌──────────────────────────────────────┐     ┌──────────────────────────────┐
│       CloudNativePG Operator          │     │   ClickHouse Operator        │
│                                      │     │                              │
│  ┌────────────────────────────────┐ │     │  ┌────────────────────────┐ │
│  │   PostgreSQL Cluster           │ │     │  │  ClickHouse Cluster    │ │
│  │   - 3 réplicas                 │ │     │  │  - 2+ shards           │ │
│  │   - Logical replication        │ │     │  │  - 2 réplicas/shard    │ │
│  │   - Dummy data (users, orders) │ │     │  │  - Keeper (Zookeeper)  │ │
│  └────────────────────────────────┘ │     │  └────────────────────────┘ │
└──────────────────────────────────────┘     └──────────────────────────────┘
                 │                                         ▲
                 │                                         │
                 │                                         │
                 ▼                                         │
┌──────────────────────────────────────────────────────────────────┐
│                           PeerDB                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      PeerDB Server                          │ │
│  │                   - UI (port 3000)                          │ │
│  │                   - API (port 8080)                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Flow Workers (2+ pods)                    │ │
│  │              - Processam CDC streams                        │ │
│  │              - Transformações de dados                      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Dependencies:                                                   │
│  ┌──────────────────────┐    ┌──────────────────────────────┐  │
│  │   PostgreSQL         │    │   Temporal                    │  │
│  │   (Metadata)         │    │   (Workflow Engine)           │  │
│  └──────────────────────┘    └──────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Componentes

### 1. ArgoCD (Namespace: argocd)

**Função**: Continuous Deployment via GitOps

- Monitora repositório Git
- Sincroniza automaticamente mudanças
- Self-healing de aplicações
- Rollback automático em caso de falha

**Configuração**:
- Sync automático habilitado
- Prune automático de recursos órfãos
- Retry automático com backoff exponencial

### 2. ClickHouse Cluster (Namespace: clickhouse)

**Função**: Database analítico OLAP para dados replicados

**Componentes**:
- **ClickHouse Operator**: Gerencia lifecycle do cluster
- **ClickHouse Keeper**: Sistema de coordenação distribuída (substituto do Zookeeper)
  - 3 instâncias para quorum
  - Coordena replicação entre shards
- **ClickHouse Cluster**:
  - 2+ shards (distribuição horizontal)
  - 2 réplicas por shard (alta disponibilidade)
  - Total: 4+ pods de ClickHouse

**Storage**:
- Data volume: 10Gi por instância
- Log volume: 5Gi por instância
- Keeper data: 5Gi por instância

**Portas**:
- 8123: HTTP interface
- 9000: Native protocol (TCP)

**Autenticação**:
- Usuário: admin
- Senha: admin123

### 3. CloudNativePG (Namespace: cloudnative-pg)

**Função**: PostgreSQL operacional com dados de origem

**Componentes**:
- **CloudNativePG Operator**: Gerencia PostgreSQL clusters
- **PostgreSQL Cluster**:
  - 3 instâncias (1 primary + 2 replicas)
  - Logical replication habilitado (wal_level=logical)
  - Automatic failover

**Configuração para CDC**:
```sql
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
```

**Storage**:
- 10Gi por instância

**Dados de Teste**:
- Tabela `users`: 4 registros
- Tabela `orders`: 5 registros
- Tabela `events`: 4 registros

**Autenticação**:
- Usuário: app_user
- Senha: armazenada em secret `postgres-cluster-app`
- Database: app_db

### 4. PeerDB (Namespace: peerdb)

**Função**: Motor de CDC (Change Data Capture)

**Componentes**:

#### PeerDB Server
- UI web para configuração
- API REST/gRPC
- Gerenciamento de peers e mirrors

#### Flow Workers
- 2+ pods para processamento paralelo
- Consomem mudanças do PostgreSQL via logical replication
- Transformam e carregam dados no ClickHouse
- Escaláveis horizontalmente

#### Dependências

**PostgreSQL (Metadata)**:
- Armazena metadados do PeerDB
- Configuração de peers
- Estado dos mirrors
- Usuário: peerdb / peerdb123
- Database: peerdb_metadata

**Temporal**:
- Workflow engine
- Orquestra jobs de CDC
- Retry automático
- Durabilidade de workflows
- Databases: temporal, temporal_visibility

**Portas**:
- 3000: PeerDB UI/API
- 8080: PeerDB gRPC

## Fluxo de Dados

### 1. Mudanças no PostgreSQL

```
┌─────────────────────┐
│   Application       │
│   (INSERT/UPDATE/   │
│    DELETE)          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  PostgreSQL         │
│  - WAL logging      │
│  - Logical decoding │
└──────────┬──────────┘
```

### 2. Captura via PeerDB

```
┌─────────────────────┐
│  PeerDB             │
│  - Publication      │
│  - Replication Slot │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Flow Worker        │
│  - Lê mudanças      │
│  - Transforma       │
│  - Batching         │
└──────────┬──────────┘
```

### 3. Escrita no ClickHouse

```
┌─────────────────────┐
│  ClickHouse         │
│  - Inserts batched  │
│  - Distributed      │
│  - Replicated       │
└─────────────────────┘
```

## Estratégias de Deploy

### Ordem de Deploy (gerenciada pelo ArgoCD)

1. **ClickHouse** (mais independente)
   - Operator
   - Keeper
   - Cluster

2. **CloudNativePG** (independente)
   - Operator
   - Cluster com dados

3. **PeerDB Dependencies** (depende de nada)
   - PostgreSQL
   - Temporal

4. **PeerDB** (depende de dependencies)
   - Server
   - Flow Workers

### Sync Policies

Todas as apps usam:
- **Automated sync**: Mudanças no Git são aplicadas automaticamente
- **Prune**: Recursos removidos do Git são deletados do cluster
- **Self-heal**: Mudanças manuais são revertidas
- **Retry**: Falhas são retentadas com backoff exponencial

## Rede e Conectividade

### DNS Interno

Serviços se comunicam via DNS do Kubernetes:

```
# PostgreSQL (CloudNativePG)
postgres-cluster-rw.cloudnative-pg.svc.cluster.local:5432

# ClickHouse
clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local:9000
clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local:8123

# PeerDB Dependencies
peerdb-dependencies-postgresql.peerdb.svc.cluster.local:5432
peerdb-dependencies-temporal-frontend.peerdb.svc.cluster.local:7233

# Keeper
clickhouse-keeper-0.clickhouse-keeper-headless.clickhouse.svc.cluster.local:9181
clickhouse-keeper-1.clickhouse-keeper-headless.clickhouse.svc.cluster.local:9181
clickhouse-keeper-2.clickhouse-keeper-headless.clickhouse.svc.cluster.local:9181
```

### Portas Externas (via Port-Forward)

```
kubectl port-forward -n argocd svc/argocd-server 8080:443
kubectl port-forward -n peerdb svc/peerdb 3000:3000
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-cluster-0-0 8123:8123 9000:9000
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432
```

## Escalabilidade

### Vertical (Recursos)

Ajuste em `values.yaml`:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

### Horizontal (Réplicas)

**ClickHouse**:
```yaml
layout:
  shardsCount: 4  # mais shards
  replicasCount: 3  # mais réplicas
```

**PeerDB Flow Workers**:
```bash
kubectl scale deployment -n peerdb peerdb-flow-worker --replicas=4
```

**CloudNativePG**:
```yaml
instances: 5  # mais réplicas
```

## Monitoramento

### Health Checks

```bash
# Status de todas as apps
kubectl get applications -n argocd

# Pods por namespace
kubectl get pods -n clickhouse
kubectl get pods -n cloudnative-pg
kubectl get pods -n peerdb
```

### Logs

```bash
# ClickHouse
kubectl logs -n clickhouse -l app=clickhouse --tail=100 -f

# PostgreSQL
kubectl logs -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster --tail=100 -f

# PeerDB
kubectl logs -n peerdb -l app=peerdb --tail=100 -f

# Temporal
kubectl logs -n peerdb -l app.kubernetes.io/name=temporal --tail=100 -f
```

### Métricas de CDC

- **Lag**: Tempo entre mudança no PG e replicação no CH
- **Throughput**: Rows por segundo
- **Errors**: Taxa de erro
- **Slot size**: Tamanho do replication slot (WAL acumulado)

## Disaster Recovery

### Backup

**CloudNativePG**:
- Backups automáticos configurados
- WAL archiving
- Point-in-time recovery

**ClickHouse**:
- Snapshots de volumes
- Replicação entre shards

### Restore

```bash
# PostgreSQL
kubectl cnpg backup postgres-cluster -n cloudnative-pg

# ClickHouse
# Usar ferramenta nativa clickhouse-backup
```

## Segurança

### Network Policies

Considere adicionar:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-peerdb-to-databases
spec:
  # Permitir apenas PeerDB acessar databases
```

### Secrets Management

Atualmente usando secrets do Kubernetes. Para produção, considere:
- Sealed Secrets
- External Secrets Operator
- Vault

### RBAC

ArgoCD usa service accounts com permissões adequadas para cada namespace.

## Troubleshooting

Ver seção detalhada no README.md e PEERDB_SETUP.md
