# PeerDB CDC Setup

## Componentes Deployados Automaticamente

✅ **PeerDB Server** - UI e API em `peerdb-server:9900`
✅ **PeerDB Flow Worker** - Workers para processar CDC
✅ **PeerDB Temporal** - Temporal para orquestração de workflows
✅ **PostgreSQL Source** - Cluster CloudNativePG com dados de teste
✅ **ClickHouse Destination** - Cluster com 2 shards

## Configuração do Mirror CDC (Manual)

O mirror CDC precisa ser configurado manualmente via PeerDB UI após o deploy.

### 1. Acesse a PeerDB UI

```bash
kubectl port-forward -n peerdb svc/peerdb-server 9900:9900
```

Acesse: http://localhost:9900

### 2. Crie o Peer PostgreSQL (Source)

- **Nome**: `postgres-source`
- **Tipo**: PostgreSQL
- **Host**: `postgres-cluster-rw.cloudnative-pg.svc.cluster.local`
- **Port**: `5432`
- **Database**: `app_db`
- **User**: `app_user`
- **Password**: `apppassword123` (do secret `postgres-cluster-app`)

### 3. Crie o Peer ClickHouse (Destination)

- **Nome**: `clickhouse-destination`
- **Tipo**: ClickHouse
- **Host**: `chi-clickhouse-cluster-main-cluster-0-0.clickhouse.svc.cluster.local`
- **Port**: `9000`
- **Database**: `default`
- **User**: `admin`
- **Password**: `admin123`

### 4. Crie o Mirror CDC

- **Nome**: `pg-to-ch-mirror`
- **Source Peer**: `postgres-source`
- **Destination Peer**: `clickhouse-destination`
- **Tables**: `public.users`, `public.orders`, `public.events`
- **Mode**: CDC (Change Data Capture)
- **Initial Snapshot**: Enabled

## Dados de Teste

O PostgreSQL já contém dados de teste criados automaticamente:

- **users**: 10 registros
- **orders**: 26 registros
- **events**: 30 registros

## Verificar Replicação

### PostgreSQL (Source)

```bash
kubectl exec -n cloudnative-pg postgres-cluster-1 -c postgres -- \
  psql -U postgres -d app_db -c "SELECT COUNT(*) FROM users;"
```

### ClickHouse (Destination)

```bash
kubectl exec -n clickhouse chi-clickhouse-cluster-main-cluster-0-0-0 -c clickhouse -- \
  clickhouse-client --query "SELECT COUNT(*) FROM default.users"
```

## Testar CDC em Tempo Real

### Inserir dados no PostgreSQL

```bash
kubectl exec -n cloudnative-pg postgres-cluster-1 -c postgres -- \
  psql -U postgres -d app_db -c \
  "INSERT INTO users (username, email) VALUES ('test_user', 'test@example.com');"
```

### Verificar replicação no ClickHouse

```bash
kubectl exec -n clickhouse chi-clickhouse-cluster-main-cluster-0-0-0 -c clickhouse -- \
  clickhouse-client --query "SELECT * FROM default.users WHERE username='test_user'"
```

## Troubleshooting

### PeerDB Logs

```bash
kubectl logs -n peerdb -l component=server --tail=100
kubectl logs -n peerdb -l component=flow-worker --tail=100
```

### Temporal Logs

```bash
kubectl logs -n peerdb -l app.kubernetes.io/component=frontend --tail=100
```

### PostgreSQL Replication Slots

```bash
kubectl exec -n cloudnative-pg postgres-cluster-1 -c postgres -- \
  psql -U postgres -c "SELECT * FROM pg_replication_slots;"
```
