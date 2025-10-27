# 🤖 ArgoCD - O que é Automático vs Manual

## ✅ O que o ArgoCD faz SOZINHO (100% Automático)

### 1. Sincronização Contínua do Git → Cluster

```
Git Repo (main) → ArgoCD → Kubernetes Cluster
```

- ✅ **Detecta mudanças** no repositório Git a cada 3 minutos
- ✅ **Aplica mudanças** automaticamente no cluster
- ✅ **Self-healing**: Se alguém modificar algo no cluster manualmente, ArgoCD reverte
- ✅ **Sync automático**: Novas versões são deployadas automaticamente
- ✅ **Retry automático**: Se falhar, tenta novamente com backoff

### 2. Ordem de Deploy (Respeitada pelo ArgoCD)

```
1. Operators (ClickHouse, CloudNativePG)
   ↓
2. Clusters (após operators estarem ready)
   ↓
3. Dependencies (PostgreSQL, Temporal)
   ↓
4. Applications (PeerDB)
   ↓
5. HPAs (após deployments)
```

**ArgoCD gerencia isso através de health checks**

### 3. Health Monitoring

ArgoCD verifica automaticamente se os recursos estão saudáveis:

- ✅ **Pods**: Running
- ✅ **Deployments**: Available replicas
- ✅ **StatefulSets**: Ready replicas
- ✅ **Services**: Endpoints disponíveis
- ✅ **CRDs**: Status dos custom resources

### 4. Auto-Scaling (via HPAs)

Uma vez que os HPAs estão criados, o Kubernetes + Metrics Server cuidam do scaling:

- ✅ **Monitora CPU/Memória** dos pods
- ✅ **Escala UP** quando ultrapassa threshold
- ✅ **Escala DOWN** quando uso diminui
- ✅ **Respeita node affinity** ao criar novos pods

### 5. Namespace Management

- ✅ **Cria namespaces** automaticamente (`CreateNamespace=true`)
- ✅ **Gerencia recursos** em múltiplos namespaces
- ✅ **Limpa recursos órfãos** quando removidos do Git

### 6. Helm Chart Management

- ✅ **Baixa charts** dos repositórios oficiais
- ✅ **Aplica values** configurados
- ✅ **Atualiza versões** quando você mudar no Git
- ✅ **Rollback automático** se falhar

---

## ⚠️ O que você PRECISA FAZER MANUALMENTE (Antes do ArgoCD)

### 🔧 Passo 1: Preparar o Cluster K3s

```bash
# Instalar K3s (control-plane)
curl -sfL https://get.k3s.io | sh -

# Adicionar workers
curl -sfL https://get.k3s.io | K3S_URL=https://control-plane:6443 \
  K3S_TOKEN=<token> sh -
```

**ArgoCD NÃO faz isso**: Você precisa de um cluster funcionando primeiro.

---

### 🏷️ Passo 2: Adicionar Labels nos Workers

```bash
# PostgreSQL workers
kubectl label node worker-1 workload=postgres
kubectl label node worker-2 workload=postgres

# ClickHouse worker
kubectl label node worker-3 workload=clickhouse

# PeerDB workers
kubectl label node worker-4 workload=peerdb
kubectl label node worker-5 workload=peerdb
```

**ArgoCD NÃO faz isso**: Labels precisam existir antes dos pods serem criados.

**Por quê?** Node affinity nos manifestos depende desses labels.

---

### 🔒 Passo 3: (Opcional) Adicionar Taints

```bash
kubectl taint node worker-1 workload=postgres:NoSchedule
kubectl taint node worker-2 workload=postgres:NoSchedule
kubectl taint node worker-3 workload=clickhouse:NoSchedule
kubectl taint node worker-4 workload=peerdb:NoSchedule
kubectl taint node worker-5 workload=peerdb:NoSchedule
```

**ArgoCD NÃO faz isso**: Taints são configurações de node, não de aplicação.

---

### 📦 Passo 4: Instalar o ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**ArgoCD NÃO se instala sozinho**: Você precisa instalar primeiro.

---

### 🔄 Passo 5: Configurar o Repositório Git

```bash
# Atualizar URLs em apps/*.yaml
sed -i '' 's/YOUR_USERNAME/seu-usuario/g' apps/*.yaml

# Git init + push
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/seu-usuario/zapper-argocd.git
git push -u origin main
```

**ArgoCD NÃO faz isso**: Precisa apontar para um repo Git válido.

---

### 🚀 Passo 6: Aplicar as Applications

```bash
kubectl apply -f apps/
```

**Isso cria as 8 Applications no ArgoCD**.

**ArgoCD NÃO aplica apps/*.yaml sozinho**: Você precisa fazer o bootstrap inicial.

---

### 🎯 Passo 7: Configurar PeerDB (CDC)

```bash
# Port-forward
kubectl port-forward -n peerdb svc/peerdb 3000:3000

# Acessar UI: http://localhost:3000
# Configurar manualmente:
#   1. Criar PostgreSQL Peer
#   2. Criar ClickHouse Peer
#   3. Criar Mirror (PG → CH)
```

**ArgoCD NÃO faz isso**: Configuração de CDC é via UI do PeerDB.

**Por quê?** Você solicitou que a configuração fosse manual via interface.

---

## 🔄 O que acontece DEPOIS do setup inicial (100% Automático)

### Cenário 1: Você muda algo no Git

```bash
# Editar configuração
vim helm-values/clickhouse-cluster.yaml
# Aumentar shards de 2 para 4

# Commit + push
git add .
git commit -m "Scale ClickHouse to 4 shards"
git push
```

**ArgoCD faz:**
1. ✅ Detecta mudança em ~3 minutos
2. ✅ Sincroniza automaticamente
3. ✅ Aplica nova configuração no cluster
4. ✅ Aguarda health check
5. ✅ Marca como "Synced" e "Healthy"

**Você não precisa fazer nada!**

---

### Cenário 2: Alguém modifica algo manualmente no cluster

```bash
# Alguém faz (errado):
kubectl scale deployment peerdb-server -n peerdb --replicas=10
```

**ArgoCD faz:**
1. ✅ Detecta drift (diferença entre Git e Cluster)
2. ✅ **Self-heal**: Reverte para 1 replica (conforme Git)
3. ✅ Marca como "Synced"

**Você não precisa fazer nada!**

---

### Cenário 3: Pod falha/morre

```bash
# Pod morre
kubectl delete pod peerdb-server-xxx -n peerdb
```

**Kubernetes (não ArgoCD) faz:**
1. ✅ Deployment controller detecta
2. ✅ Cria novo pod
3. ✅ Respeita node affinity (worker-4 ou worker-5)
4. ✅ HPA continua monitorando

**ArgoCD monitora que o Deployment está healthy.**

---

### Cenário 4: CPU/Memória alta (HPA)

```bash
# Carga aumenta, CPU vai para 80%
```

**Kubernetes HPA faz:**
1. ✅ Metrics Server coleta métricas
2. ✅ HPA detecta CPU > 75% (threshold)
3. ✅ Escala deployment para +2 pods
4. ✅ Novos pods respeitam node affinity
5. ✅ Quando carga diminui, escala down

**ArgoCD apenas monitora que está tudo saudável.**

---

### Cenário 5: Nova versão do Helm chart

```bash
# Atualizar versão
vim apps/peerdb-dependencies.yaml
# Mudar: targetRevision: 15.5.20 → 15.5.30

# Commit + push
git commit -am "Update PostgreSQL chart"
git push
```

**ArgoCD faz:**
1. ✅ Detecta mudança
2. ✅ Baixa nova versão do chart
3. ✅ Aplica com rolling update
4. ✅ Monitora health durante update
5. ✅ Marca como "Synced"

**Você não precisa fazer nada!**

---

## 📊 Fluxo Completo

```
┌─────────────────────────────────────────────────────────────────┐
│                    SETUP INICIAL (MANUAL)                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. Instalar K3s cluster                                         │
│ 2. Adicionar labels nos workers                                 │
│ 3. (Opcional) Adicionar taints                                  │
│ 4. Instalar ArgoCD                                              │
│ 5. Git init + push                                              │
│ 6. kubectl apply -f apps/                                       │
│ 7. Configurar PeerDB CDC via UI                                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              OPERAÇÃO CONTÍNUA (100% AUTOMÁTICO)                │
├─────────────────────────────────────────────────────────────────┤
│ ✅ ArgoCD sincroniza Git → Cluster (a cada 3 min)              │
│ ✅ Self-healing reverte mudanças manuais                        │
│ ✅ HPAs escalam pods baseado em CPU/Mem                         │
│ ✅ Kubernetes recria pods que morrem                            │
│ ✅ Operators gerenciam lifecycle dos clusters                   │
│ ✅ Deployments fazem rolling updates                            │
│ ✅ Health checks garantem disponibilidade                       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                VOCÊ SÓ PRECISA FAZER (OCASIONAL)                │
├─────────────────────────────────────────────────────────────────┤
│ • git commit + push (mudanças de config)                        │
│ • Monitorar via ArgoCD UI (opcional)                            │
│ • Configurar novos mirrors no PeerDB (via UI)                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Resumo: O que é Automático?

| Ação | Quem Faz | Quando |
|------|----------|--------|
| Sync Git → Cluster | ArgoCD | A cada 3 min |
| Aplicar mudanças | ArgoCD | Automático |
| Self-healing | ArgoCD | Quando há drift |
| Health checks | ArgoCD | Contínuo |
| Scaling (HPA) | Kubernetes HPA | Quando CPU/Mem > threshold |
| Recriar pods mortos | Kubernetes Deployment | Imediato |
| Respeitar node affinity | Kubernetes Scheduler | Sempre |
| Rolling updates | Kubernetes | Durante updates |
| Operator management | Operators | Contínuo |

---

## 🚫 O que NÃO é Automático?

| Ação | Por que Manual |
|------|----------------|
| Instalar K3s | Infraestrutura base |
| Adicionar labels nos nodes | Configuração de infraestrutura |
| Adicionar taints | Configuração de infraestrutura |
| Instalar ArgoCD | Bootstrap inicial |
| Git setup | Setup inicial do repo |
| kubectl apply -f apps/ | Bootstrap das Applications |
| Configurar CDC (PeerDB UI) | Decisão de negócio (você solicitou manual) |

---

## 📝 Checklist de Setup

```bash
# ===== FAÇA UMA VEZ (MANUAL) =====

[ ] 1. Instalar K3s cluster
[ ] 2. kubectl label node worker-{1,2} workload=postgres
[ ] 3. kubectl label node worker-3 workload=clickhouse
[ ] 4. kubectl label node worker-{4,5} workload=peerdb
[ ] 5. (Opcional) kubectl taint nodes...
[ ] 6. Instalar ArgoCD
[ ] 7. sed -i '' 's/YOUR_USERNAME/seu-usuario/g' apps/*.yaml
[ ] 8. git init && git push
[ ] 9. kubectl apply -f apps/
[ ] 10. Esperar tudo ficar "Healthy"
[ ] 11. Configurar PeerDB CDC via UI

# ===== DEPOIS DISSO (AUTOMÁTICO) =====

✅ ArgoCD cuida de tudo!
✅ Você só faz: git commit + push
✅ HPA escala automaticamente
✅ Self-healing automático
```

---

## 💡 Dica: Monitoramento

Você pode monitorar tudo via ArgoCD UI:

```bash
# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acessar: https://localhost:8080
# User: admin
# Pass: kubectl -n argocd get secret argocd-initial-admin-secret \
#         -o jsonpath='{.data.password}' | base64 -d
```

**Na UI você vê:**
- Status de todas as 8 Applications
- Health de todos os recursos
- Diffs entre Git e Cluster
- Histórico de syncs
- Logs de cada recurso

---

## ✅ Conclusão

**ArgoCD orquestra SIM sozinho**, mas você precisa:

1. ✅ **Setup inicial** (1x): cluster, labels, ArgoCD, git, apps
2. ✅ **Configurar CDC** (1x): via PeerDB UI
3. ✅ **Depois**: só git commit + push

**ArgoCD faz o resto:**
- Sync automático
- Self-healing
- Health monitoring
- Rolling updates
- Retry em falhas

**HPA + Kubernetes fazem:**
- Auto-scaling
- Recriar pods
- Distribuição nos workers corretos

**Você relaxa e monitora!** 🎉
