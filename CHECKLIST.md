# Checklist de Deploy e Validação

Use este checklist para garantir que todas as etapas foram completadas corretamente.

## Pré-Deploy

- [ ] Cluster K3s instalado e rodando
  ```bash
  kubectl cluster-info
  ```

- [ ] kubectl configurado e funcionando
  ```bash
  kubectl get nodes
  ```

- [ ] Helm 3+ instalado
  ```bash
  helm version
  ```

- [ ] Git instalado
  ```bash
  git --version
  ```

## Setup do Repositório

- [ ] Repositório clonado/criado

- [ ] Atualizar URLs do repositório em `apps/*.yaml`
  - [ ] `apps/clickhouse.yaml`
  - [ ] `apps/cloudnative-pg.yaml`
  - [ ] `apps/peerdb-dependencies.yaml`
  - [ ] `apps/peerdb.yaml`

  Substituir:
  ```yaml
  repoURL: https://github.com/YOUR_USERNAME/zapper-argocd.git
  ```

  Por:
  ```yaml
  repoURL: https://github.com/SEU_USUARIO/zapper-argocd.git
  ```

- [ ] Fazer commit e push das mudanças
  ```bash
  git add .
  git commit -m "Initial GitOps setup"
  git push origin main
  ```

## Deploy do ArgoCD

- [ ] Executar quickstart ou instalação manual
  ```bash
  ./quickstart.sh
  # OU
  make install-argocd
  ```

- [ ] ArgoCD pods rodando
  ```bash
  kubectl get pods -n argocd
  ```
  Deve mostrar todos os pods como Running/Completed

- [ ] Obter senha do ArgoCD
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  ```
  Senha: _______________

- [ ] Port-forward do ArgoCD funcionando (opcional)
  ```bash
  make port-forward-argocd
  ```

- [ ] Acessar UI do ArgoCD em https://localhost:8080 (opcional)

## Deploy das Aplicações

- [ ] Aplicar os ApplicationSets
  ```bash
  make deploy-apps
  ```

- [ ] Verificar aplicações criadas
  ```bash
  kubectl get applications -n argocd
  ```
  Deve mostrar 4 aplicações:
  - clickhouse
  - cloudnative-pg
  - peerdb-dependencies
  - peerdb

## Validação: ClickHouse

- [ ] Application status: Healthy & Synced
  ```bash
  kubectl get application clickhouse -n argocd
  ```

- [ ] ClickHouse Operator rodando
  ```bash
  kubectl get pods -n clickhouse -l app=clickhouse-operator
  ```

- [ ] ClickHouse Keeper pods rodando (3 pods)
  ```bash
  kubectl get pods -n clickhouse -l clickhouse.altinity.com/keeper=clickhouse-keeper
  ```
  Esperado: 3 pods Running

- [ ] ClickHouse cluster pods rodando (4+ pods)
  ```bash
  kubectl get pods -n clickhouse -l clickhouse.altinity.com/chi=clickhouse-cluster
  ```
  Esperado: 4+ pods Running (2 shards x 2 replicas)

- [ ] Testar conexão ao ClickHouse
  ```bash
  kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-cluster-0-0 9000:9000 &
  echo "SELECT version()" | clickhouse-client --host localhost --port 9000 --user admin --password admin123
  ```

## Validação: CloudNativePG

- [ ] Application status: Healthy & Synced
  ```bash
  kubectl get application cloudnative-pg -n argocd
  ```

- [ ] CloudNativePG Operator rodando
  ```bash
  kubectl get pods -n cloudnative-pg -l app.kubernetes.io/name=cloudnative-pg
  ```

- [ ] PostgreSQL cluster pods rodando (3 pods)
  ```bash
  kubectl get pods -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster
  ```
  Esperado: 3 pods Running

- [ ] PostgreSQL cluster status
  ```bash
  kubectl get cluster -n cloudnative-pg postgres-cluster
  ```
  Status deve ser "Cluster in healthy state"

- [ ] Verificar dados dummy
  ```bash
  kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432 &
  PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
  psql -h localhost -U app_user -d app_db -c "SELECT COUNT(*) FROM users;"
  ```
  Esperado: 4 rows

- [ ] Verificar logical replication habilitado
  ```bash
  kubectl exec -n cloudnative-pg postgres-cluster-1 -- psql -U app_user -d app_db -c "SHOW wal_level;"
  ```
  Esperado: logical

## Validação: PeerDB Dependencies

- [ ] Application status: Healthy & Synced
  ```bash
  kubectl get application peerdb-dependencies -n argocd
  ```

- [ ] PostgreSQL (metadata) rodando
  ```bash
  kubectl get pods -n peerdb -l app.kubernetes.io/name=postgresql
  ```

- [ ] Temporal pods rodando
  ```bash
  kubectl get pods -n peerdb -l app.kubernetes.io/instance=peerdb-dependencies
  ```
  Esperado: temporal-frontend, temporal-history, temporal-matching, temporal-worker

- [ ] Databases do Temporal criadas
  ```bash
  kubectl exec -n peerdb deployment/peerdb-dependencies-postgresql -- psql -U peerdb -l
  ```
  Deve listar: peerdb_metadata, temporal, temporal_visibility

## Validação: PeerDB

- [ ] Application status: Healthy & Synced
  ```bash
  kubectl get application peerdb -n argocd
  ```

- [ ] PeerDB server rodando
  ```bash
  kubectl get pods -n peerdb -l component=server
  ```

- [ ] PeerDB flow-workers rodando (2+ pods)
  ```bash
  kubectl get pods -n peerdb -l component=flow-worker
  ```
  Esperado: 2+ pods Running

- [ ] PeerDB service disponível
  ```bash
  kubectl get svc -n peerdb peerdb
  ```

- [ ] Acessar PeerDB UI
  ```bash
  kubectl port-forward -n peerdb svc/peerdb 3000:3000 &
  curl -s http://localhost:3000/health
  ```
  Esperado: status healthy

## Configuração do CDC

Siga o guia detalhado em `PEERDB_SETUP.md`

### Resumo:

- [ ] Acessar PeerDB UI em http://localhost:3000

- [ ] Criar PostgreSQL Peer
  - Name: postgres-source
  - Host: postgres-cluster-rw.cloudnative-pg.svc.cluster.local
  - Port: 5432
  - Database: app_db
  - User: app_user
  - Password: [do secret]

- [ ] Criar ClickHouse Peer
  - Name: clickhouse-destination
  - Host: clickhouse-clickhouse-cluster.clickhouse.svc.cluster.local
  - Port: 9000
  - Database: default
  - User: admin
  - Password: admin123

- [ ] Criar Mirror
  - Name: pg-to-ch-mirror
  - Source: postgres-source
  - Destination: clickhouse-destination
  - Tables: users, orders, events
  - Mode: CDC

- [ ] Verificar mirror status: Running

- [ ] Verificar dados replicados no ClickHouse
  ```bash
  echo "SELECT COUNT(*) FROM users;" | clickhouse-client --host localhost --port 9000 --user admin --password admin123
  ```
  Esperado: 4 rows

## Teste End-to-End

- [ ] Inserir novo registro no PostgreSQL
  ```bash
  PGPASSWORD=$(kubectl get secret -n cloudnative-pg postgres-cluster-app -o jsonpath='{.data.password}' | base64 -d) \
  psql -h localhost -U app_user -d app_db -c "INSERT INTO users (username, email) VALUES ('test_e2e', 'e2e@test.com');"
  ```

- [ ] Aguardar 30-60 segundos

- [ ] Verificar registro no ClickHouse
  ```bash
  echo "SELECT * FROM users WHERE username='test_e2e';" | clickhouse-client --host localhost --port 9000 --user admin --password admin123
  ```
  Esperado: registro encontrado

- [ ] Verificar lag do mirror no PeerDB UI
  Esperado: < 10 segundos

## Monitoramento Contínuo

- [ ] Verificar status das aplicações
  ```bash
  watch kubectl get applications -n argocd
  ```

- [ ] Verificar logs em caso de erro
  ```bash
  # ClickHouse
  kubectl logs -n clickhouse -l app=clickhouse --tail=50

  # PostgreSQL
  kubectl logs -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster --tail=50

  # PeerDB
  kubectl logs -n peerdb -l app=peerdb --tail=50

  # Temporal
  kubectl logs -n peerdb -l app.kubernetes.io/name=temporal --tail=50
  ```

## Documentação

- [ ] README.md lido e compreendido
- [ ] ARCHITECTURE.md lido e compreendido
- [ ] PEERDB_SETUP.md lido e compreendido
- [ ] Makefile explorado (`make help`)

## Comandos Úteis Salvos

```bash
# Status geral
make status

# Port forwards
make port-forward-argocd
make port-forward-peerdb
make port-forward-clickhouse
make port-forward-postgres

# Logs
make logs-clickhouse
make logs-postgres
make logs-peerdb
make logs-temporal

# Limpeza (cuidado!)
make clean
```

## Notas

Data da instalação: _______________
ArgoCD Password: _______________
Problemas encontrados:
-
-
-

Customizações feitas:
-
-
-

## Conclusão

- [ ] Todos os itens acima verificados
- [ ] Sistema totalmente funcional
- [ ] CDC operacional
- [ ] Documentação atualizada

**Status Final**: ✅ Aprovado / ❌ Pendências

---

Para suporte, consulte:
- README.md
- ARCHITECTURE.md
- PEERDB_SETUP.md
- Makefile (`make help`)
