-- Demo 5 seed: three backup-policy violations + one compliant control database.
-- Run on SqlServer1:
--   docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
--     -S localhost -U sa -P "$SA_PASSWORD" -C -i /var/opt/mssql/seed-backup-gaps.sql
-- (or paste into sqlcmd interactively)

-- DB 1: Tier-1, FULL recovery, full backup taken, NO log backups ever.
-- Violation: unbounded RPO exposure; log_reuse_wait_desc = LOG_BACKUP.
IF DB_ID('PaymentsDB') IS NULL CREATE DATABASE [PaymentsDB];
GO
ALTER DATABASE [PaymentsDB] SET RECOVERY FULL;
BACKUP DATABASE [PaymentsDB] TO DISK = N'/var/opt/mssql/data/PaymentsDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;
GO
USE [PaymentsDB];
IF OBJECT_ID('dbo.Ledger') IS NULL
  CREATE TABLE dbo.Ledger (
    ID INT IDENTITY PRIMARY KEY,
    Amount MONEY,
    At DATETIME2 DEFAULT SYSUTCDATETIME());
INSERT INTO dbo.Ledger (Amount)
SELECT TOP (50000) 1.00 FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
USE [master];
GO

-- DB 2: Tier-1, NO full backup at all. Unrecoverable.
IF DB_ID('ClaimsDB') IS NULL CREATE DATABASE [ClaimsDB];
GO
ALTER DATABASE [ClaimsDB] SET RECOVERY FULL;
GO

-- DB 3: "Prod" semantics but SIMPLE recovery. PIT recovery impossible.
IF DB_ID('OrdersProdDB') IS NULL CREATE DATABASE [OrdersProdDB];
GO
ALTER DATABASE [OrdersProdDB] SET RECOVERY SIMPLE;
BACKUP DATABASE [OrdersProdDB] TO DISK = N'/var/opt/mssql/data/OrdersProdDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;
GO

-- DB 4: the compliant control.
IF DB_ID('InventoryDB') IS NULL CREATE DATABASE [InventoryDB];
GO
ALTER DATABASE [InventoryDB] SET RECOVERY FULL;
BACKUP DATABASE [InventoryDB] TO DISK = N'/var/opt/mssql/data/InventoryDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;
BACKUP LOG [InventoryDB] TO DISK = N'/var/opt/mssql/data/InventoryDB_log.trn'
  WITH CHECKSUM, COMPRESSION, INIT;
GO
-- NOTE: re-run the BACKUP LOG above ~10 minutes before going on stage so
-- InventoryDB sits inside its 15-minute RPO window at demo time.

-- Reset (after the demo):
-- DROP DATABASE IF EXISTS [PaymentsDB];
-- DROP DATABASE IF EXISTS [ClaimsDB];
-- DROP DATABASE IF EXISTS [OrdersProdDB];
-- DROP DATABASE IF EXISTS [InventoryDB];
