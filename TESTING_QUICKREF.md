# 🧪 Testing Quick Reference

## Teste Automatizado (Mais Rápido)

```bash
# Executar script de teste E2E
./test-e2e.sh
```

Este script verifica automaticamente:
- ✅ ArgoCD (8 Applications)
- ✅ PostgreSQL (3 pods + dummy data)
- ✅ ClickHouse (4 pods + 3 keepers)
- ✅ PeerDB (3 pods)
- ✅ Temporal (4+ pods)
- ✅ HPAs (9 HPAs)
- ✅ Node affinity

---

## Testes Manuais (Passo a Passo)

### 1. Testar PostgreSQL (Dummy Data)

```bash
# Port-forward
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432

# Conectar
export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)
psql -h localhost -U app_user -d app_db

# Verificar dados
SELECT COUNT(*) FROM users;    -- Esperado: 4
SELECT COUNT(*) FROM orders;   -- Esperado: 5
SELECT COUNT(*) FROM events;   -- Esperado: 4
```

---

### 2. Testar ClickHouse (Cluster)

```bash
# Port-forward
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000

# Conectar
clickhouse-client --host localhost --port 9000 --user admin --password admin123

# Verificar cluster
SELECT * FROM system.clusters WHERE cluster = 'clickhouse-cluster';
-- Esperado: 4 linhas (2 shards × 2 replicas)
```

---

### 3. Testar Temporal (Workflows)

```bash
# Port-forward UI
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080

# Acessar: http://localhost:8088
# Você deve ver a interface do Temporal
```

---

### 4. Testar PeerDB (UI)

```bash
# Port-forward
kubectl port-forward -n peerdb svc/peerdb 3000:3000

# Acessar: http://localhost:3000
# Você deve ver a interface do PeerDB
```

---

### 5. Testar CDC (Replicação PG → CH)

#### Passo 1: Configurar no PeerDB UI

1. **Criar PostgreSQL Peer**
   - Host: `postgres-cluster-rw.cloudnative-pg.svc.cluster.local`
   - Port: `5432`
   - Database: `app_db`
   - User: `app_user`
   - Password: [do secret]

2. **Criar ClickHouse Peer**
   - Host: `chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local`
   - Port: `9000`
   - Database: `default`
   - User: `admin`
   - Password: `admin123`

3. **Criar Mirror**
   - Tables: `users`, `orders`, `events`
   - Mode: `CDC`

#### Passo 2: Verificar Dados Replicados

```bash
# No ClickHouse
SELECT COUNT(*) FROM users;    -- Deve ser igual ao PostgreSQL (4)
SELECT COUNT(*) FROM orders;   -- Deve ser igual ao PostgreSQL (5)
SELECT COUNT(*) FROM events;   -- Deve ser igual ao PostgreSQL (4)
```

#### Passo 3: Testar Tempo Real

```sql
-- No PostgreSQL
INSERT INTO users (username, email) VALUES ('test_realtime', 'test@example.com');

-- Aguardar 30 segundos

-- No ClickHouse
SELECT * FROM users WHERE username = 'test_realtime';
-- Deve aparecer! ✅
```

---

### 6. Testar HPAs (Auto-scaling)

```bash
# Ver status dos HPAs
kubectl get hpa --all-namespaces

# Ver métricas atuais
kubectl top pods -n peerdb

# Gerar carga (inserir muitos dados)
# No PostgreSQL:
INSERT INTO users (username, email)
SELECT 'user_' || generate_series(1, 100000),
       'email_' || generate_series(1, 100000);

# Monitorar scaling
watch kubectl get hpa peerdb-flow-worker-hpa -n peerdb
# Você deve ver REPLICAS aumentando: 2 → 3 → 4...
```

---

### 7. Testar Node Affinity

```bash
# Ver distribuição de pods por node
kubectl get pods -o wide --all-namespaces | grep -E "postgres|clickhouse|peerdb" | awk '{print $1, $2, $8}'

# Resultado esperado:
# cloudnative-pg  postgres-cluster-1   worker-1 ✅
# cloudnative-pg  postgres-cluster-2   worker-2 ✅
# clickhouse      clickhouse-...       worker-3 ✅
# peerdb          peerdb-server-...    worker-4 ✅
# peerdb          peerdb-worker-...    worker-5 ✅
```

---

## 🔍 Troubleshooting Rápido

### CDC não funciona?

```bash
# 1. Ver logs do PeerDB
kubectl logs -n peerdb deployment/peerdb-flow-worker --tail=100

# 2. Verificar replication slot
psql -c "SELECT * FROM pg_replication_slots;"

# 3. Verificar Temporal workflows
# Acessar: http://localhost:8088
```

### HPAs não escalam?

```bash
# 1. Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# 2. Ver eventos do HPA
kubectl describe hpa peerdb-flow-worker-hpa -n peerdb
```

### Pods não vão para workers corretos?

```bash
# 1. Verificar labels
kubectl get nodes --show-labels | grep workload

# 2. Ver eventos do pod
kubectl describe pod <pod-name> -n <namespace>
```

---

## 📊 Checklist de Validação Rápida

```bash
# Execute estes comandos e verifique os resultados:

# 1. ArgoCD
kubectl get applications -n argocd
# ✅ 8 applications com SYNC STATUS = Synced

# 2. Pods
kubectl get pods --all-namespaces | grep -E "postgres|clickhouse|peerdb"
# ✅ Todos Running

# 3. HPAs
kubectl get hpa --all-namespaces
# ✅ 9 HPAs

# 4. Services
kubectl get svc -n peerdb peerdb
kubectl get svc -n cloudnative-pg postgres-cluster-rw
kubectl get svc -n clickhouse
# ✅ Todos presentes

# 5. Dummy Data (PostgreSQL)
export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)
psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM users;"
# ✅ Retorna 4

# 6. CDC Replication (ClickHouse)
clickhouse-client --host localhost --port 9000 --user admin --password admin123 --query "SELECT COUNT(*) FROM users;"
# ✅ Retorna 4 (igual ao PostgreSQL)
```

---

## 📚 Documentação Completa

Para testes detalhados, veja:
- **TESTING_GUIDE.md** - Guia completo com todos os testes
- **test-e2e.sh** - Script automatizado de testes

---

## ✅ Status Esperado Final

| Componente | Status | Validação |
|------------|--------|-----------|
| ArgoCD | ✅ Synced | 8 Applications |
| PostgreSQL | ✅ Running | 3 pods, 13 registros |
| ClickHouse | ✅ Running | 4 pods + 3 keepers |
| PeerDB | ✅ Running | 3 pods, UI acessível |
| Temporal | ✅ Running | 4+ pods, UI acessível |
| CDC | ✅ Working | Dados replicados |
| CDC Realtime | ✅ Working | INSERT/UPDATE/DELETE |
| HPAs | ✅ Configured | 9 HPAs |
| Node Affinity | ✅ Working | Pods nos workers corretos |

**Se todos ✅, sua infra está 100% funcional!** 🎉
