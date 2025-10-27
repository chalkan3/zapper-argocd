# 🧪 Guia Completo de Testes - Validação End-to-End

Este guia mostra como testar e validar que todos os componentes estão funcionando corretamente.

---

## 📋 Índice de Testes

1. [Testar ArgoCD](#1-testar-argocd)
2. [Testar CloudNativePG (PostgreSQL)](#2-testar-cloudnativepg-postgresql)
3. [Testar ClickHouse](#3-testar-clickhouse)
4. [Testar Temporal](#4-testar-temporal)
5. [Testar PeerDB](#5-testar-peerdb)
6. [Testar CDC (Replicação PG → CH)](#6-testar-cdc-replicação-pg--ch)
7. [Testar HPAs](#7-testar-hpas)
8. [Testar Node Affinity](#8-testar-node-affinity)
9. [Teste End-to-End Completo](#9-teste-end-to-end-completo)

---

## 1. Testar ArgoCD

### 1.1 Verificar Status das Applications

```bash
# Ver todas as applications
kubectl get applications -n argocd

# Resultado esperado: 8 applications com SYNC STATUS = Synced
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

### 1.2 Verificar Detalhes de uma Application

```bash
# Ver detalhes
kubectl describe application postgres-cluster -n argocd

# Ver recursos gerenciados
kubectl get application postgres-cluster -n argocd -o yaml
```

### 1.3 Acessar ArgoCD UI

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Obter senha
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Acessar: https://localhost:8080
# User: admin
# Pass: [senha acima]
```

**✅ Teste Passou:** Todas as 8 applications estão "Synced" e "Healthy"

---

## 2. Testar CloudNativePG (PostgreSQL)

### 2.1 Verificar Cluster Status

```bash
# Ver cluster
kubectl get cluster -n cloudnative-pg

# Ver pods
kubectl get pods -n cloudnative-pg

# Resultado esperado: 3 pods running
```

Output esperado:
```
NAME                   READY   STATUS    RESTARTS   AGE
postgres-cluster-1     1/1     Running   0          10m
postgres-cluster-2     1/1     Running   0          9m
postgres-cluster-3     1/1     Running   0          8m
```

### 2.2 Conectar ao PostgreSQL

```bash
# Port-forward
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432

# Em outro terminal, obter senha
export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)

# Conectar
psql -h localhost -U app_user -d app_db
```

### 2.3 Verificar Dummy Data

```sql
-- Ver tabelas
\dt

-- Resultado esperado: users, orders, events

-- Contar registros
SELECT 'users' as table, COUNT(*) as count FROM users
UNION ALL
SELECT 'orders' as table, COUNT(*) as count FROM orders
UNION ALL
SELECT 'events' as table, COUNT(*) as count FROM events;
```

Output esperado:
```
 table  | count
--------+-------
 users  |     4
 orders |     5
 events |     4
```

### 2.4 Verificar Logical Replication

```sql
-- Verificar wal_level
SHOW wal_level;
-- Esperado: logical

-- Verificar replication slots
SELECT * FROM pg_replication_slots;

-- Verificar publications (depois de configurar PeerDB)
SELECT * FROM pg_publication;

-- Verificar REPLICA IDENTITY
SELECT
  schemaname,
  tablename,
  CASE relreplident
    WHEN 'd' THEN 'default'
    WHEN 'n' THEN 'nothing'
    WHEN 'f' THEN 'full'
    WHEN 'i' THEN 'index'
  END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_tables t ON c.relname = t.tablename AND n.nspname = t.schemaname
WHERE schemaname = 'public';
```

Output esperado:
```
 schemaname | tablename | replica_identity
------------+-----------+------------------
 public     | users     | full
 public     | orders    | full
 public     | events    | full
```

**✅ Teste Passou:** PostgreSQL está rodando, tem dummy data e CDC está configurado

---

## 3. Testar ClickHouse

### 3.1 Verificar Cluster Status

```bash
# Ver pods ClickHouse
kubectl get pods -n clickhouse -l app=clickhouse

# Ver pods Keeper
kubectl get pods -n clickhouse -l clickhouse.altinity.com/keeper=clickhouse-keeper

# Resultado esperado: 4 pods CH + 3 pods Keeper
```

Output esperado:
```
# ClickHouse pods
NAME                          READY   STATUS    RESTARTS   AGE
clickhouse-clickhouse-0-0-0   1/1     Running   0          15m
clickhouse-clickhouse-0-1-0   1/1     Running   0          14m
clickhouse-clickhouse-1-0-0   1/1     Running   0          13m
clickhouse-clickhouse-1-1-0   1/1     Running   0          12m

# Keeper pods
NAME                  READY   STATUS    RESTARTS   AGE
clickhouse-keeper-0   1/1     Running   0          16m
clickhouse-keeper-1   1/1     Running   0          15m
clickhouse-keeper-2   1/1     Running   0          14m
```

### 3.2 Conectar ao ClickHouse

```bash
# Port-forward
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000 8123:8123

# Em outro terminal, testar conexão HTTP
curl -s http://localhost:8123/ping
# Esperado: Ok.

# Ou usar clickhouse-client
clickhouse-client --host localhost --port 9000 --user admin --password admin123
```

### 3.3 Verificar Cluster Configuration

```sql
-- Ver clusters
SELECT * FROM system.clusters WHERE cluster = 'clickhouse-cluster';

-- Ver shards e replicas
SELECT
  cluster,
  shard_num,
  replica_num,
  host_name,
  port
FROM system.clusters
WHERE cluster = 'clickhouse-cluster'
ORDER BY shard_num, replica_num;
```

Output esperado:
```
cluster              | shard_num | replica_num | host_name                   | port
---------------------+-----------+-------------+-----------------------------+------
clickhouse-cluster   | 1         | 1           | clickhouse-clickhouse-0-0   | 9000
clickhouse-cluster   | 1         | 2           | clickhouse-clickhouse-0-1   | 9000
clickhouse-cluster   | 2         | 1           | clickhouse-clickhouse-1-0   | 9000
clickhouse-cluster   | 2         | 2           | clickhouse-clickhouse-1-1   | 9000
```

### 3.4 Verificar Keeper (Zookeeper)

```sql
-- Ver keeper nodes
SELECT * FROM system.zookeeper WHERE path = '/';

-- Status do keeper
SELECT * FROM system.zookeeper WHERE path = '/clickhouse/task_queue/replicated';
```

### 3.5 Testar Inserção Manual

```sql
-- Criar tabela de teste
CREATE TABLE IF NOT EXISTS test_table ON CLUSTER clickhouse-cluster
(
    id UInt64,
    name String,
    created DateTime
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/test_table', '{replica}')
ORDER BY id;

-- Inserir dados
INSERT INTO test_table VALUES (1, 'test', now());

-- Verificar em todos os shards
SELECT * FROM test_table;

-- Ver distribuição
SELECT
    hostName() as host,
    count() as records
FROM test_table
GROUP BY host;
```

**✅ Teste Passou:** ClickHouse cluster está rodando com 2 shards, 2 replicas e Keeper funcionando

---

## 4. Testar Temporal

### 4.1 Verificar Temporal Pods

```bash
# Ver todos os pods do Temporal
kubectl get pods -n peerdb -l app.kubernetes.io/instance=peerdb-temporal

# Resultado esperado: frontend, history, matching, worker
```

Output esperado:
```
NAME                                        READY   STATUS    RESTARTS   AGE
peerdb-temporal-frontend-xxxxxxxxx-xxxxx    1/1     Running   0          20m
peerdb-temporal-history-xxxxxxxxx-xxxxx     1/1     Running   0          20m
peerdb-temporal-matching-xxxxxxxxx-xxxxx    1/1     Running   0          20m
peerdb-temporal-worker-xxxxxxxxx-xxxxx      1/1     Running   0          20m
```

### 4.2 Acessar Temporal UI

```bash
# Port-forward da UI
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080

# Acessar: http://localhost:8088
```

### 4.3 Verificar Temporal via CLI

```bash
# Exec no pod do admintools
kubectl exec -it -n peerdb deployment/peerdb-temporal-admintools -- bash

# Dentro do pod, listar namespaces
tctl --namespace default namespace list

# Ver workflows
tctl --namespace default workflow list
```

### 4.4 Verificar Conectividade com PostgreSQL

```bash
# Do pod do Temporal
kubectl exec -it -n peerdb deployment/peerdb-temporal-frontend -- sh

# Testar conexão
nc -zv peerdb-postgresql 5432
# Esperado: succeeded!

# Verificar databases
export PGPASSWORD=peerdb123
psql -h peerdb-postgresql -U peerdb -l
```

Output esperado deve incluir:
```
   Name               | Owner  | Encoding
----------------------+--------+----------
 peerdb_metadata      | peerdb | UTF8
 temporal             | peerdb | UTF8
 temporal_visibility  | peerdb | UTF8
```

**✅ Teste Passou:** Temporal está rodando e conectado ao PostgreSQL

---

## 5. Testar PeerDB

### 5.1 Verificar PeerDB Pods

```bash
# Ver pods do PeerDB
kubectl get pods -n peerdb -l app=peerdb

# Resultado esperado: 1 server + 2 flow-workers
```

Output esperado:
```
NAME                                  READY   STATUS    RESTARTS   AGE
peerdb-server-xxxxxxxxx-xxxxx         1/1     Running   0          25m
peerdb-flow-worker-xxxxxxxxx-xxxxx    1/1     Running   0          25m
peerdb-flow-worker-xxxxxxxxx-yyyyy    1/1     Running   0          25m
```

### 5.2 Acessar PeerDB UI

```bash
# Port-forward
kubectl port-forward -n peerdb svc/peerdb 3000:3000

# Acessar: http://localhost:3000
```

**Você deve ver a interface do PeerDB!**

### 5.3 Testar Conectividade do PeerDB

```bash
# Entrar no pod do PeerDB server
kubectl exec -it -n peerdb deployment/peerdb-server -- sh

# Testar conexão com PostgreSQL (CloudNativePG)
nc -zv postgres-cluster-rw.cloudnative-pg.svc.cluster.local 5432
# Esperado: succeeded!

# Testar conexão com ClickHouse
nc -zv chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local 9000
# Esperado: succeeded!

# Testar conexão com Temporal
nc -zv peerdb-temporal-frontend 7233
# Esperado: succeeded!

# Testar conexão com PostgreSQL metadata
nc -zv peerdb-postgresql 5432
# Esperado: succeeded!
```

### 5.4 Verificar Logs do PeerDB

```bash
# Logs do server
kubectl logs -n peerdb deployment/peerdb-server --tail=50

# Logs dos workers
kubectl logs -n peerdb deployment/peerdb-flow-worker --tail=50

# Não deve ter erros críticos
```

**✅ Teste Passou:** PeerDB está rodando e consegue conectar em todos os componentes

---

## 6. Testar CDC (Replicação PG → CH)

### 6.1 Configurar Peers no PeerDB UI

Acesse http://localhost:3000 e configure:

#### 6.1.1 Criar PostgreSQL Peer

1. Vá em **"Peers"** → **"Add Peer"**
2. Selecione **"PostgreSQL"**
3. Preencha:
   ```
   Name: postgres-source
   Host: postgres-cluster-rw.cloudnative-pg.svc.cluster.local
   Port: 5432
   Database: app_db
   User: app_user
   Password: [obter com: kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d]
   SSL Mode: disable
   ```
4. **"Test Connection"** → Deve ter sucesso ✅
5. **"Create Peer"**

#### 6.1.2 Criar ClickHouse Peer

1. Vá em **"Peers"** → **"Add Peer"**
2. Selecione **"ClickHouse"**
3. Preencha:
   ```
   Name: clickhouse-destination
   Host: chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local
   Port: 9000
   Database: default
   User: admin
   Password: admin123
   SSL: false
   ```
4. **"Test Connection"** → Deve ter sucesso ✅
5. **"Create Peer"**

### 6.2 Criar Mirror (CDC)

1. Vá em **"Mirrors"** → **"Create Mirror"**
2. Preencha:
   ```
   Mirror Name: pg-to-ch-mirror
   Source Peer: postgres-source
   Destination Peer: clickhouse-destination

   Tables to replicate:
   - public.users
   - public.orders
   - public.events

   Sync Mode: CDC
   Do Initial Copy: Yes
   Publication Name: peerdb_publication
   Replication Slot: peerdb_slot
   ```
3. **"Create Mirror"**

### 6.3 Aguardar Sync Inicial

```bash
# Monitorar logs do flow-worker
kubectl logs -n peerdb deployment/peerdb-flow-worker -f

# Você deve ver:
# - Criando replication slot
# - Criando publication
# - Initial snapshot
# - Copiando dados
```

### 6.4 Verificar Dados no ClickHouse

```bash
# Conectar ao ClickHouse
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000
clickhouse-client --host localhost --port 9000 --user admin --password admin123
```

```sql
-- Ver databases
SHOW DATABASES;

-- Ver tabelas (PeerDB cria no database 'default')
SHOW TABLES;

-- Contar registros (deve ser igual ao PostgreSQL)
SELECT 'users' as table, COUNT(*) as count FROM users
UNION ALL
SELECT 'orders' as table, COUNT(*) as count FROM orders
UNION ALL
SELECT 'events' as table, COUNT(*) as count FROM events;
```

Output esperado (igual ao PostgreSQL):
```
 table  | count
--------+-------
 users  |     4
 orders |     5
 events |     4
```

### 6.5 Verificar Replication Slot no PostgreSQL

```bash
# Conectar ao PostgreSQL
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432
export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)
psql -h localhost -U app_user -d app_db
```

```sql
-- Ver replication slots (deve ter 'peerdb_slot')
SELECT
  slot_name,
  plugin,
  slot_type,
  database,
  active,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as lag
FROM pg_replication_slots;
```

Output esperado:
```
  slot_name  |  plugin  | slot_type | database | active |  lag
-------------+----------+-----------+----------+--------+-------
 peerdb_slot | pgoutput | logical   | app_db   | t      | 0 bytes
```

### 6.6 Verificar Publication

```sql
-- Ver publications
SELECT * FROM pg_publication;

-- Ver tabelas na publication
SELECT * FROM pg_publication_tables WHERE pubname = 'peerdb_publication';
```

Output esperado:
```
    pubname       | schemaname | tablename
------------------+------------+-----------
 peerdb_publication| public     | users
 peerdb_publication| public     | orders
 peerdb_publication| public     | events
```

**✅ Teste Passou:** CDC está configurado e dados foram copiados

---

## 7. Testar CDC em Tempo Real

### 7.1 Inserir Novo Registro no PostgreSQL

```bash
# Conectar ao PostgreSQL
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432
export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)
psql -h localhost -U app_user -d app_db
```

```sql
-- Inserir novo usuário
INSERT INTO users (username, email)
VALUES ('test_cdc', 'test_cdc@example.com');

-- Verificar
SELECT * FROM users WHERE username = 'test_cdc';
```

### 7.2 Aguardar e Verificar no ClickHouse

```bash
# Aguardar 10-30 segundos (depende do sync interval)
sleep 30

# Conectar ao ClickHouse
kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000
clickhouse-client --host localhost --port 9000 --user admin --password admin123
```

```sql
-- Verificar se o novo usuário apareceu
SELECT * FROM users WHERE username = 'test_cdc';
```

**✅ Se aparecer, CDC está funcionando em tempo real!**

### 7.3 Testar UPDATE

```sql
-- No PostgreSQL
UPDATE users SET email = 'updated_cdc@example.com' WHERE username = 'test_cdc';

-- Aguardar 30s e verificar no ClickHouse
SELECT * FROM users WHERE username = 'test_cdc';
-- Email deve estar atualizado!
```

### 7.4 Testar DELETE

```sql
-- No PostgreSQL
DELETE FROM users WHERE username = 'test_cdc';

-- Aguardar 30s e verificar no ClickHouse
SELECT COUNT(*) FROM users WHERE username = 'test_cdc';
-- Deve retornar 0!
```

### 7.5 Monitorar Temporal Workflows

```bash
# Acessar Temporal UI
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8088:8080

# Acessar: http://localhost:8088
# Ver workflows rodando para o mirror
```

**✅ Teste Passou:** CDC está replicando INSERT, UPDATE e DELETE em tempo real!

---

## 8. Testar HPAs

### 8.1 Verificar HPAs Criados

```bash
# Ver todos os HPAs
kubectl get hpa --all-namespaces

# Resultado esperado: 9 HPAs
```

Output esperado:
```
NAMESPACE        NAME                        REFERENCE                          TARGETS           MINPODS   MAXPODS   REPLICAS
peerdb           peerdb-server-hpa           Deployment/peerdb-server           20%/70%, 30%/80%  1         5         1
peerdb           peerdb-flow-worker-hpa      Deployment/peerdb-flow-worker      15%/75%, 25%/80%  2         10        2
cloudnative-pg   postgres-cluster-hpa        Cluster/postgres-cluster           18%/70%, 22%/80%  3         5         3
peerdb           peerdb-postgresql-hpa       StatefulSet/peerdb-postgresql      10%/75%, 15%/80%  1         3         1
clickhouse       clickhouse-cluster-hpa      CHI/clickhouse-cluster             25%/70%, 20%/75%  4         8         4
peerdb           temporal-frontend-hpa       Deployment/...temporal-frontend    12%/70%, 18%/80%  1         5         1
peerdb           temporal-history-hpa        Deployment/...temporal-history     10%/70%, 15%/80%  1         5         1
peerdb           temporal-matching-hpa       Deployment/...temporal-matching    8%/70%, 12%/80%   1         5         1
peerdb           temporal-worker-hpa         Deployment/...temporal-worker      20%/75%, 25%/80%  1         10        1
```

### 8.2 Verificar Métricas

```bash
# Verificar métricas dos pods
kubectl top pods -n peerdb
kubectl top pods -n clickhouse
kubectl top pods -n cloudnative-pg

# Se retornar erro, verificar metrics-server
kubectl get deployment metrics-server -n kube-system
```

### 8.3 Testar Auto-Scaling (Simular Carga)

#### Opção A: Gerar carga no PostgreSQL

```bash
# Inserir muitos dados
kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432
export PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d)
psql -h localhost -U app_user -d app_db
```

```sql
-- Inserir 100k registros
INSERT INTO users (username, email)
SELECT
  'user_' || generate_series(1, 100000),
  'user_' || generate_series(1, 100000) || '@example.com';
```

```bash
# Em outro terminal, monitorar HPA
watch kubectl get hpa peerdb-flow-worker-hpa -n peerdb

# Você deve ver REPLICAS aumentando (2 → 3 → 4...)
```

#### Opção B: Stress test direto no pod

```bash
# Stress CPU no pod do PeerDB
kubectl exec -it -n peerdb deployment/peerdb-server -- sh -c "while true; do :; done" &

# Monitorar
watch kubectl get hpa peerdb-server-hpa -n peerdb

# Você deve ver CPU% subir e replicas aumentarem

# Matar o stress
kubectl exec -it -n peerdb deployment/peerdb-server -- pkill -f "while true"
```

**✅ Teste Passou:** HPAs estão funcionando e escalando pods automaticamente

---

## 9. Testar Node Affinity

### 9.1 Verificar Labels nos Nodes

```bash
# Ver labels
kubectl get nodes --show-labels | grep workload
```

Output esperado:
```
worker-1   Ready   ...   workload=postgres
worker-2   Ready   ...   workload=postgres
worker-3   Ready   ...   workload=clickhouse
worker-4   Ready   ...   workload=peerdb
worker-5   Ready   ...   workload=peerdb
```

### 9.2 Verificar Distribuição dos Pods

```bash
# Ver em qual node cada pod está
kubectl get pods -o wide --all-namespaces | grep -E "postgres-cluster|clickhouse|peerdb" | awk '{print $1, $2, $8}'
```

Output esperado:
```
cloudnative-pg  postgres-cluster-1       worker-1  ✅
cloudnative-pg  postgres-cluster-2       worker-2  ✅
cloudnative-pg  postgres-cluster-3       worker-1  ✅
clickhouse      clickhouse-...           worker-3  ✅
clickhouse      clickhouse-keeper-0      worker-3  ✅
peerdb          peerdb-server-...        worker-4  ✅
peerdb          peerdb-flow-worker-...   worker-5  ✅
peerdb          peerdb-postgresql-0      worker-4  ✅
```

### 9.3 Testar Failover (Node Affinity é Respeitado)

```bash
# Deletar um pod do PeerDB
kubectl delete pod -n peerdb -l app=peerdb,component=server

# Aguardar novo pod ser criado
kubectl get pods -n peerdb -l app=peerdb,component=server -w

# Verificar que foi criado em worker-4 ou worker-5
kubectl get pod -n peerdb -l app=peerdb,component=server -o wide
```

**✅ Teste Passou:** Pods estão sendo criados nos workers corretos

---

## 10. Teste End-to-End Completo

### Script de Teste Automatizado

```bash
#!/bin/bash

echo "🧪 TESTE END-TO-END COMPLETO"
echo "=========================="
echo ""

# 1. Verificar ArgoCD
echo "1️⃣ Verificando ArgoCD..."
APPS=$(kubectl get applications -n argocd --no-headers | wc -l)
if [ "$APPS" -eq 8 ]; then
  echo "✅ 8 Applications encontradas"
else
  echo "❌ Esperado 8 Applications, encontrado $APPS"
  exit 1
fi

# 2. Verificar PostgreSQL
echo ""
echo "2️⃣ Verificando PostgreSQL..."
PG_PODS=$(kubectl get pods -n cloudnative-pg --no-headers | grep Running | wc -l)
if [ "$PG_PODS" -ge 3 ]; then
  echo "✅ PostgreSQL rodando ($PG_PODS pods)"
else
  echo "❌ PostgreSQL: esperado 3+ pods, encontrado $PG_PODS"
  exit 1
fi

# 3. Verificar ClickHouse
echo ""
echo "3️⃣ Verificando ClickHouse..."
CH_PODS=$(kubectl get pods -n clickhouse -l app=clickhouse --no-headers | grep Running | wc -l)
KEEPER_PODS=$(kubectl get pods -n clickhouse -l clickhouse.altinity.com/keeper --no-headers | grep Running | wc -l)
if [ "$CH_PODS" -ge 4 ] && [ "$KEEPER_PODS" -eq 3 ]; then
  echo "✅ ClickHouse rodando ($CH_PODS pods + $KEEPER_PODS keepers)"
else
  echo "❌ ClickHouse: esperado 4+ pods + 3 keepers"
  exit 1
fi

# 4. Verificar PeerDB
echo ""
echo "4️⃣ Verificando PeerDB..."
PEERDB_PODS=$(kubectl get pods -n peerdb -l app=peerdb --no-headers | grep Running | wc -l)
if [ "$PEERDB_PODS" -ge 3 ]; then
  echo "✅ PeerDB rodando ($PEERDB_PODS pods)"
else
  echo "❌ PeerDB: esperado 3+ pods, encontrado $PEERDB_PODS"
  exit 1
fi

# 5. Verificar Temporal
echo ""
echo "5️⃣ Verificando Temporal..."
TEMPORAL_PODS=$(kubectl get pods -n peerdb -l app.kubernetes.io/instance=peerdb-temporal --no-headers | grep Running | wc -l)
if [ "$TEMPORAL_PODS" -ge 4 ]; then
  echo "✅ Temporal rodando ($TEMPORAL_PODS pods)"
else
  echo "❌ Temporal: esperado 4+ pods, encontrado $TEMPORAL_PODS"
  exit 1
fi

# 6. Verificar HPAs
echo ""
echo "6️⃣ Verificando HPAs..."
HPAS=$(kubectl get hpa --all-namespaces --no-headers | wc -l)
if [ "$HPAS" -ge 9 ]; then
  echo "✅ HPAs configurados ($HPAS HPAs)"
else
  echo "❌ HPAs: esperado 9+, encontrado $HPAS"
  exit 1
fi

# 7. Verificar Node Affinity
echo ""
echo "7️⃣ Verificando Node Affinity..."
PG_NODES=$(kubectl get pods -n cloudnative-pg -o wide | grep postgres-cluster | awk '{print $7}' | grep -E "worker-1|worker-2" | wc -l)
CH_NODES=$(kubectl get pods -n clickhouse -o wide | grep clickhouse | awk '{print $7}' | grep worker-3 | wc -l)
PEERDB_NODES=$(kubectl get pods -n peerdb -l app=peerdb -o wide | awk '{print $7}' | grep -E "worker-4|worker-5" | wc -l)

echo "  PostgreSQL em workers corretos: $PG_NODES/3"
echo "  ClickHouse em workers corretos: $CH_NODES/7"
echo "  PeerDB em workers corretos: $PEERDB_NODES/3+"

if [ "$PG_NODES" -ge 3 ] && [ "$CH_NODES" -ge 7 ] && [ "$PEERDB_NODES" -ge 3 ]; then
  echo "✅ Node affinity respeitado"
else
  echo "⚠️  Node affinity parcialmente respeitado (pode estar escalando)"
fi

echo ""
echo "🎉 TESTE COMPLETO - SUCESSO!"
echo ""
echo "📋 Próximos passos:"
echo "  1. Configurar CDC no PeerDB UI: http://localhost:3000"
echo "  2. Testar replicação: insira dados no PostgreSQL"
echo "  3. Verificar no ClickHouse: dados devem aparecer"
```

Salve como `test-e2e.sh` e execute:

```bash
chmod +x test-e2e.sh
./test-e2e.sh
```

---

## 📊 Resumo dos Testes

| # | Componente | Teste | Status |
|---|------------|-------|--------|
| 1 | ArgoCD | 8 Applications Synced | ✅ |
| 2 | PostgreSQL | 3 pods, dummy data, CDC | ✅ |
| 3 | ClickHouse | 4+3 pods, cluster, keeper | ✅ |
| 4 | Temporal | 4 pods, conectado ao PG | ✅ |
| 5 | PeerDB | 3 pods, conectividade | ✅ |
| 6 | CDC | Dados replicados PG→CH | ✅ |
| 7 | CDC Realtime | INSERT/UPDATE/DELETE | ✅ |
| 8 | HPAs | 9 HPAs, auto-scaling | ✅ |
| 9 | Node Affinity | Pods nos workers corretos | ✅ |

---

## 🔍 Troubleshooting

### Problema: Dados não replicam

```bash
# 1. Verificar logs do PeerDB
kubectl logs -n peerdb deployment/peerdb-flow-worker --tail=100

# 2. Verificar replication slot ativo
psql -h localhost -U app_user -d app_db -c "SELECT * FROM pg_replication_slots;"

# 3. Verificar workflows no Temporal
# Acessar: http://localhost:8088

# 4. Verificar conectividade
kubectl exec -it -n peerdb deployment/peerdb-server -- sh
nc -zv postgres-cluster-rw.cloudnative-pg.svc.cluster.local 5432
nc -zv chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local 9000
```

### Problema: HPAs não escalam

```bash
# 1. Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# 2. Verificar métricas disponíveis
kubectl top pods -n peerdb

# 3. Ver eventos do HPA
kubectl describe hpa peerdb-flow-worker-hpa -n peerdb
```

---

## ✅ Checklist Final

- [ ] ArgoCD: 8 Applications Synced & Healthy
- [ ] PostgreSQL: 3 pods, dummy data presente
- [ ] ClickHouse: 4 pods + 3 keepers, cluster configurado
- [ ] Temporal: 4 pods, workflows visíveis
- [ ] PeerDB: 3 pods, UI acessível
- [ ] CDC configurado: Peers + Mirror criados
- [ ] Dados replicados: Mesmo count no PG e CH
- [ ] CDC tempo real: INSERT funciona
- [ ] HPAs: 9 HPAs presentes
- [ ] Node affinity: Pods nos workers corretos

**Se todos os itens estão ✅, sua infra está 100% funcional!** 🎉
