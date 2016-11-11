# SSIS_Deployment
Scripts for deploying SSIS Projects (SQL Server 2012 and higher versions)

Three TSQL files:

SSIS_1_Project.sql	Deploy the .ispac file into SSISDB catalog.
 
SSIS_2_Environment.sql	Create Environment, Environment variables, and variable references for project and package parameters.
 
SSIS_3_Job.sql Create a job that references an Environment at execution time.
