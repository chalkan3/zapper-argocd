# Troubleshooting Guide - Zapper ArgoCD

Este documento contém soluções para problemas comuns do projeto.

---

## 🔍 ArgoCD Sync Status "Unknown"

### Problema

```bash
kubectl get applications -n argocd
# NAME              SYNC STATUS   HEALTH STATUS
# clickhouse        Unknown       Healthy
# postgres          Unknown       Healthy
```

### Causa

O status `Unknown` ocorre quando:
1. Recursos foram criados manualmente (`kubectl apply`) antes do ArgoCD
2. ArgoCD não consegue comparar o estado do Git com o cluster
3. Application foi criada após os recursos já existirem

### Solução 1: Force Sync (Recomendado)

```bash
# Forçar sync de todas Applications
kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'

# Ou manualmente para cada app
argocd app sync clickhouse-operator --force
argocd app sync cloudnative-pg-operator --force
argocd app sync peerdb --force
```

### Solução 2: Hard Refresh

```bash
# Hard refresh para recalcular estado
kubectl patch application clickhouse-operator -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Para todas Applications
kubectl get applications -n argocd -o name | \
  xargs -I {} kubectl patch {} -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Solução 3: Recriar Applications (Última Opção)

⚠️ **CUIDADO:** Isso vai deletar e recriar as Applications (não os recursos reais)

```bash
# 1. Backup das Applications
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# 2. Deletar Applications (SEM deletar recursos)
kubectl delete applications -n argocd --all

# 3. Reaplicar do Git
kubectl apply -f apps/

# 4. Aguardar ArgoCD reconciliar
kubectl get applications -n argocd -w
```

### Solução 4: Annotation para Auto-Sync

Adicionar annotation nas Applications para forçar sync:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Replace=true
    argocd.argoproj.io/compare-options: IgnoreExtraneous
```

Aplicar via patch:

```bash
kubectl patch application clickhouse-operator -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/sync-options":"Replace=true"}}}'
```

### Verificação

```bash
# Verificar status após correção
kubectl get applications -n argocd

# Deve mostrar:
# NAME              SYNC STATUS   HEALTH STATUS
# clickhouse        Synced        Healthy
# postgres          Synced        Healthy
```

---

## 🔄 ArgoCD Sync Loop / OutOfSync Constante

### Problema

Application fica alternando entre `Synced` e `OutOfSync`.

### Causa Comum

1. **Recursos com valores dinâmicos** (timestamps, random IDs)
2. **Defaults aplicados pelo Kubernetes** que não estão no Git
3. **Mutating webhooks** modificando recursos

### Solução: Ignorar Diferenças

Editar Application para ignorar campos específicos:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignora se HPA está gerenciando

    - group: ""
      kind: Secret
      jsonPointers:
        - /data  # Ignora conteúdo de secrets

    - group: ""
      kind: Service
      jsonPointers:
        - /spec/clusterIP
        - /spec/clusterIPs
```

Aplicar via patch:

```bash
kubectl patch application peerdb -n argocd --type json \
  -p '[{"op":"add","path":"/spec/ignoreDifferences","value":[{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}]}]'
```

---

## 🚫 Application Stuck in "Progressing"

### Problema

Application fica em estado `Progressing` por muito tempo.

### Diagnóstico

```bash
# Ver detalhes da Application
argocd app get <app-name>

# Ver logs do sync
argocd app logs <app-name>

# Ver recursos criados
kubectl get all -n <namespace>
```

### Causas e Soluções

#### 1. Pods não iniciam (ImagePullBackOff)

```bash
# Verificar pods
kubectl get pods -n <namespace>

# Ver eventos
kubectl describe pod <pod-name> -n <namespace>

# Solução: Corrigir image tag ou pull secrets
```

#### 2. Resources Quota excedido

```bash
# Verificar quotas
kubectl describe resourcequota -n <namespace>

# Solução: Aumentar quota ou reduzir requests
```

#### 3. PVC não pode ser provisionado

```bash
# Verificar PVCs
kubectl get pvc -n <namespace>

# Ver eventos
kubectl describe pvc <pvc-name> -n <namespace>

# Solução: Verificar StorageClass existe
kubectl get storageclass
```

---

## 🔐 Secret "postgres-cluster-app" não encontrado

### Problema

```
Error: secret "postgres-cluster-app" not found
```

### Causa

CloudNativePG espera secret com credenciais, mas ele é criado automaticamente.

### Solução

Aguardar CloudNativePG Operator criar o secret:

```bash
# Verificar se operator está rodando
kubectl get pods -n cloudnative-pg -l app.kubernetes.io/name=cloudnative-pg

# Aguardar secret ser criado
kubectl get secret -n cloudnative-pg -w

# Se não criar, verificar logs do operator
kubectl logs -n cloudnative-pg -l app.kubernetes.io/name=cloudnative-pg
```

---

## 🐘 PostgreSQL Cluster não inicia

### Diagnóstico

```bash
# Verificar cluster
kubectl get cluster -n cloudnative-pg

# Ver pods
kubectl get pods -n cloudnative-pg

# Logs da instância primária
kubectl logs -n cloudnative-pg postgres-cluster-1
```

### Problemas Comuns

#### 1. Insufficient CPU/Memory

```bash
# Verificar recursos do node
kubectl top nodes

# Solução: Reduzir requests ou adicionar nodes
```

#### 2. Node Affinity não satisfeito

```bash
# Verificar labels dos nodes
kubectl get nodes --show-labels | grep workload

# Solução: Adicionar labels
kubectl label node <node-name> workload=postgres
```

#### 3. Storage Class não existe

```bash
# Verificar storage class
kubectl get storageclass

# Solução: Criar ou usar storageClass: standard
```

---

## 🔥 ClickHouse Keeper não forma quorum

### Diagnóstico

```bash
# Verificar keepers
kubectl get pods -n clickhouse -l clickhouse.altinity.com/keeper

# Logs do keeper
kubectl logs -n clickhouse clickhouse-keeper-0

# Verificar conectividade
kubectl exec -n clickhouse clickhouse-keeper-0 -- \
  echo ruok | nc localhost 9181
```

### Solução

```bash
# Deletar PVCs e reiniciar (dados de teste apenas!)
kubectl delete pvc -n clickhouse -l clickhouse.altinity.com/keeper

# Aguardar keepers subirem novamente
kubectl get pods -n clickhouse -w
```

---

## 🔄 PeerDB não cria mirror

### Diagnóstico

```bash
# Verificar job de setup
kubectl get jobs -n peerdb

# Logs do job
kubectl logs -n peerdb job/peerdb-setup-mirror

# Verificar PeerDB está acessível
kubectl port-forward -n peerdb svc/peerdb 3000:3000
curl http://localhost:3000/api/health
```

### Problemas Comuns

#### 1. PostgreSQL não está pronto

```bash
# Aguardar PostgreSQL cluster
kubectl wait --for=condition=ready cluster/postgres-cluster \
  -n cloudnative-pg --timeout=600s
```

#### 2. ClickHouse não está pronto

```bash
# Verificar ClickHouse pods
kubectl get pods -n clickhouse

# Testar conexão
kubectl exec -n clickhouse chi-clickhouse-cluster-clickhouse-0-0-0 -- \
  clickhouse-client --query "SELECT 1"
```

#### 3. Temporal não está pronto

```bash
# Verificar Temporal
kubectl get pods -n peerdb -l app.kubernetes.io/name=temporal

# Logs
kubectl logs -n peerdb -l app.kubernetes.io/name=temporal
```

### Solução: Reexecutar Job

```bash
# Deletar job antigo
kubectl delete job -n peerdb peerdb-setup-mirror

# Recriar job
kubectl apply -f manifests/peerdb/setup-mirror-job.yaml
```

---

## 📊 Prometheus não scrape métricas

### Diagnóstico

```bash
# Verificar ServiceMonitors
kubectl get servicemonitor -n monitoring

# Verificar targets no Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Acessar: http://localhost:9090/targets
```

### Solução

```bash
# Verificar se Prometheus Operator está rodando
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-operator

# Verificar labels dos services
kubectl get svc -n clickhouse --show-labels
kubectl get svc -n cloudnative-pg --show-labels

# Aplicar ServiceMonitors novamente
kubectl apply -f manifests/monitoring/
```

---

## 🔍 Comandos Úteis de Debug

### ArgoCD

```bash
# Ver todas applications
argocd app list

# Detalhes de uma app
argocd app get <app-name>

# Diff entre Git e cluster
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force

# Deletar app (mantém recursos)
argocd app delete <app-name> --cascade=false
```

### Kubernetes

```bash
# Ver todos recursos em namespace
kubectl get all -n <namespace>

# Eventos (últimos problemas)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Logs de todos pods de um deployment
kubectl logs -n <namespace> -l app=<label> --tail=100

# Describe (detalhes + eventos)
kubectl describe <resource> <name> -n <namespace>

# Port forward para debug
kubectl port-forward -n <namespace> <pod-name> <local-port>:<remote-port>
```

### PostgreSQL

```bash
# Conectar ao PostgreSQL
kubectl exec -it -n cloudnative-pg postgres-cluster-1 -- \
  psql -U app_user -d app_db

# Verificar replicação
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Verificar WAL
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  psql -U postgres -c "SELECT pg_current_wal_lsn();"
```

### ClickHouse

```bash
# Conectar ao ClickHouse
kubectl exec -it -n clickhouse chi-clickhouse-cluster-clickhouse-0-0-0 -- \
  clickhouse-client

# Verificar cluster
kubectl exec -n clickhouse chi-clickhouse-cluster-clickhouse-0-0-0 -- \
  clickhouse-client --query "SELECT * FROM system.clusters"

# Verificar replicação
kubectl exec -n clickhouse chi-clickhouse-cluster-clickhouse-0-0-0 -- \
  clickhouse-client --query "SELECT * FROM system.replicas"
```

### PeerDB

```bash
# Conectar ao PeerDB
kubectl port-forward -n peerdb svc/peerdb 3000:3000

# Verificar peers
curl http://localhost:3000/api/v1/peers

# Verificar mirrors
curl http://localhost:3000/api/v1/mirrors
```

---

## 🚨 Recovery Procedures

### Reinstalação Completa

```bash
# 1. Backup (se necessário)
kubectl get all --all-namespaces -o yaml > backup.yaml

# 2. Deletar tudo
make cleanup  # Ou usar scripts/cleanup.sh

# 3. Reinstalar
make install-argocd
kubectl apply -f apps/

# 4. Aguardar
kubectl get applications -n argocd -w
```

### Recovery de Dados PostgreSQL

```bash
# Se configurou backup S3
kubectl exec -n cloudnative-pg postgres-cluster-1 -- \
  barman-cloud-restore <s3-path> <backup-id> /var/lib/postgresql/data
```

### Recovery de ClickHouse

```bash
# ClickHouse mantém dados em PVCs
# Para restaurar, basta recriar pods com mesmos PVCs
kubectl delete pod -n clickhouse <pod-name>
# PVC mantém dados, novo pod monta mesmo volume
```

---

## 📞 Obter Ajuda

### Logs importantes

```bash
# Coletar logs para análise
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server > argocd.log
kubectl logs -n cloudnative-pg -l app.kubernetes.io/name=cloudnative-pg > cnpg.log
kubectl logs -n clickhouse -l clickhouse.altinity.com/app=chop > clickhouse-operator.log
kubectl get events --all-namespaces --sort-by='.lastTimestamp' > events.log
```

### Informações do cluster

```bash
kubectl version
kubectl get nodes -o wide
kubectl top nodes
kubectl get storageclass
kubectl get all --all-namespaces
```

---

**Última atualização:** Outubro 2024
**Versão:** 1.0
