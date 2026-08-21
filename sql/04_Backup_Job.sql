-------------------------------------------------------------------
-- ExaminationSystemDB - Daily Automatic Backup
-- Requires SQL Server Agent to be running (Developer/Standard/
-- Enterprise editions - not available on SQL Server Express).
-- Create the C:\SQLBackups\ folder first, or change @backupFolder.
--
-- >>> PREREQUISITE: 01_ExaminationSystem_FileGroups.sql,
-- >>> 02_ExaminationSystem_Build_Schema_Objects.sql, and
-- >>> 03_ExaminationSystem_Security_Setup.sql must already be run.
-------------------------------------------------------------------

use msdb
go

if exists (select 1 from msdb.dbo.sysjobs where name = N'ExaminationSystemDB_DailyBackup')
	exec msdb.dbo.sp_delete_job @job_name = N'ExaminationSystemDB_DailyBackup'
go

exec msdb.dbo.sp_add_job
	@job_name = N'ExaminationSystemDB_DailyBackup',
	@enabled = 1,
	@description = N'Daily full backup of ExaminationSystemDB'
go

exec msdb.dbo.sp_add_jobstep
	@job_name = N'ExaminationSystemDB_DailyBackup',
	@step_name = N'Backup Database',
	@subsystem = N'TSQL',
	@database_name = N'ExaminationSystemDB',
	@command = N'
		declare @backupFolder nvarchar(400) = N''C:\SQLBackups\''
		declare @path nvarchar(400) =
			@backupFolder + N''ExaminationSystemDB_'' +
			replace(convert(varchar(10), getdate(), 120), ''-'', '''') + N''.bak''

		backup database ExaminationSystemDB
		to disk = @path
		with init, name = N''ExaminationSystemDB Daily Full Backup'', compression;
	'
go

exec msdb.dbo.sp_add_schedule
	@schedule_name = N'ExaminationSystemDB_Daily_2AM',
	@freq_type = 4,              -- daily
	@freq_interval = 1,          -- every 1 day
	@active_start_time = 020000  -- 02:00 AM
go

exec msdb.dbo.sp_attach_schedule
	@job_name = N'ExaminationSystemDB_DailyBackup',
	@schedule_name = N'ExaminationSystemDB_Daily_2AM'
go

exec msdb.dbo.sp_add_jobserver
	@job_name = N'ExaminationSystemDB_DailyBackup',
	@server_name = N'(local)'
go

print '=== Daily backup job created: runs every day at 02:00 AM to C:\SQLBackups\. Confirm SQL Server Agent is running or the job will never fire. ==='
go

-------------------------------------------------------------------
-- One-off manual test (run this to confirm the backup path works
-- before relying on the schedule):
-------------------------------------------------------------------
-- backup database ExaminationSystemDB
-- to disk = N'C:\SQLBackups\ExaminationSystemDB_ManualTest.bak'
-- with init, name = N'Manual test backup'
-- go
