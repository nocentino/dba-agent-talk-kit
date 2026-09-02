#!/usr/bin/env bash
# All-in-one stack startup: core instances, fleet, MCP servers, and AG initialization.
# Run from the repo root:
#   ./compose/startup.sh
#
# What it does:
#   1. Starts core stack (sqlserver1, sqlserver2, dab-mcp, sql-mcp-server)
#   2. Starts fleet profile (sqlserver3, sqlserver4)
#   3. Waits for SQL Server instances to be ready
#   4. Initializes the Always On AG (AG_Products)
#   5. Reports final stack status
set -euo pipefail

# Compose file lives in compose/; point the CLI at it and the root .env.
export COMPOSE_FILE="${COMPOSE_FILE:-compose/docker-compose.yml}"
export COMPOSE_ENV_FILES="${COMPOSE_ENV_FILES:-.env}"

# Validate .env exists and source it for SA_PASSWORD
if [[ ! -f .env ]]; then
  echo "❌ .env not found. Run from repo root."
  exit 1
fi
source .env

echo "=========================================="
echo "DBA Agent Talk Kit: Full Stack Startup"
echo "=========================================="
echo ""

# Step 1: Start core stack
# --wait is skipped: Compose treats the one-shot init containers exiting(0) as a
# dependency failure and returns non-zero, so we poll for readiness in step 3 instead.
echo "📦 Step 1/5: Starting core stack (sqlserver1, sqlserver2, mcp servers)..."
docker compose up -d
echo "✓ Core stack up"
echo ""

# Step 2: Start fleet profile
echo "📦 Step 2/5: Starting fleet profile (sqlserver3, sqlserver4)..."
docker compose --profile fleet up -d
echo "✓ Fleet instances up"
echo ""

# Step 3: Wait for SQL Server to accept connections
echo "📦 Step 3/5: Waiting for SQL Server instances to be ready..."
max_retries=30
retry=0
while [ $retry -lt $max_retries ]; do
  if docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT @@VERSION;" >/dev/null 2>&1 && \
     docker compose exec -T sqlserver2 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT @@VERSION;" >/dev/null 2>&1 && \
     docker compose exec -T sqlserver3 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT @@VERSION;" >/dev/null 2>&1 && \
     docker compose exec -T sqlserver4 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT @@VERSION;" >/dev/null 2>&1; then
    echo "✓ All instances responding to queries"
    break
  fi
  retry=$((retry + 1))
  if [ $retry -lt $max_retries ]; then
    echo "  Waiting... ($retry/$max_retries)"
    sleep 2
  fi
done

if [ $retry -eq $max_retries ]; then
  echo "❌ Timeout waiting for SQL Server to be ready"
  exit 1
fi

echo "📦 Waiting for ProductsDB to finish seeding on sqlserver1..."
retry=0
while ! docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SET NOCOUNT ON; SELECT 1 WHERE DB_ID('ProductsDB') IS NOT NULL" 2>/dev/null | grep -qE '^[[:space:]]*1[[:space:]]*$'; do
  retry=$((retry + 1))
  if [ $retry -ge $max_retries ]; then
    echo "❌ ProductsDB never appeared on sqlserver1; is sql-init running/failed?"
    exit 1
  fi
  sleep 1
done
echo "✓ ProductsDB ready"
echo ""

# Step 4: Initialize AG
echo "📦 Step 4/5: Initializing Always On AG (AG_Products)..."
if ./compose/init-ag.sh; then
  echo "✓ AG initialized"
else
  echo "❌ AG initialization failed"
  exit 1
fi
echo ""

# Automatic seeding of the secondary takes a few seconds; give it a head start
# before verify-ag.sh so a fresh standup doesn't report a false NOT_HEALTHY blip.
echo "⏳ Waiting for secondary to finish automatic seeding..."
retry=0
while [ $retry -lt 15 ]; do
  sync_state=$(docker compose exec -T sqlserver2 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -h -1 -Q "SET NOCOUNT ON; SELECT synchronization_state_desc FROM sys.dm_hadr_database_replica_states WHERE is_local = 1;" 2>/dev/null | tr -d '[:space:]')
  if [ "$sync_state" = "SYNCHRONIZED" ]; then
    echo "✓ Secondary synchronized"
    break
  fi
  retry=$((retry + 1))
  sleep 2
done
echo ""

# Step 5: Verify stack
echo "📦 Step 5/5: Verifying stack..."
if ./compose/verify-ag.sh; then
  echo "✓ AG verification passed"
else
  echo "⚠️  AG verification check found issues (see above)"
fi
echo ""

echo "=========================================="
echo "✅ Stack Ready!"
echo "=========================================="
echo ""
echo "Stack summary:"
docker compose ps --filter 'status=running'
echo ""
echo "Next steps:"
echo "  • Run demos: see demos/README.md"
echo "  • Check MCP servers: docker compose logs -f sql-mcp-server"
echo "  • Stop stack: docker compose down"
echo ""
