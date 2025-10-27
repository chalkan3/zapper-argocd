# Quick Reference - Zapper ArgoCD GitOps

## 🚀 Quick Start

```bash
# 1. Instalar ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Obter senha
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# 3. Atualizar repo URLs
sed -i '' 's/YOUR_USERNAME/seu-usuario/g' apps/*.yaml

# 4. Push para git
git init && git add . && git commit -m "Initial commit"
git remote add origin https://github.com/seu-usuario/zapper-argocd.git
git push -u origin main

# 5. Deploy aplicações
kubectl apply -f apps/

# 6. Monitorar
kubectl get applications -n argocd -w
```

## 📁 Estrutura de Arquivos

```
zapper-argocd/
├── apps/                          ← ArgoCD Applications (COMECE AQUI)
│   ├── clickhouse.yaml            (Operator + Cluster)
│   ├── cloudnative-pg.yaml        (Operator + Cluster)
│   ├── peerdb-dependencies.yaml   (PostgreSQL + Temporal)
│   └── peerdb.yaml                (PeerDB server + workers)
│
├── helm-values/                   ← Configurações dos clusters
│   ├── clickhouse-cluster.yaml    (2 shards, 2 replicas, Keeper)
│   └── postgres-cluster.yaml      (3 instances, CDC, dummy data)
│
├── manifests/                     ← Kubernetes YAML puro
│   └── peerdb/                    (deployments + services)
│
└── docs/
    ├── README.md                  (Setup geral)
    ├── PEERDB_SETUP.md           (Configurar CDC)
    ├── ARCHITECTURE.md            (Arquitetura detalhada)
    ├── CHECKLIST.md              (Validação)
    └── STRUCTURE.md               (Estrutura detalhada)
```

## 🎯 Componentes Deployados

| App | Namespace | Helm Chart | Versão |
|-----|-----------|------------|--------|
| ClickHouse Operator | `clickhouse` | `altinity/clickhouse-operator` | 0.23.6 |
| ClickHouse Cluster | `clickhouse` | CRD (2 shards × 2 replicas) | 23.8 |
| ClickHouse Keeper | `clickhouse` | CRD (3 instances) | 23.8 |
| CloudNativePG Operator | `cloudnative-pg` | `cloudnative-pg/cloudnative-pg` | 0.21.6 |
| PostgreSQL Cluster | `cloudnative-pg` | CRD (3 instances) | 16 |
| PostgreSQL (metadata) | `peerdb` | `bitnami/postgresql` | 15.5.20 |
| Temporal | `peerdb` | `temporal/temporal` | 0.45.1 |
| PeerDB | `peerdb` | Custom manifests | latest |

## 🔧 Comandos Úteis

### Status e Monitoramento

```bash
# Status geral
make status

# Status ArgoCD
kubectl get applications -n argocd

# Todos os pods
kubectl get pods --all-namespaces
```

### Port Forwards

```bash
make port-forward-argocd     # https://localhost:8080
make port-forward-peerdb     # http://localhost:3000
make port-forward-clickhouse # localhost:8123 (HTTP), 9000 (Native)
make port-forward-postgres   # localhost:5432
```

### Logs

```bash
make logs-clickhouse
make logs-postgres
make logs-peerdb
make logs-temporal
```

### Credenciais

```bash
# ArgoCD
User: admin
Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# PostgreSQL (CloudNativePG)
User: app_user
Pass: kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d
Host: postgres-cluster-rw.cloudnative-pg.svc.cluster.local
Port: 5432
DB:   app_db

# ClickHouse
User: admin
Pass: admin123
Host: clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local
Port: 9000 (Native), 8123 (HTTP)

# PeerDB Metadata PostgreSQL
User: peerdb
Pass: peerdb123
Host: peerdb-postgresql.peerdb.svc.cluster.local
Port: 5432
DB:   peerdb_metadata
```

## 🔄 Configurar CDC (PeerDB)

```bash
# 1. Port-forward PeerDB
kubectl port-forward -n peerdb svc/peerdb 3000:3000

# 2. Acessar http://localhost:3000

# 3. Criar PostgreSQL Peer
Name: postgres-source
Host: postgres-cluster-rw.cloudnative-pg.svc.cluster.local:5432
DB:   app_db
User: app_user
Pass: [do secret acima]

# 4. Criar ClickHouse Peer
Name: clickhouse-destination
Host: clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local:9000
DB:   default
User: admin
Pass: admin123

# 5. Criar Mirror
Name:   pg-to-ch-mirror
Source: postgres-source
Dest:   clickhouse-destination
Tables: users, orders, events
Mode:   CDC
```

## 🎛️ Modificar Configurações

### Aumentar shards do ClickHouse

```bash
# Editar helm-values/clickhouse-cluster.yaml
layout:
  shardsCount: 4      # ← Aumentar
  replicasCount: 2

# Commit + push → ArgoCD sincroniza
```

### Aumentar instâncias do PostgreSQL

```bash
# Editar helm-values/postgres-cluster.yaml
instances: 5  # ← Aumentar

# Commit + push → ArgoCD sincroniza
```

### Escalar PeerDB workers

```bash
# Editar manifests/peerdb/deployment.yaml
replicas: 4  # ← Aumentar

# Ou via kubectl
kubectl scale deployment -n peerdb peerdb-flow-worker --replicas=4
```

## 🧪 Testar CDC

```bash
# 1. Port-forward PostgreSQL
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432 &

# 2. Inserir dados
PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db -c \
  "INSERT INTO users (username, email) VALUES ('test', 'test@example.com');"

# 3. Port-forward ClickHouse
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-cluster-0-0 9000:9000 &

# 4. Verificar replicação (aguardar 30s)
echo "SELECT * FROM users WHERE username='test';" | \
  clickhouse-client --host localhost --port 9000 --user admin --password admin123
```

## 🐛 Troubleshooting

### Application não sincroniza

```bash
# Ver detalhes
kubectl describe application <name> -n argocd

# Forçar sync
kubectl patch application <name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Pods não sobem

```bash
# Ver eventos
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Logs do pod
kubectl logs -n <namespace> <pod-name>

# Descrever pod
kubectl describe pod -n <namespace> <pod-name>
```

### CDC não funciona

```bash
# 1. Verificar wal_level
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SHOW wal_level;"
# Deve ser: logical

# 2. Verificar publication
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SELECT * FROM pg_publication;"

# 3. Verificar slot
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db -c "SELECT * FROM pg_replication_slots;"

# 4. Logs PeerDB
kubectl logs -n peerdb -l app=peerdb --tail=100
```

## 🧹 Limpeza

```bash
# Remover tudo
make clean

# Ou manualmente
kubectl delete -f apps/
kubectl delete namespace argocd clickhouse cloudnative-pg peerdb
```

## 📚 Documentação Completa

- **README.md** - Setup completo
- **PEERDB_SETUP.md** - Configuração CDC detalhada
- **ARCHITECTURE.md** - Arquitetura do sistema
- **STRUCTURE.md** - Estrutura do repositório
- **CHECKLIST.md** - Checklist de validação

## 🔗 Links Úteis

- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [ClickHouse Operator](https://github.com/Altinity/clickhouse-operator)
- [CloudNativePG](https://cloudnative-pg.io/)
- [PeerDB](https://docs.peerdb.io/)
- [Temporal](https://docs.temporal.io/)

## 💡 Dicas

- Use `make help` para ver todos os comandos disponíveis
- Applications sincronizam automaticamente a cada 3 minutos
- Use `helm list -A` para ver todos os releases Helm
- ArgoCD UI mostra diff visual de mudanças
- Logs do ArgoCD: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`
