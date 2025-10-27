# ArgoCD Applications

Este diretório contém todas as ArgoCD Applications que compõem a infraestrutura Zapper.

## Ordem de Deploy (Prefixos Numéricos)

Os arquivos são nomeados com **prefixos numéricos** para garantir ordem de aplicação correta, mesmo quando o Pulumi aplica em sequência aleatória.

### Ordem de Aplicação:

1. **`01-clickhouse-operator.yaml`** - ClickHouse Operator + Cluster
2. **`02-cloudnative-pg-operator.yaml`** - CloudNativePG Operator + PostgreSQL Cluster
3. **`03-peerdb-dependencies.yaml`** - PeerDB PostgreSQL + Temporal
4. **`04-peerdb.yaml`** - PeerDB Application
5. **`05-hpa.yaml`** - Horizontal Pod Autoscalers
6. **`06-monitoring.yaml`** - Prometheus + Grafana Stack + ServiceMonitors
7. **`07-peerdb-setup.yaml`** - PeerDB CDC Mirror Setup Job

## Aplicação via Pulumi

O Pulumi aplicará os arquivos em **ordem alfabética** devido aos prefixos numéricos:

```python
import pulumi_kubernetes as k8s
from pathlib import Path
import glob

# Listar arquivos em ordem
yaml_files = sorted(glob.glob("apps/*.yaml"))

# Aplicar em sequência
for yaml_file in yaml_files:
    k8s.yaml.ConfigFile(
        Path(yaml_file).stem,  # Nome sem extensão
        file=yaml_file
    )
```

**IMPORTANTE**: Mesmo que o Pulumi aplique arquivos aleatoriamente, os nomes garantem ordem alfabética correta:
- `01-*` será aplicado antes de `02-*`
- `02-*` será aplicado antes de `03-*`
- E assim por diante...

As **sync waves** dentro de cada arquivo também garantem ordem interna (operators antes de clusters).

## Estrutura dos Arquivos

Cada arquivo pode conter múltiplas Applications (separadas por `---`):

- **01-clickhouse-operator.yaml**: 2 Applications (operator + cluster)
- **02-cloudnative-pg-operator.yaml**: 2 Applications (operator + cluster)
- **03-peerdb-dependencies.yaml**: 2 Applications (postgresql + temporal)
- **04-peerdb.yaml**: 1 Application
- **05-hpa.yaml**: 1 Application
- **06-monitoring.yaml**: 2 Applications (kube-prometheus-stack + servicemonitors)
- **07-peerdb-setup.yaml**: 1 Application

Total: **11 ArgoCD Applications**

## Verificação

Após aplicar via Pulumi, verificar status:

```bash
kubectl get applications -n argocd
kubectl get applications -n argocd -w  # Watch mode
```

## Dependências

A ordem numérica dos arquivos garante as seguintes dependências:

```
01-clickhouse-operator.yaml
    ├─> clickhouse-operator (wave 1)
    └─> clickhouse-cluster (wave 2)

02-cloudnative-pg-operator.yaml
    ├─> cloudnative-pg-operator (wave 1)
    └─> postgres-cluster (wave 2)

03-peerdb-dependencies.yaml (depende de 01, 02)
    ├─> peerdb-postgresql (wave 2)
    └─> peerdb-temporal (wave 2)

04-peerdb.yaml (depende de 03)
    └─> peerdb (wave 3)

05-hpa.yaml (depende de 01, 02, 04)
    └─> hpa (wave 3)

06-monitoring.yaml (depende de 04)
    ├─> kube-prometheus-stack (wave 3)
    └─> monitoring-servicemonitors (wave 4)

07-peerdb-setup.yaml (depende de 01, 02, 04)
    └─> peerdb-setup (wave 4)
```

## Rollback

Para reverter todas as Applications:

```bash
pulumi destroy
# ou manualmente:
kubectl delete applications -n argocd --all
```
