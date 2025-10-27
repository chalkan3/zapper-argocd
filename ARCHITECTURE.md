# Arquitetura e Racional do Projeto

## 📋 Sumário Executivo

Este documento explica as decisões arquiteturais, tecnologias escolhidas e racional por trás da implementação da infraestrutura de dados distribuída com CDC (Change Data Capture) usando GitOps.

---

## 🎯 Objetivos do Projeto

### Requisitos Principais

1. **ClickHouse em Cluster Mode**
   - Configuração com Keeper para coordenação distribuída
   - Distribuição de dados em 2+ nodes via sharding
   - Alta disponibilidade com replicação

2. **PostgreSQL com CloudNativePG**
   - Instância com dados de teste (dummy data)
   - Preparada para replicação via CDC

3. **CDC com PeerDB**
   - ETL em tempo real PostgreSQL → ClickHouse
   - Configuração de peers (sources) e mirrors
   - Garantia de réplica contínua dos dados

4. **Dependências do PeerDB**
   - PostgreSQL para metadata do PeerDB
   - Temporal para orquestração de workflows

5. **GitOps Completo**
   - Infraestrutura como código
   - Versionamento e auditoria
   - Deploy automatizado via ArgoCD

---

## 🏗️ Arquitetura Geral

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                    Git Repository (Source of Truth)             │
│  ├─ apps/                    (ArgoCD Applications)              │
│  ├─ manifests/               (Kubernetes Manifests)             │
│  ├─ helm-values/             (Helm Values)                      │
│  └─ scripts/                 (Automation Scripts)               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ArgoCD                                  │
│  - Sincroniza Git → Kubernetes                                  │
│  - Sync Waves (ordem de deploy)                                 │
│  - Auto-healing e self-healing                                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
┌────────────────┐ ┌────────────┐ ┌──────────────────┐
│  ClickHouse    │ │ PostgreSQL │ │     PeerDB       │
│   Operator     │ │  Operator  │ │   + Temporal     │
└───────┬────────┘ └─────┬──────┘ └─────┬────────────┘
        │                │              │
        ▼                ▼              ▼
┌────────────────┐ ┌────────────┐ ┌──────────────────┐
│ ClickHouse     │ │PostgreSQL  │ │ PeerDB Metadata  │
│ Cluster        │ │ Cluster    │ │ PostgreSQL       │
│                │ │            │ │                  │
│ - 2 Shards     │ │- 3 Replicas│ │ Temporal Server  │
│ - 2 Replicas   │ │- WAL CDC   │ │                  │
│ - 3 Keepers    │ │- Dummy Data│ │ PeerDB Server    │
│                │ │            │ │ + Workers        │
└────────────────┘ └────────────┘ └──────────────────┘
        ▲                │                    │
        │                └────────────────────┘
        │                    CDC Replication
        │                   (PG → ClickHouse)
        │
┌───────┴────────────────────────────────────────────┐
│        Prometheus + Grafana (Monitoring)           │
└────────────────────────────────────────────────────┘
```

---

## 🤔 Decisões Arquiteturais e Racional

### 1. Por que ArgoCD (GitOps)?

**Decisão:** Usar ArgoCD como ferramenta de GitOps.

**Racional:**
- ✅ **Declarativo**: Infraestrutura versionada no Git
- ✅ **Auditável**: Histórico completo de mudanças
- ✅ **Recuperação**: Rollback fácil via Git
- ✅ **Sync Waves**: Controle preciso da ordem de deploy
- ✅ **Self-healing**: Correção automática de drift
- ✅ **UI + CLI**: Interface visual + automação

**Alternativas consideradas:**
- Flux CD: Menos maduro, UI limitada
- Manual kubectl: Não escalável, sem histórico
- Helm direto: Sem GitOps, sem auditoria

---

### 2. Por que ClickHouse Operator?

**Decisão:** Usar Altinity ClickHouse Operator com Keeper.

**Racional:**
- ✅ **Cluster Nativo**: Suporte a sharding e replicação
- ✅ **ClickHouse Keeper**: Substituto do ZooKeeper (mais leve)
- ✅ **Operador Maduro**: Altinity é mantido pela comunidade ClickHouse
- ✅ **CRDs Declarativas**: `ClickHouseInstallation` + `ClickHouseKeeperInstallation`
- ✅ **Auto-scaling**: Suporte a HPAs

**Configuração escolhida:**
```yaml
shardsCount: 2        # Distribuição de dados em 2 shards
replicasCount: 2      # Alta disponibilidade com 2 réplicas
keeperReplicas: 3     # Quorum de 3 Keepers (HA)
```

**Por que 2 shards?**
- Balanceamento de carga de queries
- Paralelização de ingestão
- Escalabilidade horizontal

**Por que 3 Keepers?**
- Quorum para consenso (tolerância a 1 falha)
- Coordenação de replicação distribuída
- Leve comparado ao ZooKeeper

---

### 3. Por que CloudNativePG?

**Decisão:** Usar CloudNativePG como operador PostgreSQL.

**Racional:**
- ✅ **Cloud Native**: Projetado para Kubernetes
- ✅ **HA Nativo**: Replicação streaming automática
- ✅ **CDC Ready**: WAL level = logical (suporte a CDC)
- ✅ **Backup/Recovery**: Integração com S3, Azure, GCS
- ✅ **Pooling**: PgBouncer integrado
- ✅ **Open Source**: CNCF Sandbox Project

**Configuração CDC:**
```yaml
wal_level: logical              # Necessário para CDC
max_wal_senders: 10             # Conexões de replicação
max_replication_slots: 10       # Slots para PeerDB
REPLICA IDENTITY FULL           # Captura completa de mudanças
```

**Alternativas consideradas:**
- Zalando Postgres Operator: Mais complexo, menos maduro
- Bitnami PostgreSQL HA: Sem operador, configuração manual
- CrunchyData: Comercial, features bloqueadas

---

### 4. Por que PeerDB?

**Decisão:** Usar PeerDB para CDC/ETL PostgreSQL → ClickHouse.

**Racional:**
- ✅ **CDC Nativo**: Projetado especificamente para PG → CH
- ✅ **Desempenho**: 10x mais rápido que Airbyte/Debezium
- ✅ **Tipo-Safe**: Mapeamento automático de tipos PG ↔ CH
- ✅ **Initial Snapshot**: Carga inicial + CDC contínuo
- ✅ **UI Simples**: Interface para configurar mirrors
- ✅ **API REST**: Automação via scripts

**Fluxo CDC:**
```
PostgreSQL WAL → PeerDB Workers → ClickHouse Tables
     ↓                ↓                    ↓
(Logical Decoding) (Processing)     (Batch Insert)
```

**Alternativas consideradas:**
- Debezium + Kafka: Muito complexo, overhead desnecessário
- Airbyte: Lento, não otimizado para PG → CH
- Scripts custom: Não confiável, manutenção alta

---

### 5. Por que Temporal?

**Decisão:** Instalar Temporal como dependência do PeerDB.

**Racional:**
- ✅ **Requisito do PeerDB**: PeerDB usa Temporal para workflows
- ✅ **Orquestração**: Coordena workers de CDC
- ✅ **Retry Logic**: Resiliência automática
- ✅ **Observabilidade**: UI para debug de workflows
- ✅ **Durabilidade**: Workflows sobrevivem a restarts

**Como funciona:**
```
PeerDB → Temporal Workflow → CDC Workers
   │           │                   │
   │           ▼                   ▼
   │     (State Machine)    (Process Changes)
   │           │                   │
   └───────────┴───────────────────┘
         (Metadata PostgreSQL)
```

---

### 6. Estratégia de Deploy com Sync Waves

**Decisão:** Usar sync waves + prefixos numéricos nos arquivos.

**Racional:**
- ✅ **Ordem Garantida**: Operators antes de clusters
- ✅ **Dependências**: PeerDB só após PG + CH prontos
- ✅ **Tolerância a Falhas**: Retry automático por fase
- ✅ **Pulumi-safe**: Prefixos garantem ordem alfabética

**Fases de Deploy:**
```
Wave 1 (01-02): Operators
  ├─ ClickHouse Operator
  └─ CloudNativePG Operator

Wave 2 (03): Clusters + Dependencies
  ├─ ClickHouse Cluster (com Keeper)
  ├─ PostgreSQL Cluster
  ├─ PeerDB PostgreSQL
  └─ Temporal

Wave 3 (04-06): Applications
  ├─ PeerDB Server
  ├─ HPAs
  └─ Monitoring Stack

Wave 4 (07): Setup Jobs
  ├─ Seed Data Job
  └─ PeerDB CDC Mirror Setup
```

---

### 7. Node Affinity e Tolerations

**Decisão:** Distribuir workloads em workers dedicados.

**Racional:**
- ✅ **Isolamento**: Evita noisy neighbors
- ✅ **Performance**: Recursos dedicados por workload
- ✅ **Escalabilidade**: Adicionar nodes por tipo
- ✅ **Custos**: Otimizar instâncias por workload

**Distribuição:**
```
worker-1, worker-2 → PostgreSQL (I/O intensivo)
worker-3           → ClickHouse (CPU/Memória)
worker-4, worker-5 → PeerDB (CPU para CDC)
```

**Implementação:**
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values:
                - postgres  # ou clickhouse, peerdb
```

---

### 8. Auto-scaling (HPAs)

**Decisão:** Configurar HPAs para todos os componentes.

**Racional:**
- ✅ **Elasticidade**: Escala com carga real
- ✅ **Custos**: Reduz pods em períodos ociosos
- ✅ **SLA**: Mantém performance sob carga
- ✅ **Automático**: Sem intervenção manual

**HPAs configurados:**
```
- PostgreSQL: 3-10 replicas (CPU 70%)
- ClickHouse: 4-12 pods (CPU 75%)
- PeerDB Server: 1-5 replicas (CPU 70%)
- PeerDB Workers: 2-8 replicas (CPU 80%)
- Temporal: 1-3 replicas (CPU 70%)
```

---

### 9. Monitoring com Prometheus + Grafana

**Decisão:** Deploy completo do kube-prometheus-stack.

**Racional:**
- ✅ **Observabilidade**: Métricas de todos componentes
- ✅ **Alertas**: Alertmanager para incidentes
- ✅ **Dashboards**: Visualização em tempo real
- ✅ **Service Discovery**: Auto-discovery de targets
- ✅ **Long-term Storage**: Retenção de 30 dias

**Dashboards incluídos:**
- Kubernetes Cluster (gnetId: 7249)
- ClickHouse Overview (gnetId: 882)
- PostgreSQL Database (gnetId: 9628)
- ArgoCD (gnetId: 14584)

---

### 10. Automação de CDC Mirror

**Decisão:** Script Python + Kubernetes Job para setup automático.

**Racional:**
- ✅ **Zero Touch**: CDC configurado automaticamente
- ✅ **Idempotente**: Pode reexecutar sem erros
- ✅ **Validação**: Verifica conectividade antes de criar
- ✅ **GitOps**: Job versionado no Git

**Fluxo:**
```python
1. Aguarda PeerDB estar pronto
2. Lê senha do PostgreSQL (Kubernetes Secret)
3. Cria peer PostgreSQL (postgres-source)
4. Cria peer ClickHouse (clickhouse-destination)
5. Cria mirror PG→CH (tables: users, orders, events)
6. Valida replicação inicial
```

---

## 📊 Especificações Técnicas

### Recursos Computacionais

| Componente | CPU Request | Memory Request | CPU Limit | Memory Limit |
|------------|-------------|----------------|-----------|--------------|
| PostgreSQL | 500m | 1Gi | 2000m | 4Gi |
| ClickHouse | 1000m | 2Gi | 4000m | 8Gi |
| PeerDB Server | 500m | 512Mi | 1000m | 2Gi |
| Temporal | 500m | 512Mi | 1000m | 1Gi |
| Prometheus | 500m | 2Gi | 2000m | 8Gi |
| Grafana | 100m | 256Mi | 500m | 1Gi |

### Storage

| Componente | Tipo | Tamanho | Retenção |
|------------|------|---------|----------|
| PostgreSQL Data | RWO | 20Gi | - |
| ClickHouse Data | RWO | 10Gi/pod | - |
| ClickHouse Logs | RWO | 5Gi/pod | - |
| Keeper Data | RWO | 5Gi/pod | - |
| Prometheus | RWO | 50Gi | 30d |
| Grafana | RWO | 10Gi | - |

### Network Policies

```
argocd       → Todos (gerenciamento)
peerdb       → postgres-cluster (CDC source)
peerdb       → clickhouse-cluster (CDC destination)
prometheus   → Todos (scraping)
grafana      → prometheus (datasource)
```

---

## 🔄 Fluxo de Dados (CDC)

### 1. Escrita no PostgreSQL
```sql
INSERT INTO users (username, email) VALUES ('alice', 'alice@example.com');
```

### 2. Captura no WAL (Write-Ahead Log)
```
PostgreSQL WAL → Logical Decoding → Replication Slot
```

### 3. Processamento PeerDB
```
PeerDB Worker → Lê WAL changes → Transforma tipos → Batch
```

### 4. Escrita no ClickHouse
```
ClickHouse → INSERT INTO users (username, email) VALUES (...)
```

### 5. Verificação
```sql
-- PostgreSQL
SELECT COUNT(*) FROM users; -- 100

-- ClickHouse (após ~5s)
SELECT COUNT(*) FROM users; -- 100 ✅
```

---

## 🧪 Validação e Testes

### Testes Automatizados (scripts/test-e2e.sh)

1. **Connectivity Tests**
   - ✅ PostgreSQL cluster acessível
   - ✅ ClickHouse cluster acessível
   - ✅ PeerDB API respondendo

2. **Data Validation**
   - ✅ PostgreSQL tem dados (users, orders, events)
   - ✅ ClickHouse recebeu dados via CDC
   - ✅ Contagem de registros confere

3. **CDC Health**
   - ✅ Mirror ativo e sincronizando
   - ✅ Replication lag < 10s
   - ✅ Sem erros nos workers

4. **Monitoring**
   - ✅ Prometheus scraping targets
   - ✅ Grafana dashboards carregados
   - ✅ Alertmanager configurado

---

## 🚀 Deployment Pipeline

### Ordem de Execução

```
1. Git Push → main branch
   ↓
2. ArgoCD detecta mudança (3min sync)
   ↓
3. Sync Wave 1: Operators instalados
   ├─ ClickHouse Operator
   └─ CloudNativePG Operator
   ↓
4. Sync Wave 2: Clusters criados
   ├─ ClickHouse Cluster (2 shards, 2 replicas, 3 keepers)
   ├─ PostgreSQL Cluster (3 instâncias)
   ├─ PeerDB PostgreSQL
   └─ Temporal
   ↓
5. Sync Wave 3: Applications
   ├─ PeerDB Server + Workers
   ├─ HPAs
   └─ Prometheus + Grafana
   ↓
6. Sync Wave 4: Setup Jobs
   ├─ Seed Data Job (popular PostgreSQL)
   └─ PeerDB Setup Job (criar CDC mirror)
   ↓
7. ✅ Stack completo rodando
   ├─ PostgreSQL replicando → ClickHouse
   ├─ Monitoring ativo
   └─ Auto-scaling configurado
```

**Tempo total:** ~10-15 minutos

---

## 🎯 Objetivos Cumpridos

| Requisito | Status | Evidência |
|-----------|--------|-----------|
| ClickHouse cluster mode com Keeper | ✅ | `helm-values/clickhouse-cluster.yaml:31-32` |
| Sharding em 2+ nodes | ✅ | `shardsCount: 2` |
| CloudNativePG com dummy data | ✅ | `manifests/cloudnative-pg/seed-data-job.yaml` |
| CDC PG→CH via PeerDB | ✅ | `scripts/setup-peerdb-mirror.py` |
| PostgreSQL + Temporal (deps) | ✅ | `apps/03-peerdb-dependencies.yaml` |
| Réplica contínua validada | ✅ | `scripts/test-e2e.sh` |
| Repo com source-code | ✅ | GitHub repo completo |
| Outline/racional | ✅ | Este documento |
| Instruções de execução | ✅ | `README.md` + `CONTRIBUTING.md` |

---

## 📚 Referências Técnicas

- [ClickHouse Operator](https://github.com/Altinity/clickhouse-operator)
- [CloudNativePG](https://cloudnative-pg.io/)
- [PeerDB](https://docs.peerdb.io/)
- [Temporal](https://temporal.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)

---

## 🔮 Evolução Futura

### Melhorias Planejadas

1. **Multi-tenancy**: Isolamento por namespace
2. **Backup/DR**: Velero + Restic
3. **Security**: Network Policies + OPA
4. **CI/CD**: GitHub Actions + Validation
5. **Observability**: Jaeger + OpenTelemetry
6. **Escalabilidade**: Adicionar mais shards ClickHouse

---

**Autor:** Chalkan3
**Data:** Outubro 2024
**Versão:** 1.0
