#!/bin/bash

# PeerDB Mirror Setup Script
# Wrapper to run the Python script for CDC mirror setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         PEERDB CDC MIRROR AUTO-SETUP                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed${NC}"
    echo -e "${YELLOW}Please install Python 3.8+ to run this script${NC}"
    exit 1
fi

# Check if requests library is installed
if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Python 'requests' library not found${NC}"
    echo -e "${YELLOW}Installing requests...${NC}"
    pip3 install requests --quiet || {
        echo -e "${RED}❌ Failed to install requests library${NC}"
        echo -e "${YELLOW}Please install manually: pip3 install requests${NC}"
        exit 1
    }
    echo -e "${GREEN}✅ Requests library installed${NC}"
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

# Check if PeerDB is running
echo -e "${YELLOW}Checking if PeerDB is deployed...${NC}"
if ! kubectl get pods -n peerdb -l app=peerdb 2>/dev/null | grep -q Running; then
    echo -e "${RED}❌ PeerDB is not running${NC}"
    echo -e "${YELLOW}Please deploy PeerDB first:${NC}"
    echo -e "  kubectl apply -f apps/peerdb.yaml"
    exit 1
fi
echo -e "${GREEN}✅ PeerDB is running${NC}"

# Check if PostgreSQL is running
echo -e "${YELLOW}Checking if PostgreSQL is deployed...${NC}"
if ! kubectl get pods -n cloudnative-pg -l cnpg.io/cluster=postgres-cluster 2>/dev/null | grep -q Running; then
    echo -e "${RED}❌ PostgreSQL is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✅ PostgreSQL is running${NC}"

# Check if ClickHouse is running
echo -e "${YELLOW}Checking if ClickHouse is deployed...${NC}"
if ! kubectl get pods -n clickhouse -l app=clickhouse 2>/dev/null | grep -q Running; then
    echo -e "${RED}❌ ClickHouse is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ClickHouse is running${NC}"

echo ""
echo -e "${BLUE}Starting PeerDB mirror setup...${NC}"
echo ""

# Port-forward PeerDB (in background)
echo -e "${YELLOW}Setting up port-forward to PeerDB...${NC}"
kubectl port-forward -n peerdb svc/peerdb 3000:3000 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Ensure port-forward is killed on exit
trap "kill $PF_PID 2>/dev/null || true" EXIT

# Set environment variable for local connection
export PEERDB_URL="http://localhost:3000"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run Python script
python3 "$SCRIPT_DIR/setup-peerdb-mirror.py"

RESULT=$?

# Cleanup port-forward
kill $PF_PID 2>/dev/null || true

if [ $RESULT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             SETUP COMPLETED SUCCESSFULLY!                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Verification Commands:${NC}"
    echo ""
    echo -e "${YELLOW}1. Check mirror status in PeerDB UI:${NC}"
    echo "   kubectl port-forward -n peerdb svc/peerdb 3000:3000"
    echo "   http://localhost:3000"
    echo ""
    echo -e "${YELLOW}2. Verify data in ClickHouse:${NC}"
    echo "   kubectl port-forward -n clickhouse svc/chi-clickhouse-cluster-clickhouse-0-0 9000:9000"
    echo "   clickhouse-client --host localhost --port 9000 --user admin --password admin123 \\"
    echo "     --query 'SELECT COUNT(*) FROM users'"
    echo ""
    echo -e "${YELLOW}3. Test real-time CDC:${NC}"
    echo "   # Insert in PostgreSQL"
    echo "   kubectl port-forward -n cloudnative-pg svc/postgres-cluster-rw 5432:5432"
    echo "   psql -h localhost -U app_user -d app_db \\"
    echo "     -c \"INSERT INTO users (username, email) VALUES ('cdc_test', 'cdc@example.com');\""
    echo ""
    echo "   # Check in ClickHouse (wait 30s)"
    echo "   clickhouse-client --host localhost --port 9000 --user admin --password admin123 \\"
    echo "     --query \"SELECT * FROM users WHERE username='cdc_test'\""
    echo ""
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  SETUP FAILED!                            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. Check PeerDB logs:"
    echo "   kubectl logs -n peerdb -l app=peerdb --tail=100"
    echo ""
    echo "2. Check PeerDB UI manually:"
    echo "   kubectl port-forward -n peerdb svc/peerdb 3000:3000"
    echo "   http://localhost:3000"
    echo ""
    echo "3. Verify PostgreSQL replication settings:"
    echo "   kubectl exec -n cloudnative-pg postgres-cluster-1 -- \\"
    echo "     psql -U app_user -d app_db -c 'SHOW wal_level;'"
    echo ""
    exit 1
fi
