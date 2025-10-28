# CDC Pipeline - 100% Automated Deployment

Este documento descreve toda a automação implementada para deployment do pipeline CDC PostgreSQL → PeerDB → ClickHouse.

## 🎯 Objetivo

Deploy 100% automático via ArgoCD GitOps, sem nenhuma intervenção manual necessária.

## 📋 Ordem de Deploy (Sync Waves)

### Wave 0: CRDs
- CloudNativePG Pooler CRD (required before operator)

### Wave 1: Operators
- CloudNativePG Operator (with standard CRDs)
- ClickHouse Operator (Altinity)

### Wave 2: Infrastructure
- **MinIO**: S3-compatible storage para staging de CDC
  - Bucket `peerdb-staging` criado automaticamente
- **PeerDB PostgreSQL**: Metadata store do PeerDB
  - Databases: `peerdb_metadata`, `temporal`, `temporal_visibility`
- **Temporal**: Workflow orchestration
  - Frontend, History, Matching, Worker, Web, Admin Tools

### Wave 3: Applications
- **PostgreSQL Cluster** (CloudNativePG)
  - 3 réplicas com replicação lógica (wal_level=logical)
  - **Automações**:
    - ✅ Criação automática de tabelas (users, orders, events)
    - ✅ Configuração de REPLICA IDENTITY FULL
    - ✅ Criação de índices
    - ✅ **REPLICATION permission** para app_user (`ALTER USER app_user WITH REPLICATION`)
    - ✅ **Table ownership** transferido para app_user (required for CDC publications)
    - ✅ **Sequence ownership** transferido para app_user

- **ClickHouse Cluster**
  - 2 shards para analytics distribuído

- **PeerDB Components**
  - `peerdb-server`: SQL interface (porta 9900)
  - `peerdb-flow-api`: gRPC/HTTP API (portas 8112/8113)
  - `peerdb-flow-worker`: CDC workers
  - `peerdb-ui`: Web UI + REST API (porta 3000)
  - **Variáveis de ambiente**:
    - `AWS_SDK_LOAD_CONFIG=false` - Desabilita lookup de AWS credentials
    - `AWS_EC2_METADATA_DISABLED=true` - Desabilita EC2 IMDS

- **Temporal Search Attributes**
  - Job automático adiciona `MirrorName` search attribute
  - Executado via tctl no admintools pod

### Wave 4: Setup & Configuration
- **PeerDB Setup Mirror Job**
  - Aguarda todos os serviços estarem prontos (PostgreSQL, ClickHouse, PeerDB UI)
  - Cria PostgreSQL peer via REST API
  - Cria ClickHouse peer com MinIO S3 via REST API
  - Cria CDC mirror `pg_to_ch_mirror` via REST API
  - Tabelas: users, orders, events

## 🔧 Configurações Automáticas

### PostgreSQL (CloudNativePG)

```yaml
postInitApplicationSQL:
  # Criação de tabelas
  - CREATE TABLE users (...)
  - CREATE TABLE orders (...)
  - CREATE TABLE events (...)

  # CDC Configuration
  - ALTER TABLE users REPLICA IDENTITY FULL
  - ALTER TABLE orders REPLICA IDENTITY FULL
  - ALTER TABLE events REPLICA IDENTITY FULL

  # Permissions
  - GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user
  - GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user

  # REPLICATION (critical for CDC)
  - ALTER USER app_user WITH REPLICATION

  # Table Ownership (critical for CDC publications)
  - ALTER TABLE users OWNER TO app_user
  - ALTER TABLE orders OWNER TO app_user
  - ALTER TABLE events OWNER TO app_user
  - ALTER SEQUENCE users_id_seq OWNER TO app_user
  - ALTER SEQUENCE orders_id_seq OWNER TO app_user
  - ALTER SEQUENCE events_id_seq OWNER TO app_user
```

### PeerDB REST API Calls

#### PostgreSQL Peer
```bash
curl -X POST "http://peerdb-ui:3000/api/v1/peers/create" \
  -H "Authorization: Basic OnBlZXJkYg==" \
  -d '{
    "peer": {
      "name": "postgres_source",
      "type": 3,
      "postgres_config": {
        "host": "postgres-cluster-rw.cloudnative-pg.svc.cluster.local",
        "port": 5432,
        "user": "app_user",
        "password": "<from-secret>",
        "database": "app_db"
      }
    }
  }'
```

#### ClickHouse Peer com MinIO
```bash
curl -X POST "http://peerdb-ui:3000/api/v1/peers/create" \
  -H "Authorization: Basic OnBlZXJkYg==" \
  -d '{
    "peer": {
      "name": "clickhouse_destination",
      "type": 8,
      "clickhouse_config": {
        "host": "chi-clickhouse-cluster-main-cluster-0-0.clickhouse.svc.cluster.local",
        "port": 9000,
        "user": "admin",
        "password": "admin123",
        "database": "default",
        "disable_tls": true,
        "s3_path": "peerdb-staging",
        "access_key_id": "minioadmin",
        "secret_access_key": "minioadmin",
        "region": "us-east-1",
        "endpoint": "http://minio.minio.svc.cluster.local:9000"
      }
    }
  }'
```

#### CDC Mirror
```bash
curl -X POST "http://peerdb-ui:3000/api/v1/flows/cdc/create" \
  -H "Authorization: Basic OnBlZXJkYg==" \
  -d '{
    "connection_configs": {
      "flow_job_name": "pg_to_ch_mirror",
      "source_name": "postgres_source",
      "destination_name": "clickhouse_destination",
      "table_mappings": [
        {
          "source_table_identifier": "public.users",
          "destination_table_identifier": "default.users"
        },
        {
          "source_table_identifier": "public.orders",
          "destination_table_identifier": "default.orders"
        },
        {
          "source_table_identifier": "public.events",
          "destination_table_identifier": "default.events"
        }
      ],
      "do_initial_snapshot": true,
      "max_batch_size": 1000000,
      "idle_timeout_seconds": 60
    }
  }'
```

## 🚀 Como Usar

### Deploy Completo
```bash
# 1. Apply all ArgoCD applications
kubectl apply -f apps/

# 2. Aguardar sync automático
# Todos os componentes serão deployados automaticamente seguindo as sync waves

# 3. Verificar status
kubectl get applications -n argocd
kubectl get pods -n cloudnative-pg
kubectl get pods -n clickhouse
kubectl get pods -n minio
kubectl get pods -n peerdb
```

### Verificar CDC Funcionando
```bash
# Ver dados no PostgreSQL
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U postgres -d app_db -c "SELECT COUNT(*) FROM users;"

# Ver dados no ClickHouse (após sincronização inicial)
kubectl exec -n clickhouse chi-clickhouse-cluster-main-cluster-0-0-0 -c clickhouse -- \
  clickhouse-client -q "SELECT COUNT(*) FROM default.users"

# Ver logs do PeerDB
kubectl logs -n peerdb -l component=flow-worker
```

## ✅ Checklist de Automação

- [x] PostgreSQL cluster com WAL logical replication
- [x] Tabelas criadas automaticamente
- [x] **REPLICATION permission** concedida automaticamente
- [x] **Table ownership** configurado automaticamente
- [x] ClickHouse cluster deployado
- [x] MinIO S3 storage deployado
- [x] MinIO bucket criado automaticamente
- [x] Temporal deployado com databases
- [x] **Temporal search attributes** configurados automaticamente
- [x] PeerDB components deployados
- [x] **AWS metadata disabled** nas env vars
- [x] PostgreSQL peer criado via REST API
- [x] ClickHouse peer criado via REST API com MinIO
- [x] CDC mirror criado via REST API
- [x] Seed data inserido automaticamente

## 🔍 Troubleshooting

### Ver logs do setup job
```bash
kubectl logs -n peerdb -l job-name=peerdb-setup-mirror
```

### Ver status do CDC mirror
```bash
# Via PeerDB UI (port-forward primeiro)
kubectl port-forward -n peerdb svc/peerdb-ui 3000:3000

# Acessar: http://localhost:3000
# Login: peerdb / peerdb
```

### Recriar o setup job
```bash
kubectl delete job -n peerdb peerdb-setup-mirror
# ArgoCD vai recriar automaticamente
```

## 📊 Fluxo de Dados

```
PostgreSQL (app_db)
  ├─ users (10 registros)
  ├─ orders (26 registros)
  └─ events (30 registros)
         ↓ (CDC via PeerDB)
    MinIO (staging)
      └─ bucket: peerdb-staging
         ↓
ClickHouse (default)
  ├─ users
  ├─ orders
  └─ events
```

## 🎯 Zero Manual Steps!

Todo o pipeline é configurado automaticamente via ArgoCD GitOps. Basta fazer `kubectl apply -f apps/` e aguardar!
