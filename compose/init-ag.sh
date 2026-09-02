#!/usr/bin/env bash
# Initialize a clusterless AG (CLUSTER_TYPE = NONE) across sqlserver1/sqlserver2.
# Prereq: both containers up with MSSQL_ENABLE_HADR=1 (base compose already sets it).
# Run from the repo root:
#   ./compose/init-ag.sh
set -euo pipefail
# Compose file now lives in compose/; point the CLI at it and the root .env.
export COMPOSE_FILE="${COMPOSE_FILE:-compose/docker-compose.yml}"
export COMPOSE_ENV_FILES="${COMPOSE_ENV_FILES:-.env}"
source .env 2>/dev/null || true
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"
CERT_PASSWORD="${CERT_PASSWORD:-$SA_PASSWORD}"

sql1() { docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "$1"; }
sql2() { docker compose exec -T sqlserver2 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "$1"; }

echo "== 0/7 Clear any stale cert files (makes this script re-runnable) =="
docker compose exec -T --user root sqlserver1 bash -c 'rm -f /var/opt/mssql/data/*_ag_cert.cer' || true
docker compose exec -T --user root sqlserver2 bash -c 'rm -f /var/opt/mssql/data/*_ag_cert.cer' || true

echo "== 1/7 Master keys + certificates on both instances =="
sql1 "
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
  CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'${CERT_PASSWORD}';
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'ag_cert')
  CREATE CERTIFICATE ag_cert WITH SUBJECT = N'AG endpoint cert - sqlserver1';
BACKUP CERTIFICATE ag_cert TO FILE = N'/var/opt/mssql/data/sqlserver1_ag_cert.cer';"
sql2 "
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
  CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'${CERT_PASSWORD}';
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'ag_cert')
  CREATE CERTIFICATE ag_cert WITH SUBJECT = N'AG endpoint cert - sqlserver2';
BACKUP CERTIFICATE ag_cert TO FILE = N'/var/opt/mssql/data/sqlserver2_ag_cert.cer';"

echo "== 2/7 Exchange certificate public keys =="
docker compose cp sqlserver1:/var/opt/mssql/data/sqlserver1_ag_cert.cer /tmp/sqlserver1_ag_cert.cer
docker compose cp sqlserver2:/var/opt/mssql/data/sqlserver2_ag_cert.cer /tmp/sqlserver2_ag_cert.cer
docker compose cp /tmp/sqlserver2_ag_cert.cer sqlserver1:/var/opt/mssql/data/sqlserver2_ag_cert.cer
docker compose cp /tmp/sqlserver1_ag_cert.cer sqlserver2:/var/opt/mssql/data/sqlserver1_ag_cert.cer

# docker cp lands files owned by root; make them readable by the mssql process.
docker compose exec -T --user root sqlserver1 chmod 644 /var/opt/mssql/data/sqlserver2_ag_cert.cer
docker compose exec -T --user root sqlserver2 chmod 644 /var/opt/mssql/data/sqlserver1_ag_cert.cer

echo "== 3/7 Cross-register login + certificate for endpoint auth =="
sql1 "
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ag_login')
  CREATE LOGIN ag_login WITH PASSWORD = N'${CERT_PASSWORD}';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ag_user')
BEGIN
  CREATE USER ag_user FOR LOGIN ag_login;
END
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'ag_cert_peer')
  CREATE CERTIFICATE ag_cert_peer AUTHORIZATION ag_user
    FROM FILE = N'/var/opt/mssql/data/sqlserver2_ag_cert.cer';"
sql2 "
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ag_login')
  CREATE LOGIN ag_login WITH PASSWORD = N'${CERT_PASSWORD}';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ag_user')
BEGIN
  CREATE USER ag_user FOR LOGIN ag_login;
END
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'ag_cert_peer')
  CREATE CERTIFICATE ag_cert_peer AUTHORIZATION ag_user
    FROM FILE = N'/var/opt/mssql/data/sqlserver1_ag_cert.cer';"

echo "== 4/7 HADR endpoints on 5022 =="
for f in sql1 sql2; do $f "
IF NOT EXISTS (SELECT 1 FROM sys.endpoints WHERE name = 'Hadr_endpoint')
  CREATE ENDPOINT Hadr_endpoint
    STATE = STARTED
    AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
    FOR DATABASE_MIRRORING (
      AUTHENTICATION = CERTIFICATE ag_cert,
      ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES);
GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO ag_login;"; done

echo "== 5/7 Wait for ProductsDB to exist (sql-init may still be seeding it) =="
max_retries=30
retry=0
until sql1 "SET NOCOUNT ON; SELECT 1 WHERE DB_ID('ProductsDB') IS NOT NULL" 2>/dev/null | grep -qE '^[[:space:]]*1[[:space:]]*$'; do
  retry=$((retry + 1))
  if [ $retry -ge $max_retries ]; then
    echo "❌ ProductsDB never appeared on sqlserver1 after ${max_retries}s; is sql-init running/failed?"
    exit 1
  fi
  sleep 1
done

echo "== 6/7 Create AG on primary (automatic seeding) =="
sql1 "
IF DB_ID('ProductsDB') IS NOT NULL AND NOT EXISTS
   (SELECT 1 FROM sys.availability_groups WHERE name = 'AG_Products')
BEGIN
  ALTER DATABASE [ProductsDB] SET RECOVERY FULL;
  BACKUP DATABASE [ProductsDB] TO DISK = N'/var/opt/mssql/data/ProductsDB_ag_seed.bak'
    WITH CHECKSUM, COMPRESSION, INIT;
  BACKUP LOG [ProductsDB] TO DISK = N'/var/opt/mssql/data/ProductsDB_ag_seed.trn'
    WITH CHECKSUM, COMPRESSION, INIT;
  CREATE AVAILABILITY GROUP [AG_Products]
    WITH (CLUSTER_TYPE = NONE)
    FOR DATABASE [ProductsDB]
    REPLICA ON
      N'sqlserver1' WITH (ENDPOINT_URL = N'tcp://sqlserver1:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)),
      N'sqlserver2' WITH (ENDPOINT_URL = N'tcp://sqlserver2:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL));
END"

echo "== 7/7 Join secondary + allow seeding =="
sql2 "
IF NOT EXISTS (SELECT 1 FROM sys.availability_groups WHERE name = 'AG_Products')
BEGIN
  ALTER AVAILABILITY GROUP [AG_Products] JOIN WITH (CLUSTER_TYPE = NONE);
  ALTER AVAILABILITY GROUP [AG_Products] GRANT CREATE ANY DATABASE;
END"

echo "AG init complete. Automatic seeding may take ~30s; run ./compose/verify-ag.sh"
