#!/usr/bin/env python3
"""
PeerDB Mirror Auto-Setup Script

Automatically configures PeerDB CDC replication:
1. Creates PostgreSQL peer (source)
2. Creates ClickHouse peer (destination)
3. Creates mirror (PG -> CH) with tables: users, orders, events

Uses PeerDB API instead of manual UI configuration.
"""

import os
import sys
import time
import json
import base64
import requests
from typing import Optional

# Colors for output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def print_header(msg: str):
    print(f"\n{Colors.BLUE}{'='*60}{Colors.NC}")
    print(f"{Colors.BLUE}{msg}{Colors.NC}")
    print(f"{Colors.BLUE}{'='*60}{Colors.NC}\n")

def print_success(msg: str):
    print(f"{Colors.GREEN}✅ {msg}{Colors.NC}")

def print_error(msg: str):
    print(f"{Colors.RED}❌ {msg}{Colors.NC}")

def print_info(msg: str):
    print(f"{Colors.YELLOW}ℹ️  {msg}{Colors.NC}")

def get_kubernetes_secret(namespace: str, secret_name: str, key: str) -> Optional[str]:
    """Get secret from Kubernetes."""
    import subprocess
    try:
        cmd = [
            'kubectl', 'get', 'secret', '-n', namespace,
            secret_name, '-o', f'jsonpath={{.data.{key}}}'
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if result.stdout:
            return base64.b64decode(result.stdout).decode('utf-8')
        return None
    except Exception as e:
        print_error(f"Failed to get secret {secret_name}/{key}: {e}")
        return None

def wait_for_peerdb(base_url: str, max_retries: int = 30):
    """Wait for PeerDB to be ready."""
    print_info("Waiting for PeerDB to be ready...")
    for i in range(max_retries):
        try:
            response = requests.get(f"{base_url}/api/health", timeout=5)
            if response.status_code == 200:
                print_success("PeerDB is ready!")
                return True
        except Exception:
            pass

        print(f"  Attempt {i+1}/{max_retries}... waiting 10s")
        time.sleep(10)

    print_error("PeerDB did not become ready in time")
    return False

def create_postgres_peer(base_url: str, pg_password: str) -> bool:
    """Create PostgreSQL peer (source)."""
    print_info("Creating PostgreSQL peer...")

    peer_config = {
        "name": "postgres-source",
        "type": "POSTGRES",
        "config": {
            "host": "postgres-cluster-rw.cloudnative-pg.svc.cluster.local",
            "port": 5432,
            "user": "app_user",
            "password": pg_password,
            "database": "app_db"
        }
    }

    try:
        response = requests.post(
            f"{base_url}/api/v1/peers",
            json=peer_config,
            headers={"Content-Type": "application/json"},
            timeout=30
        )

        if response.status_code in [200, 201]:
            print_success(f"PostgreSQL peer created: postgres-source")
            return True
        elif response.status_code == 409:
            print_info("PostgreSQL peer already exists")
            return True
        else:
            print_error(f"Failed to create PostgreSQL peer: {response.status_code}")
            print_error(f"Response: {response.text}")
            return False

    except Exception as e:
        print_error(f"Exception creating PostgreSQL peer: {e}")
        return False

def create_clickhouse_peer(base_url: str) -> bool:
    """Create ClickHouse peer (destination)."""
    print_info("Creating ClickHouse peer...")

    peer_config = {
        "name": "clickhouse-destination",
        "type": "CLICKHOUSE",
        "config": {
            "host": "chi-clickhouse-cluster-clickhouse-0-0.clickhouse.svc.cluster.local",
            "port": 9000,
            "user": "admin",
            "password": "admin123",
            "database": "default"
        }
    }

    try:
        response = requests.post(
            f"{base_url}/api/v1/peers",
            json=peer_config,
            headers={"Content-Type": "application/json"},
            timeout=30
        )

        if response.status_code in [200, 201]:
            print_success(f"ClickHouse peer created: clickhouse-destination")
            return True
        elif response.status_code == 409:
            print_info("ClickHouse peer already exists")
            return True
        else:
            print_error(f"Failed to create ClickHouse peer: {response.status_code}")
            print_error(f"Response: {response.text}")
            return False

    except Exception as e:
        print_error(f"Exception creating ClickHouse peer: {e}")
        return False

def create_mirror(base_url: str) -> bool:
    """Create CDC mirror from PostgreSQL to ClickHouse."""
    print_info("Creating CDC mirror (PG → CH)...")

    mirror_config = {
        "flowJobName": "pg-to-ch-mirror",
        "source": {
            "peerName": "postgres-source",
            "schemaName": "public",
            "tableNames": ["users", "orders", "events"]
        },
        "destination": {
            "peerName": "clickhouse-destination",
            "schemaName": "default"
        },
        "syncMode": "CDC",
        "cdcConfig": {
            "snapshotNumRowsPerPartition": 10000,
            "snapshotMaxParallelWorkers": 4,
            "snapshotNumTablesInParallel": 1,
            "doInitialSnapshot": True,
            "replicationSlotName": "peerdb_slot_pg_to_ch"
        }
    }

    try:
        response = requests.post(
            f"{base_url}/api/v1/mirrors",
            json=mirror_config,
            headers={"Content-Type": "application/json"},
            timeout=30
        )

        if response.status_code in [200, 201]:
            print_success(f"Mirror created: pg-to-ch-mirror")
            print_success("Tables: users, orders, events")
            return True
        elif response.status_code == 409:
            print_info("Mirror already exists")
            return True
        else:
            print_error(f"Failed to create mirror: {response.status_code}")
            print_error(f"Response: {response.text}")
            return False

    except Exception as e:
        print_error(f"Exception creating mirror: {e}")
        return False

def verify_replication(base_url: str) -> bool:
    """Verify that replication is working."""
    print_info("Verifying replication status...")

    try:
        response = requests.get(
            f"{base_url}/api/v1/mirrors/pg-to-ch-mirror",
            timeout=30
        )

        if response.status_code == 200:
            mirror_status = response.json()
            print_success(f"Mirror status: {mirror_status.get('status', 'UNKNOWN')}")
            return True
        else:
            print_error(f"Failed to get mirror status: {response.status_code}")
            return False

    except Exception as e:
        print_error(f"Exception verifying replication: {e}")
        return False

def main():
    print_header("PeerDB Mirror Auto-Setup")

    # Configuration
    peerdb_url = os.getenv('PEERDB_URL', 'http://peerdb.peerdb.svc.cluster.local:3000')

    # For local development/testing, you can use port-forward
    # kubectl port-forward -n peerdb svc/peerdb 3000:3000
    # Then set PEERDB_URL=http://localhost:3000

    print_info(f"PeerDB URL: {peerdb_url}")

    # Step 1: Wait for PeerDB to be ready
    if not wait_for_peerdb(peerdb_url):
        sys.exit(1)

    # Step 2: Get PostgreSQL password from Kubernetes secret
    print_info("Getting PostgreSQL password from Kubernetes secret...")
    pg_password = get_kubernetes_secret(
        namespace='cloudnative-pg',
        secret_name='postgres-cluster-app',
        key='password'
    )

    if not pg_password:
        print_error("Failed to get PostgreSQL password")
        sys.exit(1)

    print_success("PostgreSQL password retrieved")

    # Step 3: Create PostgreSQL peer
    if not create_postgres_peer(peerdb_url, pg_password):
        print_error("Failed to create PostgreSQL peer")
        sys.exit(1)

    # Step 4: Create ClickHouse peer
    if not create_clickhouse_peer(peerdb_url):
        print_error("Failed to create ClickHouse peer")
        sys.exit(1)

    # Wait a bit for peers to be registered
    print_info("Waiting 5 seconds for peers to be registered...")
    time.sleep(5)

    # Step 5: Create mirror
    if not create_mirror(peerdb_url):
        print_error("Failed to create mirror")
        sys.exit(1)

    # Wait a bit for mirror to start
    print_info("Waiting 10 seconds for mirror to initialize...")
    time.sleep(10)

    # Step 6: Verify replication
    verify_replication(peerdb_url)

    # Final message
    print_header("Setup Complete!")
    print(f"{Colors.GREEN}CDC Mirror Configuration:{Colors.NC}")
    print(f"  Source: PostgreSQL (postgres-cluster-rw.cloudnative-pg)")
    print(f"  Destination: ClickHouse (chi-clickhouse-cluster-clickhouse-0-0.clickhouse)")
    print(f"  Tables: users, orders, events")
    print(f"  Mode: CDC (Change Data Capture)")
    print()
    print(f"{Colors.YELLOW}Next steps:{Colors.NC}")
    print("  1. Verify data in ClickHouse:")
    print("     clickhouse-client --query 'SELECT COUNT(*) FROM users'")
    print()
    print("  2. Test real-time replication:")
    print("     psql -c \"INSERT INTO users (username, email) VALUES ('test', 'test@example.com');\"")
    print()
    print("  3. Monitor mirror status in PeerDB UI:")
    print("     kubectl port-forward -n peerdb svc/peerdb 3000:3000")
    print("     http://localhost:3000")
    print()

if __name__ == "__main__":
    main()
