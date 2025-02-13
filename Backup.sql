--1. Tạo ổ đĩa để lưu backup.
EXECUTE master.dbo.xp_create_subdir 'D:\Backup\QTCSDL\Full'
EXECUTE master.dbo.xp_create_subdir 'D:\Backup\QTCSDL\Diff'
GO

-- 2. Stored Procedure cho Full Backup
CREATE OR ALTER PROCEDURE sp_BackupR3_Full
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BackupFile NVARCHAR(255)
    SET @BackupFile = 'D:\Backup\QTCSDL\Full\QTCSDL_FULL_' + FORMAT(GETDATE(),'yyyyMMdd_HHmmss' ) + '.bak'
       
    -- Check Database Integrity
    DBCC CHECKDB('PhongTro') WITH NO_INFOMSGS

    BACKUP DATABASE PhongTro
    TO DISK = @BackupFile
    WITH COMPRESSION, 
         INIT,
         NAME = 'PhongTro-Full Database Backup',
         STATS = 10,
         CHECKSUM,
		 RETAINDAYS = 30
END
GO

-- 3. Stored Procedure cho Differential Backup
CREATE OR ALTER PROCEDURE sp_BackupR3_Diff
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BackupFile NVARCHAR(255)
    SET @BackupFile = 'D:\Backup\QTCSDL\Diff\QTCSDL_DIFF_' + FORMAT(GETDATE(),'yyyyMMdd_HHmmss' ) + '.bak'

    BACKUP DATABASE PhongTro
    TO DISK = @BackupFile
    WITH DIFFERENTIAL,
         COMPRESSION,
         INIT,
         NAME = 'PhongTro-Differential Backup',
         STATS = 10,
         CHECKSUM,
		 RETAINDAYS = 2
END
GO

-- 4. Stored Procedure để cleanup backup files
CREATE OR ALTER PROCEDURE sp_CleanupBackups
AS
BEGIN
    -- Xóa Full backups cũ hơn 30 ngày
    DECLARE @cmd VARCHAR(255)
    SET @cmd = 'FORFILES /P "D:\Backup\QTCSDL\Full" /M *.bak /D -30 /C "CMD /C DEL @path"'
    EXEC master.dbo.xp_cmdshell @cmd

    -- Xóa Differential backups cũ hơn 2 ngày
    SET @cmd = 'FORFILES /P "D:\Backup\QTCSDL\Diff" /M *.bak /D -2 /C "CMD /C DEL @path"'
    EXEC master.dbo.xp_cmdshell @cmd
END
GO

-- 5. Tạo Jobs và Server cho từng Job
USE msdb
go
-- Job cho Full Backup (chạy mỗi tháng lúc 8 giờ sáng)
EXEC dbo.sp_add_job
	@job_name = N'Full_Backup_Job'

--Step 1: Full Backup
EXEC dbo.sp_add_jobstep @job_name = N'Full_Backup_Job',
    @step_name = N'Full Backup',
	@step_id = 1,
    @subsystem = N'TSQL',
	@command = N'USE PhongTro;  
                    EXEC dbo.sp_BackupR3_Full;'
       
--Step 2: Cleanup old full backup
EXEC dbo.sp_add_jobstep 
    @job_name = N'Full_Backup_Job',
    @step_name = N'Cleanup Old Full Backups',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'USE PhongTro;
                 EXEC dbo.sp_BackupR3_Cleanup;';

-- Thiết lập thứ tự thực hiện các job
EXEC dbo.sp_add_jobstep 
    @job_name = N'Full_Backup_Job',
    @step_name = N'Full Backup',
    @on_success_action = 3, -- Chuyển sang step tiếp theo khi thành công
    @on_fail_action = 2;    -- Kết thúc job khi thất bại

-- Lịch chạy job
EXEC dbo.sp_add_jobschedule @job_name = N'Full_Backup_Job',
    @name = N'1months_Full_Backup',
    @freq_type = 16, -- theo tháng
    @freq_interval = 1, -- mỗi 1 tháng
	@freq_recurrence_factor = 1, --phải chạy mỗi tháng 1 lần
    @active_start_time = 80000    -- 8:00 AM

GO
EXEC sp_add_jobserver
		@job_name = N'Full_Backup_Job',
		@server_name = N'(LOCAL)';
GO


-- Job cho Differential Backup (chạy mỗi 2 ngày)
EXEC dbo.sp_add_job 
@job_name = N'Diff_Backup_Job'

--Step 1: Diff backup
EXEC dbo.sp_add_jobstep @job_name = N'Diff_Backup_Job',
    @step_name = N'Differential Backup',
	@step_id = 1,
    @subsystem = N'TSQL',
    @command = N'USE PhongTro; 
                    EXEC dbo.sp_BackupR3_Diff;'
       
--Step 2: Clean old diff backups
EXEC dbo.sp_add_jobstep @job_name = N'Diff_Backup_Job',
    @step_name = N'Cleanup Old Differential Backup',
	@step_id = 2,
    @subsystem = N'TSQL',
    @command = N'USE PhongTro; 
                    EXEC dbo.sp_BackupR3_Diff;'

--Thiết lập thứ tự chạy
EXEC dbo.sp_add_jobstep 
    @job_name = N'Diff_Backup_Job',
    @step_name = N'Differential Backup',
    @on_success_action = 3, -- Chuyển sang step tiếp theo khi thành công
    @on_fail_action = 2;    -- Kết thúc job khi thất bại

EXEC dbo.sp_add_jobschedule @job_name = N'Diff_Backup_Job',
    @name = N'2days_Diff_Backup',
    @freq_type = 4, -- theo ngày
    @freq_interval = 2, -- mỗi 2 ngày
    @active_start_time = 80000   -- 8:00 AM
GO
EXEC sp_add_jobserver
		@job_name = N'Diff_Backup_Job',
		@server_name = N'(LOCAL)';
GO

-- 1. Thực thi Full Backup
EXEC sp_BackupR3_Full;
GO

-- 2. Thực thi Differential Backup
EXEC sp_BackupR3_Diff;
GO

-- 5. Thực thi Cleanup Backups
EXEC sp_CleanupBackups;
GO


--6. Tạo FUNCTION xem JOB History
CREATE FUNCTION fn_JobHistory
(
    @JobName NVARCHAR(128) = NULL
)
RETURNS @JobHistory TABLE
(
    JobName NVARCHAR(128),
    run_date INT,
    run_time INT,
    run_duration INT,
    message NVARCHAR(MAX),
    step_id INT,
    step_name NVARCHAR(MAX)
)
AS
BEGIN
    INSERT INTO @JobHistory
    SELECT
        j.name AS JobName,
        h.run_date,
        h.run_time,
        h.run_duration,
        h.message,
        h.step_id,
        h.step_name
    FROM
        msdb.dbo.sysjobhistory h
        INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
    WHERE
        (@JobName IS NULL OR j.name = @JobName)

    RETURN
END
GO

SELECT * FROM dbo.fn_JobHistory('Full_Backup_Job') ORDER BY run_date DESC, run_time DESC;
SELECT * FROM dbo.fn_JobHistory('Diff_Backup_Job') ORDER BY run_date DESC, run_time DESC;
SELECT * FROM dbo.fn_JobHistory('Cleanup_Job') ORDER BY run_date DESC, run_time DESC;


-- Thủ tục tạo restore database
use msdb
RESTORE DATABASE PhongTro
FROM DISK = 'D:\Backup\QTCSDL\Full\QTCSDL_FULL_20241116_003849.bak'
WITH REPLACE;
