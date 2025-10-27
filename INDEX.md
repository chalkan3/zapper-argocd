# 📚 Índice de Documentação - Zapper ArgoCD GitOps

## 🎯 Por Onde Começar?

### Você é novo aqui?
→ Comece por **[SUMMARY.txt](SUMMARY.txt)** para visão geral rápida
→ Depois leia **[README.md](README.md)** para instalação completa

### Quer instalar rapidamente?
→ Use **[QUICKREF.md](QUICKREF.md)** para comandos rápidos
→ Ou execute **`./quickstart.sh`**

### Quer entender a estrutura?
→ Leia **[STRUCTURE.md](STRUCTURE.md)** para detalhes da organização

### Quer entender a arquitetura?
→ Leia **[ARCHITECTURE.md](ARCHITECTURE.md)** para visão técnica completa

### Precisa configurar o CDC?
→ Siga **[PEERDB_SETUP.md](PEERDB_SETUP.md)** passo a passo

### Quer validar a instalação?
→ Use **[CHECKLIST.md](CHECKLIST.md)** para verificar cada componente
→ Ou execute **`./test-e2e.sh`** para teste automatizado

### Quer testar os componentes?
→ Leia **[TESTING_GUIDE.md](TESTING_GUIDE.md)** para testes detalhados
→ Ou use **[TESTING_QUICKREF.md](TESTING_QUICKREF.md)** para referência rápida

---

## 📖 Guia Completo de Documentação

### 1️⃣ Documentação de Setup

#### **README.md** - Guia Principal
- Visão geral do projeto
- Pré-requisitos
- Instalação passo a passo
- Comandos básicos
- Troubleshooting inicial
- **Quando usar**: Primeira instalação e setup geral

#### **quickstart.sh** - Script de Instalação
- Script automatizado de instalação
- Instala ArgoCD
- Aplica todas as applications
- **Quando usar**: Instalação rápida sem customizações

#### **QUICKREF.md** - Referência Rápida
- Comandos mais usados
- Credenciais de acesso
- Port forwards
- Troubleshooting rápido
- **Quando usar**: Consulta rápida durante operação

#### **CHECKLIST.md** - Lista de Verificação
- Pré-requisitos
- Passos de instalação
- Validação de cada componente
- Testes end-to-end
- **Quando usar**: Validar instalação completa

---

### 2️⃣ Documentação Técnica

#### **ARCHITECTURE.md** - Arquitetura do Sistema
- Visão geral da arquitetura
- Componentes detalhados
- Fluxo de dados
- Escalabilidade
- Disaster recovery
- Segurança
- **Quando usar**: Entender como tudo funciona

#### **STRUCTURE.md** - Estrutura do Repositório
- Organização de arquivos e diretórios
- Como Helm charts são usados
- Como Applications funcionam
- Como modificar configurações
- Como adicionar novos componentes
- **Quando usar**: Entender organização do código

#### **PEERDB_SETUP.md** - Configuração do PeerDB
- Como configurar CDC
- Criar peers (PostgreSQL e ClickHouse)
- Criar mirrors
- Testar replicação
- Troubleshooting específico
- **Quando usar**: Configurar CDC após instalação

#### **SUMMARY.txt** - Resumo Visual
- Overview visual da estrutura
- Diagrama ASCII da arquitetura
- Quick start resumido
- Features principais
- **Quando usar**: Visão geral rápida

---

### 3️⃣ Arquivos de Configuração

#### **Diretório `/apps/`**
Contém as ArgoCD Applications que definem o que será deployado:

- **clickhouse.yaml**
  - ClickHouse Operator (Helm)
  - ClickHouse Cluster (CRD)

- **cloudnative-pg.yaml**
  - CloudNativePG Operator (Helm)
  - PostgreSQL Cluster (CRD)

- **peerdb-dependencies.yaml**
  - PostgreSQL para metadata (Helm Bitnami)
  - Temporal workflow engine (Helm)

- **peerdb.yaml**
  - PeerDB server + flow-workers (manifests)

**Quando modificar**:
- Mudar versão de Helm charts
- Alterar valores inline
- Adicionar novas aplicações

#### **Diretório `/helm-values/`**
Valores customizados e CRDs:

- **clickhouse-cluster.yaml** - ClickHouseInstallation CRD
- **postgres-cluster.yaml** - PostgreSQL Cluster CRD
- **\*-values.yaml** - Valores para Helm charts (referência)

**Quando modificar**:
- Alterar número de shards/replicas
- Mudar configurações de storage
- Ajustar recursos (CPU/memory)

#### **Diretório `/manifests/`**
Manifests Kubernetes puros:

- **peerdb/deployment.yaml** - Deployments do PeerDB
- **peerdb/service.yaml** - Services do PeerDB

**Quando modificar**:
- Alterar imagens do PeerDB
- Escalar workers
- Mudar variáveis de ambiente

---

### 4️⃣ Ferramentas

#### **Makefile**
Comandos úteis para operação:

```bash
make help                    # Ver todos os comandos
make install-argocd          # Instalar ArgoCD
make deploy-apps             # Deploy aplicações
make status                  # Ver status
make port-forward-*          # Port forwards
make logs-*                  # Ver logs
make clean                   # Remover tudo
```

**Quando usar**: Operação do dia a dia

---

## 🗺️ Fluxo de Leitura Recomendado

### Para Iniciantes

```
1. SUMMARY.txt           (5 min)  - Visão geral
2. README.md             (15 min) - Setup completo
3. quickstart.sh         (5 min)  - Execução
4. CHECKLIST.md          (20 min) - Validação
5. PEERDB_SETUP.md       (15 min) - Configurar CDC
6. QUICKREF.md           (bookm)  - Salvar para consulta
```

**Tempo total**: ~1 hora

### Para Operadores

```
1. ARCHITECTURE.md       (20 min) - Entender sistema
2. STRUCTURE.md          (15 min) - Organização
3. QUICKREF.md           (bookm)  - Comandos frequentes
4. Makefile              (5 min)  - Ferramentas
```

**Tempo total**: ~40 minutos

### Para Desenvolvedores

```
1. STRUCTURE.md          (15 min) - Como está organizado
2. apps/*.yaml           (10 min) - ArgoCD Applications
3. helm-values/*.yaml    (10 min) - Configurações
4. manifests/*.yaml      (5 min)  - Manifests
5. ARCHITECTURE.md       (20 min) - Arquitetura completa
```

**Tempo total**: ~1 hora

---

## 🔍 Busca Rápida

### "Como faço para..."

| Pergunta | Documento | Seção |
|----------|-----------|-------|
| Instalar tudo? | README.md | Instalação |
| Configurar CDC? | PEERDB_SETUP.md | Passo 1-5 |
| Ver logs? | QUICKREF.md | Logs |
| Acessar serviços? | QUICKREF.md | Port Forwards |
| Obter credenciais? | QUICKREF.md | Credenciais |
| Aumentar réplicas? | STRUCTURE.md | Modificando Configurações |
| Adicionar app? | STRUCTURE.md | Adicionando Aplicações |
| Resolver problemas? | README.md, CHECKLIST.md | Troubleshooting |
| Entender arquitetura? | ARCHITECTURE.md | Componentes |
| Escalar componentes? | ARCHITECTURE.md | Escalabilidade |

### "O que é..."

| Termo | Documento | Explicação |
|-------|-----------|------------|
| ArgoCD | ARCHITECTURE.md | GitOps CD tool |
| ClickHouse | ARCHITECTURE.md | Analytical database |
| CloudNativePG | ARCHITECTURE.md | PostgreSQL operator |
| PeerDB | ARCHITECTURE.md | CDC tool |
| Temporal | ARCHITECTURE.md | Workflow engine |
| Keeper | ARCHITECTURE.md | ClickHouse coordinator |
| CDC | PEERDB_SETUP.md | Change Data Capture |
| CRD | STRUCTURE.md | Custom Resource Definition |
| Operator | STRUCTURE.md | Kubernetes operator pattern |

---

## 📝 Convenções de Documentação

### Emoji Guide

- 🚀 Ações/Comandos
- 📁 Arquivos/Diretórios
- 🎯 Objetivos/Metas
- ⚙️ Configurações
- 🐛 Troubleshooting
- ✅ Sucesso/Checklist
- ❌ Erro/Falha
- 💡 Dicas
- ⚠️ Avisos
- 📊 Arquitetura/Diagramas
- 🔧 Ferramentas
- 🔍 Busca/Análise
- 📚 Documentação
- 🔗 Links externos

### Code Blocks

```bash
# Comandos de terminal
```

```yaml
# Configurações YAML
```

```
# Outputs/Resultados
```

---

## 🆘 Precisa de Ajuda?

1. **Problema de instalação?**
   → README.md (Troubleshooting) + CHECKLIST.md

2. **CDC não funciona?**
   → PEERDB_SETUP.md (Troubleshooting)

3. **Quer customizar?**
   → STRUCTURE.md (Modificando Configurações)

4. **Quer entender melhor?**
   → ARCHITECTURE.md

5. **Comando rápido?**
   → QUICKREF.md ou `make help`

---

## 📌 Links Rápidos

- [README.md](README.md) - Setup geral
- [QUICKREF.md](QUICKREF.md) - Referência rápida
- [ARCHITECTURE.md](ARCHITECTURE.md) - Arquitetura
- [STRUCTURE.md](STRUCTURE.md) - Estrutura
- [PEERDB_SETUP.md](PEERDB_SETUP.md) - CDC
- [CHECKLIST.md](CHECKLIST.md) - Validação
- [SUMMARY.txt](SUMMARY.txt) - Overview
- [Makefile](Makefile) - Comandos úteis

---

**Última atualização**: 2025-10-27
**Versão**: 1.0.0
