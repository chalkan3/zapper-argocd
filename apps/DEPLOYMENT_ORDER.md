# Ordem de Deploy - Zapper ArgoCD

## Visão Geral

Os arquivos na pasta `apps/` são nomeados com **prefixos numéricos (01-07)** para garantir ordem de aplicação sequencial, mesmo quando o Pulumi ou outros sistemas aplicam arquivos em ordem aleatória.

## Sequência de Deploy

```
┌─────────────────────────────────────────────────────────────┐
│  FASE 1: OPERATORS (01-02)                                  │
│  Instalação dos operadores Kubernetes                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  01-clickhouse-operator.yaml              │
    │    ├─ ClickHouse Operator (wave 1)        │
    │    └─ ClickHouse Cluster (wave 2)         │
    └───────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  02-cloudnative-pg-operator.yaml          │
    │    ├─ CloudNativePG Operator (wave 1)     │
    │    └─ PostgreSQL Cluster (wave 2)         │
    └───────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  FASE 2: DEPENDENCIES (03)                                  │
│  Serviços que PeerDB precisa                                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  03-peerdb-dependencies.yaml              │
    │    ├─ PeerDB PostgreSQL (wave 2)          │
    │    └─ Temporal (wave 2)                   │
    └───────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  FASE 3: APPLICATIONS (04-06)                               │
│  Aplicações principais                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  04-peerdb.yaml                           │
    │    └─ PeerDB Application (wave 3)         │
    └───────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  05-hpa.yaml                              │
    │    └─ Horizontal Pod Autoscalers (wave 3) │
    └───────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  06-monitoring.yaml                       │
    │    ├─ Prometheus Stack (wave 3)           │
    │    └─ ServiceMonitors (wave 4)            │
    └───────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  FASE 4: SETUP JOBS (07)                                    │
│  Configuração automática pós-deploy                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
    ┌───────────────────────────────────────────┐
    │  07-peerdb-setup.yaml                     │
    │    └─ PeerDB CDC Mirror Setup (wave 4)    │
    └───────────────────────────────────────────┘
```

## Garantias de Ordem

### 1. Ordem Alfabética (Prefixos Numéricos)
Os arquivos são processados alfabeticamente:
```
01-* → 02-* → 03-* → 04-* → 05-* → 06-* → 07-*
```

### 2. Sync Waves (Dentro de Cada Arquivo)
Cada arquivo pode ter múltiplas Applications com sync waves:
- **Wave 1**: Operators primeiro
- **Wave 2**: Clusters/Dependencies
- **Wave 3**: Applications
- **Wave 4**: Setup Jobs

### 3. Dupla Proteção
```
Prefixo Numérico          Sync Wave
(ordem de arquivo)    +   (ordem interna)
       ↓                        ↓
01-clickhouse.yaml    →   operator (wave 1) → cluster (wave 2)
02-cloudnative-pg.yaml →  operator (wave 1) → cluster (wave 2)
```

## Timeline de Deploy Esperado

```
T=0s    : ArgoCD começa a processar apps/
T=5s    : 01-clickhouse-operator.yaml aplicado
T=10s   : ClickHouse Operator instalado (wave 1)
T=30s   : ClickHouse Cluster criado (wave 2)
T=35s   : 02-cloudnative-pg-operator.yaml aplicado
T=40s   : CloudNativePG Operator instalado (wave 1)
T=60s   : PostgreSQL Cluster criado (wave 2)
T=65s   : 03-peerdb-dependencies.yaml aplicado
T=90s   : PeerDB PostgreSQL + Temporal prontos (wave 2)
T=95s   : 04-peerdb.yaml aplicado
T=120s  : PeerDB Application rodando (wave 3)
T=125s  : 05-hpa.yaml aplicado
T=130s  : HPAs configurados (wave 3)
T=135s  : 06-monitoring.yaml aplicado
T=180s  : Prometheus + Grafana prontos (wave 3+4)
T=185s  : 07-peerdb-setup.yaml aplicado
T=240s  : CDC Mirror configurado (wave 4)
T=300s  : ✅ TUDO PRONTO!
```

## Dependências Críticas

| Arquivo | Depende De | Razão |
|---------|------------|-------|
| 03-peerdb-dependencies.yaml | 01, 02 | Precisa de PostgreSQL Cluster |
| 04-peerdb.yaml | 03 | Precisa de PeerDB PostgreSQL + Temporal |
| 05-hpa.yaml | 01, 02, 04 | Precisa dos workloads deployados |
| 06-monitoring.yaml | 04 | ServiceMonitors precisam de PeerDB |
| 07-peerdb-setup.yaml | 01, 02, 04 | CDC precisa de PG + CH + PeerDB |

## Validação

### Verificar Ordem de Aplicação
```bash
# Listar arquivos em ordem
ls -1 apps/*.yaml

# Deve retornar:
# 01-clickhouse-operator.yaml
# 02-cloudnative-pg-operator.yaml
# 03-peerdb-dependencies.yaml
# 04-peerdb.yaml
# 05-hpa.yaml
# 06-monitoring.yaml
# 07-peerdb-setup.yaml
```

### Monitorar Deploy
```bash
# Watch de todas Applications
kubectl get applications -n argocd -w

# Ver sync waves
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.argocd\.argoproj\.io/sync-wave}{"\n"}{end}' | sort -k2 -n
```

## Troubleshooting

### Se o deploy falhar:

1. **Verificar ordem dos arquivos**
   ```bash
   ls -1 apps/*.yaml | cat -n
   ```

2. **Verificar sync waves**
   ```bash
   grep -r "sync-wave" apps/
   ```

3. **Ver status de cada Application**
   ```bash
   kubectl get applications -n argocd
   ```

4. **Ver detalhes de falha**
   ```bash
   kubectl describe application <app-name> -n argocd
   ```

5. **Forçar re-sync**
   ```bash
   kubectl patch application <app-name> -n argocd --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
   ```
