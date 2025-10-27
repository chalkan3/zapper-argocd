# Configuração do PeerDB para CDC

Este guia detalha como configurar o PeerDB para realizar CDC (Change Data Capture) do PostgreSQL para o ClickHouse.

## Pré-requisitos

1. Todas as aplicações deployadas e saudáveis
2. Port-forward do PeerDB ativo: `make port-forward-peerdb`

## Obter Credenciais

### PostgreSQL (CloudNativePG)

```bash
# Usuário
echo "app_user"

# Senha
kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d

# Host interno (para PeerDB)
echo "postgres-cluster-rw.cloudnative-pg.svc.cluster.local"

# Database
echo "app_db"

# Port
echo "5432"
```

### ClickHouse

```bash
# Usuário
echo "admin"

# Senha
echo "admin123"

# Host interno (para PeerDB)
echo "clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local"

# Port HTTP
echo "8123"

# Port Native
echo "9000"
```

## Passo 1: Acessar Interface do PeerDB

1. Execute o port-forward:
```bash
make port-forward-peerdb
```

2. Acesse http://localhost:3000 no navegador

## Passo 2: Criar PostgreSQL Peer (Source)

1. No PeerDB UI, vá para "Peers" → "Add Peer"
2. Selecione "PostgreSQL"
3. Preencha os campos:
   - **Name**: `postgres-source`
   - **Host**: `postgres-cluster-rw.cloudnative-pg.svc.cluster.local`
   - **Port**: `5432`
   - **Database**: `app_db`
   - **User**: `app_user`
   - **Password**: [senha obtida acima]
   - **Enable SSL**: Desabilitado (false)

4. Clique em "Test Connection"
5. Se OK, clique em "Create Peer"

## Passo 3: Criar ClickHouse Peer (Destination)

1. No PeerDB UI, vá para "Peers" → "Add Peer"
2. Selecione "ClickHouse"
3. Preencha os campos:
   - **Name**: `clickhouse-destination`
   - **Host**: `clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local`
   - **Port**: `9000` (Native protocol)
   - **Database**: `default`
   - **User**: `admin`
   - **Password**: `admin123`
   - **Enable SSL**: Desabilitado (false)

4. Clique em "Test Connection"
5. Se OK, clique em "Create Peer"

## Passo 4: Criar Mirror (CDC)

1. No PeerDB UI, vá para "Mirrors" → "Create Mirror"
2. Preencha os campos:

### Configuração Básica
   - **Mirror Name**: `pg-to-ch-mirror`
   - **Source Peer**: `postgres-source`
   - **Destination Peer**: `clickhouse-destination`

### Configuração de Tabelas
Adicione as seguintes tabelas para replicação:

#### Tabela 1: users
   - **Source Schema**: `public`
   - **Source Table**: `users`
   - **Destination Schema**: `default`
   - **Destination Table**: `users`

#### Tabela 2: orders
   - **Source Schema**: `public`
   - **Source Table**: `orders`
   - **Destination Schema**: `default`
   - **Destination Table**: `orders`

#### Tabela 3: events
   - **Source Schema**: `public`
   - **Source Table**: `events`
   - **Destination Schema**: `default`
   - **Destination Table**: `events`

### Opções Avançadas
   - **Sync Mode**: `CDC` (Change Data Capture)
   - **Initial Snapshot**: Habilitado (true)
   - **Publication Name**: `peerdb_publication`
   - **Replication Slot Name**: `peerdb_slot`
   - **Batch Size**: `10000`
   - **Sync Interval**: `30s`

3. Clique em "Create Mirror"

## Passo 5: Verificar Replicação

### Verificar Status no PeerDB

1. Vá para "Mirrors" no PeerDB UI
2. Veja o status do mirror `pg-to-ch-mirror`
3. Deve mostrar:
   - Status: `Running` ou `Syncing`
   - Rows Synced: número crescente
   - Last Sync: timestamp recente

### Verificar Dados no ClickHouse

```bash
# Port-forward ClickHouse
make port-forward-clickhouse

# Em outro terminal, conecte ao ClickHouse
clickhouse-client --host localhost --port 9000 --user admin --password admin123

# Verificar dados
SELECT * FROM users LIMIT 10;
SELECT * FROM orders LIMIT 10;
SELECT * FROM events LIMIT 10;

# Verificar contagem
SELECT 'users' as table, count(*) as count FROM users
UNION ALL
SELECT 'orders' as table, count(*) as count FROM orders
UNION ALL
SELECT 'events' as table, count(*) as count FROM events;
```

### Testar CDC em Tempo Real

```bash
# Port-forward PostgreSQL
make port-forward-postgres

# Em outro terminal, conecte ao PostgreSQL
PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
psql -h localhost -U app_user -d app_db

# Inserir novos dados
INSERT INTO users (username, email) VALUES ('test_user', 'test@example.com');
INSERT INTO orders (user_id, product_name, quantity, amount) VALUES (1, 'Test Product', 1, 99.99);

# Aguardar alguns segundos e verificar no ClickHouse
# Os dados devem aparecer automaticamente
```

## Troubleshooting

### Mirror não inicia

```bash
# Verificar logs do PeerDB
kubectl logs -n peerdb -l app=peerdb --tail=100

# Verificar logs do flow-worker
kubectl logs -n peerdb -l component=flow-worker --tail=100

# Verificar logs do Temporal
kubectl logs -n peerdb -l app.kubernetes.io/name=temporal --tail=100
```

### Dados não estão sendo replicados

1. Verificar se o PostgreSQL tem logical replication habilitado:
```bash
kubectl exec -n cloudnative-pg postgres-cluster-1 -- psql -U app_user -d app_db -c "SHOW wal_level;"
# Deve retornar "logical"
```

2. Verificar publication e slot:
```bash
kubectl exec -n cloudnative-pg postgres-cluster-1 -- psql -U app_user -d app_db -c "SELECT * FROM pg_publication;"
kubectl exec -n cloudnative-pg postgres-cluster-1 -- psql -U app_user -d app_db -c "SELECT * FROM pg_replication_slots;"
```

3. Verificar conectividade:
```bash
# Do pod do PeerDB para PostgreSQL
kubectl exec -n peerdb deployment/peerdb-server -- nc -zv postgres-cluster-rw.cloudnative-pg.svc.cluster.local 5432

# Do pod do PeerDB para ClickHouse
kubectl exec -n peerdb deployment/peerdb-server -- nc -zv clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local 9000
```

### Performance issues

1. Aumentar batch size no mirror
2. Ajustar sync interval
3. Escalar flow-workers:
```bash
kubectl scale deployment -n peerdb peerdb-flow-worker --replicas=4
```

## Monitoramento

### Métricas importantes

- **Lag**: Diferença entre última mudança no PG e última replicação
- **Throughput**: Número de rows por segundo sendo replicadas
- **Errors**: Qualquer erro de replicação

### Dashboard do Temporal

```bash
kubectl port-forward -n peerdb svc/peerdb-dependencies-temporal-web 8088:8080
```

Acesse http://localhost:8088 para ver workflows do Temporal

## Limpeza

Para remover o mirror:

1. No PeerDB UI, vá para o mirror
2. Clique em "Delete Mirror"
3. Confirme a exclusão

Isso irá:
- Parar a replicação
- Remover o replication slot do PostgreSQL
- Remover a publication do PostgreSQL
- Manter os dados já replicados no ClickHouse
