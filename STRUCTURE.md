# Estrutura do Repositório GitOps

## Visão Geral

Este repositório implementa GitOps usando **Helm charts oficiais** gerenciados pelo ArgoCD.

## Diretórios

### `/apps/`

Contém as **ArgoCD Applications** que definem o que será deployado.

Cada arquivo YAML cria uma ou mais Applications no ArgoCD que:
- Apontam para Helm charts oficiais OU
- Apontam para manifestos customizados neste repositório

#### Arquivos:

**`clickhouse.yaml`** (2 Applications)
- `clickhouse-operator`: Helm chart `altinity/clickhouse-operator`
- `clickhouse-cluster`: Manifests CRD do repositório (`helm-values/clickhouse-cluster.yaml`)

**`cloudnative-pg.yaml`** (2 Applications)
- `cloudnative-pg-operator`: Helm chart `cloudnative-pg/cloudnative-pg`
- `postgres-cluster`: Manifests CRD do repositório (`helm-values/postgres-cluster.yaml`)

**`peerdb-dependencies.yaml`** (2 Applications)
- `peerdb-postgresql`: Helm chart `bitnami/postgresql`
- `peerdb-temporal`: Helm chart `temporal/temporal`

**`peerdb.yaml`** (1 Application)
- `peerdb`: Manifests customizados (`manifests/peerdb/`)

### `/helm-values/`

Valores customizados e CRDs (Custom Resource Definitions) para configuração dos clusters.

- **`clickhouse-cluster.yaml`**: Define o cluster ClickHouse (ClickHouseInstallation + ClickHouseKeeperInstallation CRDs)
- **`postgres-cluster.yaml`**: Define o cluster PostgreSQL (Cluster CRD do CloudNativePG)

Estes arquivos são aplicados pelo ArgoCD como **directory sources**.

### `/manifests/`

Manifests Kubernetes puros (YAML) para componentes sem Helm chart oficial.

- **`peerdb/`**: Deployment e Service do PeerDB
  - `deployment.yaml`: PeerDB server + flow-workers
  - `service.yaml`: Service ClusterIP

### `/bootstrap/`

Scripts e manifests para instalação inicial do ArgoCD.

- **`argocd-install.yaml`**: Namespace + Application para bootstrap do ArgoCD

### Root

- **`Makefile`**: Comandos úteis para gerenciamento
- **`quickstart.sh`**: Script de instalação rápida
- **`.gitignore`**: Arquivos ignorados pelo Git

## Documentação

- **`README.md`**: Guia principal de instalação
- **`ARCHITECTURE.md`**: Arquitetura detalhada do sistema
- **`PEERDB_SETUP.md`**: Configuração do CDC com PeerDB
- **`CHECKLIST.md`**: Checklist de validação
- **`STRUCTURE.md`**: Este arquivo

## Fluxo de Deploy

### 1. ArgoCD lê as Applications em `/apps/`

```
apps/clickhouse.yaml → ArgoCD cria 2 Applications
apps/cloudnative-pg.yaml → ArgoCD cria 2 Applications
apps/peerdb-dependencies.yaml → ArgoCD cria 2 Applications
apps/peerdb.yaml → ArgoCD cria 1 Application
```

### 2. ArgoCD processa cada Application

Para Applications com **Helm charts**:
```
Application → Helm Repo → Download Chart → Apply com values inline
```

Para Applications com **directory sources**:
```
Application → Git Repo → Lê arquivos YAML → Apply no cluster
```

### 3. Operators criam recursos

```
ClickHouse Operator → Lê ClickHouseInstallation CRD → Cria StatefulSets
CloudNativePG Operator → Lê Cluster CRD → Cria PostgreSQL Cluster
```

## Helm Charts Oficiais Utilizados

| Componente | Chart | Versão | Repository |
|------------|-------|--------|------------|
| ClickHouse Operator | `altinity-clickhouse-operator` | 0.23.6 | https://docs.altinity.com/clickhouse-operator/ |
| CloudNativePG | `cloudnative-pg` | 0.21.6 | https://cloudnative-pg.github.io/charts |
| PostgreSQL | `postgresql` | 15.5.20 | https://charts.bitnami.com/bitnami |
| Temporal | `temporal` | 0.45.1 | https://go.temporal.io/helm-charts |

## Custom Resources (CRDs)

### ClickHouse

**ClickHouseInstallation** (`helm-values/clickhouse-cluster.yaml`)
```yaml
apiVersion: clickhouse.altinity.com/v1
kind: ClickHouseInstallation
metadata:
  name: clickhouse-cluster
spec:
  configuration:
    clusters:
      - name: clickhouse-cluster
        layout:
          shardsCount: 2
          replicasCount: 2
```

**ClickHouseKeeperInstallation** (`helm-values/clickhouse-cluster.yaml`)
```yaml
apiVersion: clickhouse.altinity.com/v1
kind: ClickHouseKeeperInstallation
metadata:
  name: clickhouse-keeper
spec:
  clusters:
    - name: keeper-cluster
      layout:
        replicasCount: 3
```

### CloudNativePG

**Cluster** (`helm-values/postgres-cluster.yaml`)
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
spec:
  instances: 3
  postgresql:
    parameters:
      wal_level: logical
```

## Vantagens desta Abordagem

### ✅ Usa Helm Charts Oficiais

- Manutenção pelos autores originais
- Atualizações de segurança automáticas
- Melhores práticas incorporadas
- Comunidade ativa

### ✅ Customização via Values

- Values inline nos Applications
- Fácil de versionar e revisar
- Sem necessidade de manter charts locais

### ✅ CRDs Separados

- Configurações complexas em arquivos dedicados
- Fácil de editar e visualizar
- GitOps completo

### ✅ Operators Pattern

- ClickHouse Operator gerencia todo o lifecycle
- CloudNativePG gerencia PostgreSQL
- Self-healing automático
- Updates rolling

## Modificando Configurações

### Para alterar valores de Helm charts:

1. Edite o arquivo em `apps/*.yaml`
2. Modifique a seção `helm.values`
3. Commit e push
4. ArgoCD sincroniza automaticamente

Exemplo:
```yaml
# apps/peerdb-dependencies.yaml
source:
  chart: postgresql
  helm:
    values: |
      auth:
        password: NOVA_SENHA  # ← Modificar aqui
```

### Para alterar CRDs:

1. Edite o arquivo em `helm-values/*.yaml`
2. Modifique as configurações desejadas
3. Commit e push
4. ArgoCD sincroniza automaticamente

Exemplo:
```yaml
# helm-values/clickhouse-cluster.yaml
layout:
  shardsCount: 4  # ← Aumentar shards
  replicasCount: 3  # ← Aumentar réplicas
```

### Para alterar PeerDB:

1. Edite os manifests em `manifests/peerdb/`
2. Commit e push
3. ArgoCD sincroniza automaticamente

## Adicionando Novas Aplicações

### Com Helm Chart oficial:

1. Adicione nova Application em `apps/`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minha-app
spec:
  source:
    repoURL: https://charts.example.com
    chart: minha-app
    targetRevision: 1.0.0
    helm:
      values: |
        # values aqui
```

2. Apply: `kubectl apply -f apps/minha-app.yaml`

### Com manifests customizados:

1. Crie diretório: `manifests/minha-app/`
2. Adicione YAMLs: `deployment.yaml`, `service.yaml`, etc.
3. Crie Application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minha-app
spec:
  source:
    repoURL: https://github.com/user/repo.git
    path: manifests/minha-app
```

4. Apply: `kubectl apply -f apps/minha-app.yaml`

## Namespaces

Cada componente tem seu próprio namespace:

- `argocd`: ArgoCD
- `clickhouse`: ClickHouse Operator + Cluster + Keeper
- `cloudnative-pg`: CloudNativePG Operator + PostgreSQL Cluster
- `peerdb`: PostgreSQL (metadata) + Temporal + PeerDB

Namespaces são criados automaticamente via `syncOptions.CreateNamespace=true`.

## Conclusão

Esta estrutura combina:
- ✅ Helm charts oficiais (melhor suporte)
- ✅ GitOps completo (versionamento)
- ✅ Customização flexível (values + CRDs)
- ✅ Operators (automação)
- ✅ ArgoCD (sync automático)

Resultado: Infraestrutura como código, mantida e auditável.
