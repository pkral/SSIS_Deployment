--=======================================================================
-- Created By:   Peter Kral
-- Created Date: 02/17/2014
-- Purpose:   Deploy the SSIS project "SSIS_Project"

-- Modification History:
-- Modified by:  Date:      Modification Desc:
-----------------------------------------------------------------------

--=======================================================================

--=======================================================================
-- BEFORE YOU RUN THIS SCRIPT:
-- 1.
-- Copy this file from TFS:
-- {Project Branch}/SSIS_Project.ispac
-- Copy to:
-- \\{Server Name}\C$\SSIS_Deploy\SSIS_Project.ispac
-- 2.
-- You must be in SQLCMD mode
--=======================================================================
USE SSISDB;
GO

-- Copy the ispac file from TFS to this location on the target server:
:setvar isPacPath "C:\SSIS_Deploy\SSIS_Project.ispac"

DECLARE
    @folder_name nvarchar(128) = 'SSIS_Folder'
,   @folder_description nvarchar(128) = N'SSIS_Project'
,   @folder_id bigint = NULL
,   @project_name nvarchar(128) = 'SSIS_Project'
,   @project_stream varbinary(max)
,   @operation_id bigint = NULL;

-- Read the zip (ispac) data in from the source file
SELECT @project_stream = T.stream
FROM
(
    SELECT *
      FROM OPENROWSET(BULK N'$(isPacPath)', SINGLE_BLOB ) AS B
) AS T (stream);


-- Get the folder_id for the target folder
    SELECT @folder_id = folder_id
      FROM [catalog].folders AS CF
     WHERE CF.name = @folder_name;

-- Create the folder if it doesn't exist
IF @folder_id IS NULL
BEGIN
    -- Create the folder for our project
    EXECUTE [catalog].[create_folder]
        @folder_name
       ,@folder_id OUTPUT;

    EXECUTE [catalog].[set_folder_description]
      @folder_name = @folder_name
     ,@folder_description = @folder_description;
END;


-- Deploy the project to the new folder
EXECUTE [catalog].[deploy_project]
    @folder_name
   ,@project_name
   ,@project_stream
   ,@operation_id OUTPUT;

IF @@SERVERNAME = 'SSIS_Server'
BEGIN
-- Add ssis_datareader permissions to the new folder
-- @object_type=1 Folder
-- @object_id= @folder_id
-- @principal_id=10 ssis_datareader
    EXEC [SSISDB].[catalog].[grant_permission] @object_type=1, @object_id=@folder_id, @principal_id=10, @permission_type=1; -- Read

    EXEC [SSISDB].[catalog].[grant_permission] @object_type=1, @object_id=@folder_id, @principal_id=10, @permission_type=101; -- Read Objects

END;

-- Check to see if something went awry (no news is good news)
SELECT OM.*
  FROM [catalog].operation_messages AS OM
 WHERE OM.operation_id = @operation_id;

