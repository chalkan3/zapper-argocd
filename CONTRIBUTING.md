# Contributing to Zapper ArgoCD GitOps

Obrigado por considerar contribuir para este projeto! Este guia irá ajudá-lo a entender como você pode contribuir.

## 📋 Sumário

- [Código de Conduta](#código-de-conduta)
- [Como Posso Contribuir?](#como-posso-contribuir)
- [Diretrizes de Desenvolvimento](#diretrizes-de-desenvolvimento)
- [Processo de Pull Request](#processo-de-pull-request)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Convenções](#convenções)

---

## Código de Conduta

Este projeto segue um código de conduta simples: seja respeitoso e construtivo em todas as interações.

---

## Como Posso Contribuir?

### 🐛 Reportar Bugs

Se você encontrou um bug:

1. **Verifique** se o bug já foi reportado nas [Issues](https://github.com/chalkan3/zapper-argocd/issues)
2. Se não existe, **crie uma nova issue** com:
   - Título descritivo
   - Passos para reproduzir
   - Comportamento esperado vs. atual
   - Versões (K8s, Helm, ArgoCD)
   - Logs relevantes

**Template de Bug Report:**
```markdown
## Descrição do Bug
[Descrição clara do problema]

## Como Reproduzir
1. Execute `kubectl apply -f ...`
2. Aguarde 5 minutos
3. Observe erro X

## Comportamento Esperado
[O que deveria acontecer]

## Ambiente
- K8s Version: 1.28
- ArgoCD Version: 2.9
- Helm Version: 3.13

## Logs
```
[Logs relevantes]
```
```

### 💡 Sugerir Melhorias

Para sugestões de features:

1. **Abra uma issue** com:
   - Título claro (ex: "Feature: Add Kafka to stack")
   - Descrição detalhada
   - Caso de uso
   - Possível implementação

### 📝 Melhorar Documentação

Documentação sempre pode ser melhorada:

- Corrigir typos
- Adicionar exemplos
- Melhorar clareza
- Traduzir para outros idiomas

### 🔧 Contribuir com Código

1. Fork o repositório
2. Crie um branch (`git checkout -b feature/minha-feature`)
3. Faça suas mudanças
4. Commit (`git commit -m 'Add: nova feature'`)
5. Push (`git push origin feature/minha-feature`)
6. Abra um Pull Request

---

## Diretrizes de Desenvolvimento

### Pré-requisitos

```bash
# Ferramentas necessárias
- kubectl
- helm 3+
- git
- make
- K3s ou Kubernetes cluster

# Validação de ambiente
kubectl version --client
helm version
make --version
```

### Setup de Desenvolvimento

```bash
# 1. Fork e clone
git clone https://github.com/SEU-USUARIO/zapper-argocd.git
cd zapper-argocd

# 2. Copiar .env.example
cp .env.example .env

# 3. Instalar ArgoCD
make install-argocd

# 4. Deploy apps
make deploy-apps

# 5. Testar
make test
```

### Validação

Antes de fazer commit:

```bash
# Validar YAML
make validate

# Rodar testes
make test

# Verificar status
make status
```

---

## Processo de Pull Request

### Checklist antes do PR

- [ ] Código testado localmente
- [ ] Testes passando (`make test`)
- [ ] YAML validado (`make validate`)
- [ ] Documentação atualizada
- [ ] Commit messages claros
- [ ] Branch atualizado com `main`

### Template de Pull Request

```markdown
## Descrição
[Descrição clara das mudanças]

## Tipo de Mudança
- [ ] Bug fix
- [ ] Nova feature
- [ ] Breaking change
- [ ] Documentação

## Como Foi Testado?
- [ ] make test
- [ ] Testes manuais
- [ ] Ambiente: K3s 1.28

## Checklist
- [ ] Código segue convenções do projeto
- [ ] Documentação atualizada
- [ ] Testes passando
- [ ] YAML validado
```

### Revisão de Código

Pull requests serão revisados quanto a:

1. **Funcionalidade**: Código funciona como esperado?
2. **Qualidade**: Código segue boas práticas?
3. **Testes**: Mudanças foram testadas?
4. **Documentação**: README atualizado?
5. **Compatibilidade**: Não quebra funcionalidades existentes?

---

## Estrutura do Projeto

```
zapper-argocd/
├── apps/                    ← ArgoCD Applications
│   ├── clickhouse.yaml
│   ├── cloudnative-pg.yaml
│   ├── peerdb.yaml
│   ├── hpa.yaml
│   └── monitoring.yaml
│
├── helm-values/             ← Helm values e CRDs
│   ├── clickhouse-cluster.yaml
│   ├── postgres-cluster.yaml
│   └── monitoring/
│
├── manifests/               ← Kubernetes manifests
│   ├── peerdb/
│   ├── hpa/
│   └── monitoring/
│
├── scripts/                 ← Scripts auxiliares
│   ├── quickstart.sh
│   ├── test-e2e.sh
│   ├── setup-node-affinity.sh
│   └── cleanup.sh
│
├── .env.example             ← Template de variáveis
├── Makefile                 ← Comandos úteis
└── README.md                ← Documentação principal
```

### Onde Adicionar Novos Componentes

| Componente | Localização | Exemplo |
|------------|-------------|---------|
| Nova Application | `apps/` | `apps/kafka.yaml` |
| Helm values | `helm-values/` | `helm-values/kafka-values.yaml` |
| Manifests customizados | `manifests/` | `manifests/kafka/` |
| HPA | `manifests/hpa/` | `manifests/hpa/kafka-hpa.yaml` |
| ServiceMonitor | `manifests/monitoring/` | `manifests/monitoring/servicemonitor-kafka.yaml` |
| Scripts | `scripts/` | `scripts/setup-kafka.sh` |

---

## Convenções

### Git Commit Messages

Use prefixos claros:

```
Add: Nova feature ou componente
Fix: Correção de bug
Update: Atualização de código existente
Remove: Remoção de código
Docs: Apenas documentação
Test: Adicionar ou corrigir testes
Refactor: Refatoração de código
```

**Exemplos:**
```bash
git commit -m "Add: Kafka to data stack"
git commit -m "Fix: ClickHouse node affinity configuration"
git commit -m "Update: Prometheus retention to 60 days"
git commit -m "Docs: Add Kafka setup guide to README"
```

### YAML Formatting

```yaml
# Use 2 espaços para indentação
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: my-namespace
  labels:
    app: my-app
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080

# Sempre adicione comentários explicativos
# Comentário sobre configuração importante
someConfig: value
```

### Kubernetes Resources

**Naming Convention:**
- Lowercase com hífens: `my-service-name`
- Prefixos por namespace quando aplicável
- Sufixos descritivos: `-svc`, `-deploy`, `-hpa`

**Labels Obrigatórias:**
```yaml
metadata:
  labels:
    app: nome-da-app
    component: backend|frontend|database
    managed-by: argocd
```

### Helm Values

Organize por seções:

```yaml
# Application Settings
app:
  name: myapp
  version: 1.0.0

# Resources
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Node Affinity
affinity:
  nodeAffinity:
    # ...

# HPA
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
```

### ArgoCD Applications

Template padrão:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/chalkan3/zapper-argocd.git
    targetRevision: main
    path: manifests/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Testes

### Testes Automatizados

```bash
# Rodar teste E2E completo
make test

# Ou manualmente
./scripts/test-e2e.sh
```

### Testes Manuais

```bash
# Verificar pods
kubectl get pods --all-namespaces

# Verificar Applications
kubectl get applications -n argocd

# Verificar HPAs
kubectl get hpa --all-namespaces

# Verificar node affinity
kubectl get pods -o wide --all-namespaces | grep -E "postgres|clickhouse|peerdb"
```

### Adicionar Novos Testes

Edite `scripts/test-e2e.sh`:

```bash
# Adicionar novo teste
test_component "My Component" \
  "kubectl get pods -n my-namespace --no-headers 2>/dev/null | grep Running | wc -l" \
  "2" \
  "2+ pods running"
```

---

## Versionamento

Este projeto segue [Semantic Versioning](https://semver.org/):

- **MAJOR**: Mudanças incompatíveis (breaking changes)
- **MINOR**: Novas funcionalidades compatíveis
- **PATCH**: Bug fixes compatíveis

Exemplo: `v2.1.3`

---

## Perguntas Frequentes

### Como adicionar um novo componente ao stack?

1. Criar ArgoCD Application em `apps/novo-componente.yaml`
2. Adicionar Helm values ou manifests em `helm-values/` ou `manifests/`
3. Adicionar HPA se necessário em `manifests/hpa/`
4. Adicionar ServiceMonitor em `manifests/monitoring/`
5. Atualizar README.md
6. Adicionar testes em `scripts/test-e2e.sh`
7. Commit e PR

### Como testar mudanças antes do PR?

```bash
# 1. Validar YAML
make validate

# 2. Deploy em cluster de teste
kubectl create namespace test-namespace
kubectl apply -f apps/minha-mudanca.yaml -n test-namespace

# 3. Verificar
kubectl get all -n test-namespace

# 4. Rodar testes
make test

# 5. Cleanup
kubectl delete namespace test-namespace
```

### Como atualizar versões de Helm charts?

1. Editar `apps/*.yaml` e alterar `targetRevision`
2. Testar localmente
3. Atualizar README.md com nova versão
4. Commit e PR

---

## Recursos Úteis

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitOps Principles](https://www.gitops.tech/)

---

## Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a mesma licença MIT do projeto.

---

## Agradecimentos

Obrigado por contribuir para tornar este projeto melhor! 🎉

---

**Dúvidas?** Abra uma [Issue](https://github.com/chalkan3/zapper-argocd/issues) ou entre em contato.
