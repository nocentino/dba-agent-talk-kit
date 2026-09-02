#!/usr/bin/env bash
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "1/4 Creating backup-compliance test databases..."
echo "      - PaymentsDB (Tier-1, FULL, full backup taken, NO log backups) [VIOLATION: unbounded RPO]"
docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF DB_ID('PaymentsDB') IS NULL CREATE DATABASE [PaymentsDB];
ALTER DATABASE [PaymentsDB] SET RECOVERY FULL;
BACKUP DATABASE [PaymentsDB] TO DISK = N'/var/opt/mssql/data/PaymentsDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;" > /dev/null 2>&1

docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d PaymentsDB -Q "
CREATE TABLE dbo.Ledger (
  ID INT IDENTITY PRIMARY KEY,
  Amount MONEY,
  At DATETIME2 DEFAULT SYSUTCDATETIME());
INSERT INTO dbo.Ledger (Amount)
SELECT TOP (50000) 1.00 FROM sys.all_objects a CROSS JOIN sys.all_objects b;" > /dev/null 2>&1
echo "      ✓ PaymentsDB created (no log backup chain)"

echo "2/4 Creating unrecoverable database..."
echo "      - ClaimsDB (Tier-1, FULL recovery, NO full backup ever) [CRITICAL: unrecoverable]"
docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF DB_ID('ClaimsDB') IS NULL CREATE DATABASE [ClaimsDB];
ALTER DATABASE [ClaimsDB] SET RECOVERY FULL;" > /dev/null 2>&1
echo "      ✓ ClaimsDB created (no full backup)"

echo "3/4 Creating prod database with wrong recovery model..."
echo "      - OrdersProdDB (looks like Prod but SIMPLE recovery) [VIOLATION: no PIT recovery]"
docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF DB_ID('OrdersProdDB') IS NULL CREATE DATABASE [OrdersProdDB];
ALTER DATABASE [OrdersProdDB] SET RECOVERY SIMPLE;
BACKUP DATABASE [OrdersProdDB] TO DISK = N'/var/opt/mssql/data/OrdersProdDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;" > /dev/null 2>&1
echo "      ✓ OrdersProdDB created (SIMPLE recovery)"

echo "4/4 Creating compliant control database..."
echo "      - InventoryDB (Tier-1, FULL, full backup + current log backup) [COMPLIANT]"
docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF DB_ID('InventoryDB') IS NULL CREATE DATABASE [InventoryDB];
ALTER DATABASE [InventoryDB] SET RECOVERY FULL;
BACKUP DATABASE [InventoryDB] TO DISK = N'/var/opt/mssql/data/InventoryDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;
BACKUP LOG [InventoryDB] TO DISK = N'/var/opt/mssql/data/InventoryDB_log.trn'
  WITH CHECKSUM, COMPRESSION, INIT;" > /dev/null 2>&1
echo "      ✓ InventoryDB created (fully compliant)"

echo ""
echo "✓ Backup posture seeded."
echo "  - 3 databases with policy violations (varying severity)"
echo "  - 1 compliant control for reference"
echo "  Run query: get_backup_status() on SqlServer1"
