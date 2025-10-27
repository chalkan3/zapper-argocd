# 📊 Resumo de ArgoCD Applications

## Total de Applications: **8**

Distribuídas em **5 arquivos YAML** no diretório `apps/`:

---

## 📄 Arquivo: `clickhouse.yaml` (2 Applications)

### 1. `clickhouse-operator`
- **Tipo**: Helm Chart
- **Repositório**: https://docs.altinity.com/clickhouse-operator/
- **Chart**: altinity-clickhouse-operator
- **Versão**: 0.23.6
- **Namespace**: clickhouse
- **Descrição**: Instala o ClickHouse Operator

### 2. `clickhouse-cluster`
- **Tipo**: Directory (manifests do repo)
- **Source**: helm-values/clickhouse-cluster.yaml
- **Namespace**: clickhouse
- **Descrição**: Cria o cluster ClickHouse (CRDs: ClickHouseInstallation + ClickHouseKeeperInstallation)

---

## 📄 Arquivo: `cloudnative-pg.yaml` (2 Applications)

### 3. `cloudnative-pg-operator`
- **Tipo**: Helm Chart
- **Repositório**: https://cloudnative-pg.github.io/charts
- **Chart**: cloudnative-pg
- **Versão**: 0.21.6
- **Namespace**: cloudnative-pg
- **Descrição**: Instala o CloudNativePG Operator

### 4. `postgres-cluster`
- **Tipo**: Directory (manifests do repo)
- **Source**: helm-values/postgres-cluster.yaml
- **Namespace**: cloudnative-pg
- **Descrição**: Cria o cluster PostgreSQL (CRD: Cluster com dummy data)

---

## 📄 Arquivo: `peerdb-dependencies.yaml` (2 Applications)

### 5. `peerdb-postgresql`
- **Tipo**: Helm Chart
- **Repositório**: https://charts.bitnami.com/bitnami
- **Chart**: postgresql
- **Versão**: 15.5.20
- **Namespace**: peerdb
- **Descrição**: PostgreSQL para metadados do PeerDB + Temporal

### 6. `peerdb-temporal`
- **Tipo**: Helm Chart
- **Repositório**: https://go.temporal.io/helm-charts
- **Chart**: temporal
- **Versão**: 0.45.1
- **Namespace**: peerdb
- **Descrição**: Temporal workflow engine

---

## 📄 Arquivo: `peerdb.yaml` (1 Application)

### 7. `peerdb`
- **Tipo**: Directory (manifests do repo)
- **Source**: manifests/peerdb/
- **Namespace**: peerdb
- **Descrição**: PeerDB server + flow-workers

---

## 📄 Arquivo: `hpa.yaml` (1 Application)

### 8. `hpa`
- **Tipo**: Directory (manifests do repo)
- **Source**: manifests/hpa/
- **Namespace**: Múltiplos (clickhouse, cloudnative-pg, peerdb)
- **Descrição**: Horizontal Pod Autoscalers para todos os componentes (9 HPAs)

---

## 📊 Resumo por Tipo

| Tipo | Quantidade | Applications |
|------|------------|--------------|
| **Helm Chart** | 5 | clickhouse-operator, cloudnative-pg-operator, peerdb-postgresql, peerdb-temporal |
| **Directory** | 3 | clickhouse-cluster, postgres-cluster, peerdb, hpa |

**Total**: **8 Applications**

---

## 📊 Resumo por Namespace

| Namespace | Applications | Descrição |
|-----------|-------------|-----------|
| **clickhouse** | 2 | Operator + Cluster |
| **cloudnative-pg** | 2 | Operator + Cluster |
| **peerdb** | 3 | PostgreSQL + Temporal + PeerDB |
| **Múltiplos** | 1 | HPAs (distribui HPAs em vários namespaces) |

---

## 🔄 Ordem de Deploy

As Applications serão sincronizadas pelo ArgoCD nesta sequência lógica:

1. **clickhouse-operator** → Instala operator
2. **clickhouse-cluster** → Cria cluster (depende do operator)
3. **cloudnative-pg-operator** → Instala operator
4. **postgres-cluster** → Cria cluster (depende do operator)
5. **peerdb-postgresql** → Instala PostgreSQL
6. **peerdb-temporal** → Instala Temporal (depende do PostgreSQL)
7. **peerdb** → Instala PeerDB (depende de PostgreSQL + Temporal)
8. **hpa** → Cria HPAs para auto-scaling (pode ser aplicado em paralelo)

---

## 📝 Comandos Úteis

### Ver todas as Applications

```bash
kubectl get applications -n argocd
```

Output esperado:
```
NAME                      SYNC STATUS   HEALTH STATUS
clickhouse-operator       Synced        Healthy
clickhouse-cluster        Synced        Healthy
cloudnative-pg-operator   Synced        Healthy
postgres-cluster          Synced        Healthy
peerdb-postgresql         Synced        Healthy
peerdb-temporal           Synced        Healthy
peerdb                    Synced        Healthy
hpa                       Synced        Healthy
```

### Ver detalhes de uma Application

```bash
kubectl describe application clickhouse-operator -n argocd
```

### Forçar sync de uma Application

```bash
kubectl patch application clickhouse-operator -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Ver logs de sync

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

---

## 🎯 Diferença: Application vs ApplicationSet

**Nota**: Este repositório usa **Applications** (não ApplicationSets).

| Conceito | Descrição | Quando usar |
|----------|-----------|-------------|
| **Application** | Gerencia um único deployment | Deploy de componentes individuais (nosso caso) |
| **ApplicationSet** | Template que gera múltiplas Applications | Deploy em múltiplos ambientes/clusters |

**Por que Applications?**
- Deploy em um único cluster
- Controle individual de cada componente
- Mais simples e direto
- Sync policies independentes

---

## 📦 Estrutura de Arquivos vs Applications

```
apps/
├── clickhouse.yaml              → 2 Applications
│   ├── clickhouse-operator
│   └── clickhouse-cluster
│
├── cloudnative-pg.yaml          → 2 Applications
│   ├── cloudnative-pg-operator
│   └── postgres-cluster
│
├── peerdb-dependencies.yaml     → 2 Applications
│   ├── peerdb-postgresql
│   └── peerdb-temporal
│
├── peerdb.yaml                  → 1 Application
│   └── peerdb
│
└── hpa.yaml                     → 1 Application
    └── hpa (9 HPAs)

TOTAL: 5 arquivos → 8 Applications
```

---

## ✅ Checklist de Validação

Após aplicar `kubectl apply -f apps/`, verifique:

- [ ] 8 Applications criadas no namespace argocd
- [ ] Todas com status "Synced"
- [ ] Todas com health "Healthy"
- [ ] Pods rodando em clickhouse namespace
- [ ] Pods rodando em cloudnative-pg namespace
- [ ] Pods rodando em peerdb namespace
- [ ] HPAs criados em todos os namespaces (`kubectl get hpa --all-namespaces`)

```bash
# Comando rápido para verificar
kubectl get applications -n argocd && \
kubectl get pods -n clickhouse && \
kubectl get pods -n cloudnative-pg && \
kubectl get pods -n peerdb
```

---

**Total**: **8 ArgoCD Applications** em **5 arquivos YAML**

**Novo**: Inclui HPA (Horizontal Pod Autoscaler) com **9 HPAs** para auto-scaling de todos os componentes.
