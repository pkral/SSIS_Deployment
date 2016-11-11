--===============================================================================================
-- Created By:   Peter Kral
-- Created Date: 02/17/2014
-- Purpose:   Deploy SSIS job for the SSIS Package 'SSIS_Package'

-- Modification History:
-- Modified by:  Date:      Modification Desc:
-----------------------------------------------------------------------

--=================================================================================================
USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

-- Variable to help construct command string
DECLARE @command_string nvarchar(1000)
       ,@env_ref nvarchar(30)
       ,@project_name nvarchar(50) = N'SSIS_Project'
       ,@environment_name nvarchar(50) = N'ENV_SSIS_Project'
       ,@folder_name nvarchar(128) = N'SSIS_Folder'
       ,@package_name nvarchar(128) = N'SSIS_Package' -- Don't add file extension on the name
       ,@job_description nvarchar(256) = N'Executes the SSIS_Package';

DECLARE @job_name nvarchar(128) = N'SSIS: ' + @package_name
       ,@job_step_name nvarchar(128) = N'Execute Package ' + @package_name;


-- All this work to find the ENVREFERENCE value (the reference_id from SSISDB)
 SELECT @env_ref = r.reference_id
   FROM [SSISDB].[internal].environment_references as r
  INNER JOIN    [SSISDB].[internal].projects AS p
     ON r.project_id = p.project_id
  INNER JOIN    [SSISDB].[internal].folders AS f
     ON p.folder_id = f.folder_id
  INNER JOIN    [SSISDB].[internal].environments AS e
     ON e.folder_id = f.folder_id
    AND e.environment_name = r.environment_name
  WHERE e.environment_name = @environment_name
    AND p.name = @project_name

IF @env_ref IS NULL
   RAISERROR('Could not find environment reference',16,1)
ELSE
   SELECT @command_string = N'/ISSERVER "\"\SSISDB\' + @folder_name + N'\' + @project_name + N'\' + @package_name + N'.dtsx\"" /SERVER "\"' + @@SERVERNAME
                          + N'\"" /ENVREFERENCE '  + @env_ref
                          + N' /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";2 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E'

SELECT @command_string AS command_string_for_SSIS_job_step

-- Create the job
DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SSIS: SSIS_Package', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=@job_description, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=@job_step_name, 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'SSIS', 
		@command=@command_string,
		@database_name=N'master', 
		@flags=32
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Weekly', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=9, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20130418, 
		@active_end_date=99991231, 
		@active_start_time=231500, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
