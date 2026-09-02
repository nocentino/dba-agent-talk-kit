-- =====================================================================
-- SqlServer3 — DBA monitoring login (reserved fleet member)
-- Mirrors the dba_monitor account on SqlServer1/2.
-- Server-level DMV permissions only; any demo-specific databases are created
-- by their respective seed scripts.
-- =====================================================================

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dba_monitor')
BEGIN
    CREATE LOGIN dba_monitor WITH PASSWORD = 'MonitorP@ss123!',
        CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF;
    PRINT 'Login dba_monitor created.';
END
ELSE
    PRINT 'Login dba_monitor already exists.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dba_monitor')
    CREATE USER dba_monitor FOR LOGIN dba_monitor;
GO

GRANT VIEW SERVER STATE   TO dba_monitor;
GRANT VIEW DATABASE STATE TO dba_monitor;
GRANT VIEW ANY DATABASE   TO dba_monitor;
GRANT VIEW ANY DEFINITION TO dba_monitor;
GO

-- msdb access for get_job_status (SQL Agent runs on this instance)
USE msdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dba_monitor')
    CREATE USER dba_monitor FOR LOGIN dba_monitor;
GO
EXEC sp_addrolemember 'SQLAgentReaderRole', 'dba_monitor';
GRANT SELECT ON dbo.sysjobactivity  TO dba_monitor;
GRANT SELECT ON dbo.sysjobs         TO dba_monitor;
GRANT SELECT ON dbo.sysjobhistory   TO dba_monitor;
GRANT SELECT ON dbo.sysjobsteps     TO dba_monitor;
GRANT SELECT ON dbo.sysjobservers   TO dba_monitor;
GRANT SELECT ON dbo.sysschedules    TO dba_monitor;
GRANT SELECT ON dbo.sysjobschedules TO dba_monitor;
GO

USE master;
GO
PRINT 'dba_monitor account ready on sqlserver3.';
GO
