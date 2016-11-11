--=======================================================================
-- Created By:   Peter Kral
-- Created Date: 02/17/2014
-- Purpose:      Create/Modify SSIS environments and associate variables
--                with package/project parameters

-- Modification History:
-- Modified by:  Date:      Modification Desc:
-----------------------------------------------------------------------

--=======================================================================
USE SSISDB;
GO

SET NOCOUNT ON;

-- Standard variables
DECLARE @ErrMsg varchar(1000) = ''
       ,@ErrSeverity int
       ,@ErrState int;

-- Project, package, environment variables
DECLARE @environment_name nvarchar(128) = N'ENV_SSIS_Project'
       ,@environment_description nvarchar(128) = N'Environment for Project SSIS_Project'
       ,@folder_name nvarchar(128) = N'SSIS_Folder'
       ,@project_name nvarchar(128) = N'SSIS_Project';

-- Get ID values needed throughout
DECLARE @folder_id  BIGINT = (SELECT  folder_id FROM [catalog].folders  WHERE name = @folder_name);
DECLARE @project_id BIGINT = (SELECT project_id FROM [catalog].projects WHERE name = @project_name AND folder_id = @folder_id);


-- variables supporting iterative procedure calls
DECLARE @current_row_id int
       ,@max_row_id int
       ,@parameter_name  nvarchar(128)
       ,@variable_name  nvarchar(128)
       ,@data_type  nvarchar(128)
       ,@sensitive  bit
       ,@value  sql_variant
       ,@var_description  nvarchar(1024)
       ,@reference_id bigint
       ,@object_type smallint
       ,@object_type_project smallint = 20
       ,@object_type_package smallint = 30
       ,@package_name nvarchar(128)
       ,@project_version_lsn bigint;


-- table variable for the environment variables and matching project/package parameters
DECLARE @env_variables table (
      unique_id int IDENTITY (1,1)
     ,parameter_name  nvarchar(128)
     ,variable_name  nvarchar(128)
     ,data_type  nvarchar(128) -- String, Int32, etc.
     ,sensitive  bit
     ,value  sql_variant
     ,var_description  nvarchar(1024)
     ,parameter_scope nvarchar(128) -- Package or Project
	 ,package_name nvarchar(128)
);

-- Populate table variable

	INSERT INTO @env_variables
		  (parameter_name
		  ,variable_name
		  ,data_type
		  ,sensitive
          ,value
		  ,var_description
		  ,parameter_scope
		  ,package_name)
	VALUES
	 (N'CM.MyConnectionManagerName.ServerName',N'MyDatabaseName_ServerName',N'String',N'0',N'MyDatabaseServerName_Value',N'MyDatabaseName Description',N'Project',N'SSIS_Project')
	,(N'CM.MyConnectionManagerName_2.ServerName',N'MyDatabaseName_2_ServerName',N'String',N'0',N'MyDatabaseServerName_2_Value',N'MyDatabaseName_2 Description',N'Project',N'SSIS_Project')
	,(N'MyStringVariable',N'MyStringVariable',N'String',N'0',N'MyStringVariable_Value',N'MyStringVariable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyBooleanVariable',N'MyBooleanVariable',N'Boolean',N'0',N'MyBooleanVariable_Value',N'MyBooleanVariable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyByteVariable',N'MyByteVariable',N'Byte',N'0',N'MyByteVariable_Value',N'MyByteVariable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyDateTimeVariable',N'MyDateTimeVariable',N'DateTime',N'0',N'MyDateTimeVariable_Value',N'MyDateTimeVariable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyDoubleVariable',N'MyDoubleVariable',N'Double',N'0',N'MyDoubleVariable_Value',N'MyDoubleVariable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyInt16Variable',N'MyInt16Variable',N'Int16',N'0',N'MyInt16Variable_Value',N'MyInt16Variable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyInt32Variable',N'MyInt32Variable',N'Int32',N'0',N'MyInt32Variable_Value',N'MyInt32Variable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyInt64Variable',N'MyInt64Variable',N'Int64',N'0',N'MyInt64Variable_Value',N'MyInt64Variable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MySingleVariable',N'MySingleVariable',N'Single',N'0',N'MySingleVariable_Value',N'MySingleVariable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyUInt32Variable',N'MyUInt32Variable',N'UInt32',N'0',N'MyUInt32Variable_Value',N'MyUInt32Variable_Description',N'Package',N'SSISPackageName.dtsx')
	,(N'MyUInt64Variable',N'MyUInt64Variable',N'UInt64',N'0',N'MyUInt64Variable_Value',N'MyUInt64Variable_Description',N'Package',N'SSISPackageName.dtsx')	


SELECT 'Please examine the @env_variables table content to validate the values being deployed.';
SELECT *
  FROM @env_variables;

-- Create the environment
-----------------------------------------------------------------------
IF NOT EXISTS (
            SELECT * FROM [SSISDB].[internal].folders as f
             INNER JOIN [SSISDB].[internal].environments as e
                ON e.folder_id = f.folder_id
             WHERE f.folder_id = @folder_id
               AND e.environment_name = @environment_name
            )
EXEC SSISDB.[catalog].create_environment
      @folder_name=@folder_name
     ,@environment_name=@environment_name
     ,@environment_description=@environment_description;

-- Create the environment reference in the project
-----------------------------------------------------------------------
IF NOT EXISTS (
            SELECT * FROM  [SSISDB].[internal].environment_references as r
             INNER JOIN    [SSISDB].[internal].projects AS p
                ON r.project_id = p.project_id
             INNER JOIN    [SSISDB].[internal].folders AS f
                ON p.folder_id = f.folder_id
             INNER JOIN    [SSISDB].[internal].environments AS e
                ON e.folder_id = f.folder_id
               AND e.environment_name = r.environment_name
             WHERE r.project_id = @project_id
               AND f.folder_id = @folder_id
               AND r.environment_name = @environment_name
           )
EXEC SSISDB.[catalog].create_environment_reference
      @folder_name =  @folder_name
     ,@project_name =  @project_name
     ,@environment_name = @environment_name
     ,@reference_type =  'R'
     ,@reference_id = @reference_id OUT;

-- Loop initialization
         SELECT @current_row_id = MIN(unique_id)
               ,@max_row_id = MAX(unique_id)
           FROM @env_variables;

BEGIN TRY
         WHILE @current_row_id <= @max_row_id
         BEGIN
            SELECT @variable_name = variable_name
                  ,@parameter_name = parameter_name
                  ,@data_type = data_type
                  ,@sensitive = sensitive
                  ,@value  =  CASE WHEN @data_type = 'String' THEN value ELSE CAST(value as int) END
                  ,@var_description= var_description
                  ,@object_type = CASE WHEN parameter_scope = 'Package' THEN @object_type_package ELSE @object_type_project END
				  ,@package_name = package_name
              FROM @env_variables
             WHERE unique_id = @current_row_id;
			
		   -- Refer to the latest version of the project
           SELECT  @project_version_lsn = (SELECT MAX(project_version_lsn) FROM internal.object_parameters WHERE project_id = @project_id AND parameter_name = @parameter_name);

            -- Create / Set the environment variables
            -----------------------------------------------------------------------
            SET @ErrMsg = 'Problem creating environment variable ' + @variable_name

           IF NOT EXISTS (
            SELECT * FROM [SSISDB].[catalog].environment_variables as v
             INNER JOIN [SSISDB].[internal].environments as e
                ON e.environment_id = v.environment_id
             WHERE v.name = @variable_name
               AND e.environment_name = @environment_name
            )
                EXEC SSISDB.[catalog].create_environment_variable
                      @folder_name=@folder_name
                     ,@environment_name=@environment_name
                     ,@variable_name=@variable_name
                     ,@data_type=@data_type
                     ,@sensitive=@sensitive
                     ,@value=@value
                     ,@description=@var_description;
                ELSE
                EXEC SSISDB.[catalog].set_environment_variable_value
                      @folder_name=@folder_name
                     ,@environment_name=@environment_name
                     ,@variable_name=@variable_name
                     ,@value=@value;

            -- Associate environment variables with package and/or project parameters
            -------------------------------------------------------------------------
            SET @ErrMsg = 'Problem associating environment variable ' + @variable_name

            IF NOT EXISTS (
                        SELECT * FROM [SSISDB].[internal].object_parameters as op
                         INNER JOIN   [SSISDB].[internal].projects as p
                            ON p.project_id = op.project_id
                         INNER JOIN   [SSISDB].[internal].folders AS f
                            ON p.folder_id = f.folder_id
                         WHERE op.project_id = @project_id
						   AND op.project_version_lsn = @project_version_lsn
                           AND f.folder_id = @folder_id
                           AND parameter_name = @parameter_name
                           AND referenced_variable_name = @variable_name
                           AND object_type = @object_type
                        )
            EXEC SSISDB.[catalog].set_object_parameter_value
                  @object_type = @object_type
                 ,@folder_name =  @folder_name
                 ,@project_name =  @project_name
                 ,@parameter_name = @parameter_name
                 ,@parameter_value =  @variable_name
                 ,@object_name = @package_name -- This is required when @object_type = 30 (Package), Ignored when @object_type = 20 (Project)
                 ,@value_type = 'R';

            --Select next item
            SELECT @current_row_id = @current_row_id + 1;
         END;
END TRY
BEGIN CATCH
    SELECT  @ErrSeverity = ERROR_SEVERITY(),
            @ErrState = ERROR_STATE(),
            @ErrMsg = @ErrMsg + '. ' + ERROR_MESSAGE() + '. Error in line ' + CAST(ERROR_LINE() AS varchar(1000)) + ' of procedure ' + ERROR_PROCEDURE();

    RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
END CATCH;