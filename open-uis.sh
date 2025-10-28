#!/bin/bash

echo "Abrindo todas as UIs para apresentação..."
echo ""

# PeerDB UI
echo "[1/4] Starting PeerDB UI..."
kubectl port-forward -n peerdb svc/peerdb-ui 3000:3000 > /dev/null 2>&1 &
PF_PEERDB=$!
sleep 1

# Temporal Web UI
echo "[2/4] Starting Temporal UI..."
kubectl port-forward -n peerdb svc/peerdb-temporal-web 8080:8080 > /dev/null 2>&1 &
PF_TEMPORAL=$!
sleep 1

# ClickHouse HTTP Interface
echo "[3/4] Starting ClickHouse HTTP UI..."
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-cluster 8123:8123 > /dev/null 2>&1 &
PF_CLICKHOUSE_HTTP=$!
sleep 1

# ClickHouse Native (para clients externos)
echo "[4/4] Starting ClickHouse Native Protocol..."
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-cluster 9000:9000 > /dev/null 2>&1 &
PF_CLICKHOUSE_NATIVE=$!
sleep 1

echo ""
echo "=============================================="
echo "✅ Todas as UIs estão rodando!"
echo "=============================================="
echo ""
echo "📊 PeerDB UI:        http://localhost:3000"
echo "   Usuário: (deixe vazio)"
echo "   Senha: peerdb"
echo ""
echo "⏱️  Temporal UI:      http://localhost:8080"
echo "   Sem autenticação"
echo ""
echo "🗄️  ClickHouse Play:  http://localhost:8123/play"
echo "   Usuário: admin"
echo "   Senha: admin123"
echo ""
echo "🔌 ClickHouse Native: localhost:9000"
echo "   Para DBeaver/DataGrip/Clients externos"
echo "   Usuário: admin | Senha: admin123"
echo ""
echo "=============================================="
echo "Pressione Ctrl+C para parar todos os forwards"
echo "=============================================="
echo ""

# Trap Ctrl+C
trap "echo ''; echo 'Parando todos os port-forwards...'; kill $PF_PEERDB $PF_TEMPORAL $PF_CLICKHOUSE_HTTP $PF_CLICKHOUSE_NATIVE 2>/dev/null; echo 'Finalizado!'; exit" INT

# Manter rodando
wait
