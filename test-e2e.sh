#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           TESTE END-TO-END - ZAPPER ARGOCD                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

FAILED=0

# Função para teste
test_component() {
  local component=$1
  local command=$2
  local expected=$3
  local description=$4

  echo -n "Testing $component... "
  result=$(eval "$command")

  if [ "$result" -ge "$expected" ]; then
    echo -e "${GREEN}✅ PASS${NC} - $description (found: $result, expected: $expected+)"
  else
    echo -e "${RED}❌ FAIL${NC} - $description (found: $result, expected: $expected+)"
    FAILED=$((FAILED + 1))
  fi
}

echo -e "${YELLOW}1️⃣  Verificando ArgoCD Applications...${NC}"
test_component "ArgoCD" \
  "kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l" \
  "8" \
  "8 Applications"

echo ""
echo -e "${YELLOW}2️⃣  Verificando CloudNativePG (PostgreSQL)...${NC}"
test_component "PostgreSQL Pods" \
  "kubectl get pods -n cloudnative-pg --no-headers 2>/dev/null | grep Running | wc -l" \
  "3" \
  "3 pods running"

test_component "PostgreSQL Operator" \
  "kubectl get deployment -n cloudnative-pg cnpg-operator --no-headers 2>/dev/null | wc -l" \
  "1" \
  "Operator deployed"

echo ""
echo -e "${YELLOW}3️⃣  Verificando ClickHouse...${NC}"
test_component "ClickHouse Pods" \
  "kubectl get pods -n clickhouse --no-headers 2>/dev/null | grep -E 'clickhouse-cluster|clickhouse-.*-[0-9]' | grep Running | wc -l" \
  "4" \
  "4+ ClickHouse pods"

test_component "ClickHouse Keeper" \
  "kubectl get pods -n clickhouse --no-headers 2>/dev/null | grep keeper | grep Running | wc -l" \
  "3" \
  "3 Keeper pods"

echo ""
echo -e "${YELLOW}4️⃣  Verificando PeerDB...${NC}"
test_component "PeerDB Pods" \
  "kubectl get pods -n peerdb -l app=peerdb --no-headers 2>/dev/null | grep Running | wc -l" \
  "3" \
  "PeerDB server + workers"

test_component "PeerDB Service" \
  "kubectl get svc -n peerdb peerdb --no-headers 2>/dev/null | wc -l" \
  "1" \
  "PeerDB service"

echo ""
echo -e "${YELLOW}5️⃣  Verificando Temporal...${NC}"
test_component "Temporal Pods" \
  "kubectl get pods -n peerdb --no-headers 2>/dev/null | grep temporal | grep Running | wc -l" \
  "4" \
  "4+ Temporal components"

echo ""
echo -e "${YELLOW}6️⃣  Verificando PostgreSQL (PeerDB Metadata)...${NC}"
test_component "PeerDB PostgreSQL" \
  "kubectl get pods -n peerdb --no-headers 2>/dev/null | grep postgresql | grep Running | wc -l" \
  "1" \
  "PostgreSQL metadata"

echo ""
echo -e "${YELLOW}7️⃣  Verificando HPAs...${NC}"
test_component "HPAs" \
  "kubectl get hpa --all-namespaces --no-headers 2>/dev/null | wc -l" \
  "9" \
  "9 HPAs configurados"

echo ""
echo -e "${YELLOW}8️⃣  Verificando Node Affinity...${NC}"

# PostgreSQL nodes
PG_ON_CORRECT=$(kubectl get pods -n cloudnative-pg -o wide 2>/dev/null | grep postgres-cluster | awk '{print $7}' | grep -cE "worker-1|worker-2" || echo 0)
echo -e "  PostgreSQL: ${GREEN}$PG_ON_CORRECT/3${NC} pods nos workers corretos (worker-1/2)"

# ClickHouse nodes
CH_ON_CORRECT=$(kubectl get pods -n clickhouse -o wide 2>/dev/null | grep -E "clickhouse-cluster|clickhouse-.*-[0-9]|keeper" | awk '{print $7}' | grep -c "worker-3" || echo 0)
echo -e "  ClickHouse: ${GREEN}$CH_ON_CORRECT/7${NC} pods no worker correto (worker-3)"

# PeerDB nodes
PEERDB_ON_CORRECT=$(kubectl get pods -n peerdb -l app=peerdb -o wide 2>/dev/null | awk '{print $7}' | grep -cE "worker-4|worker-5" || echo 0)
echo -e "  PeerDB: ${GREEN}$PEERDB_ON_CORRECT/3+${NC} pods nos workers corretos (worker-4/5)"

echo ""
echo -e "${YELLOW}9️⃣  Verificando Metrics Server (para HPAs)...${NC}"
METRICS=$(kubectl get deployment metrics-server -n kube-system --no-headers 2>/dev/null | wc -l)
if [ "$METRICS" -ge 1 ]; then
  echo -e "${GREEN}✅ PASS${NC} - Metrics Server instalado"
else
  echo -e "${YELLOW}⚠️  WARN${NC} - Metrics Server não encontrado (HPAs não funcionarão)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}🎉 SUCESSO! Todos os testes passaram!${NC}"
  echo ""
  echo -e "${BLUE}📋 Próximos Passos:${NC}"
  echo ""
  echo "1. Configurar CDC no PeerDB:"
  echo "   kubectl port-forward -n peerdb svc/peerdb 3000:3000"
  echo "   Acesse: http://localhost:3000"
  echo ""
  echo "2. Testar replicação:"
  echo "   - Criar PostgreSQL Peer"
  echo "   - Criar ClickHouse Peer"
  echo "   - Criar Mirror (PG → CH)"
  echo "   - Inserir dados no PostgreSQL"
  echo "   - Verificar no ClickHouse"
  echo ""
  echo "3. Monitorar:"
  echo "   kubectl get hpa --all-namespaces"
  echo "   kubectl top pods -n peerdb"
  echo ""
  echo -e "${GREEN}✅ Infraestrutura 100% funcional!${NC}"
  exit 0
else
  echo -e "${RED}❌ FALHOU! $FAILED teste(s) falharam.${NC}"
  echo ""
  echo "Verifique os logs:"
  echo "  kubectl get pods --all-namespaces"
  echo "  kubectl describe pod <pod-name> -n <namespace>"
  echo ""
  echo "Documentação:"
  echo "  TESTING_GUIDE.md - Guia completo de testes"
  exit 1
fi
