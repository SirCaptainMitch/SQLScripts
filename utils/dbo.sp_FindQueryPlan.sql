USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.sp_FindQueryPlan') IS  NULL
    EXEC ('CREATE PROCEDURE dbo.sp_FindQueryPlan AS RETURN 0');
GO

ALTER PROCEDURE [dbo].[sp_FindQueryPlan]
    @DatabaseName NVARCHAR(128), 
    @ObjectName NVARCHAR(128) = NULL  
WITH RECOMPILE
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;    

DECLARE @Sql NVARCHAR(MAX)	   

IF OBJECT_ID('tempdb..#ProcCache') IS NOT NULL 
	DROP TABLE #ProcCache 

CREATE TABLE #ProcCache
			( id INT IDENTITY(1,1) 
			 ,ObjectId INT
			 ,ObjectName VARCHAR(255)
			 ,PlanHandle VARBINARY(64)
			 ,QueryPlan XML 
			 ,CachedTime DATETIME
			 ,ExecCount INT 			 
			 ,[LastElapsedTime(S)] NUMERIC(12,4)
			 ,SetOptions VARCHAR(1000) 
			) 

SELECT @Sql =  
N'USE ' + @DatabaseName + ' 

DECLARE @ObjectId INT = OBJECT_ID(@ObjectName)

SELECT o.object_id
	 , OBJECT_NAME(o.object_id) 
	 , s.plan_handle
	 , h.query_plan
	 , s.cached_time
	 , S.execution_count
	 , CONVERT(NUMERIC(12,4),( CONVERT(NUMERIC,s.last_elapsed_time) / CONVERT(NUMERIC,1000000) )) 
FROM sys.objects o 
	 INNER JOIN sys.dm_exec_procedure_stats s on o.object_id = s.object_id
	 CROSS APPLY sys.dm_exec_query_plan(s.plan_handle) h	 
WHERE o.object_id = ISNULL(@ObjectId, o.object_id)'

INSERT #ProcCache 
	  (  ObjectId
	   , ObjectName
	   , PlanHandle
	   , QueryPlan
	   , CachedTime
	   , ExecCount
	   , [LastElapsedTime(S)]) 
EXEC sp_executesql @sql, N'@ObjectName VARCHAR(255)', @ObjectName

-- This part taken from SQL First Responder Kit 
-- https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/blob/dev/sp_BlitzCache.sql#L2866
UPDATE p 
SET SetOptions = SUBSTRING(
                    CASE WHEN (CAST(pa.value AS INT) & 1 = 1) THEN ', ANSI_PADDING' ELSE '' END +
                    CASE WHEN (CAST(pa.value AS INT) & 8 = 8) THEN ', CONCAT_NULL_YIELDS_NULL' ELSE '' END +
                    CASE WHEN (CAST(pa.value AS INT) & 16 = 16) THEN ', ANSI_WARNINGS' ELSE '' END +
                    CASE WHEN (CAST(pa.value AS INT) & 32 = 32) THEN ', ANSI_NULLS' ELSE '' END +
                    CASE WHEN (CAST(pa.value AS INT) & 64 = 64) THEN ', QUOTED_IDENTIFIER' ELSE '' END +
                    CASE WHEN (CAST(pa.value AS INT) & 4096 = 4096) THEN ', ARITH_ABORT' ELSE '' END +
                    CASE WHEN (CAST(pa.value AS INT) & 8192 = 8191) THEN ', NUMERIC_ROUNDABORT' ELSE '' END 
                    , 2, 200000) 
FROM #ProcCache p 
	 CROSS APPLY sys.dm_exec_plan_attributes (p.PlanHandle) pa 
WHERE  pa.attribute = 'set_options' 

SELECT ObjectId
	   ,ObjectName 
	   ,QueryPlan	   
	   ,CachedTime
	   ,ExecCount
	   ,[LastElapsedTime(S)]
	   ,[LastElapsedTime(S)] * CONVERT(NUMERIC(12,4), ExecCount) AS TotalExecTime
	   ,SetOptions 
FROM #ProcCache
ORDER BY [LastElapsedTime(S)] * CONVERT(NUMERIC(12,4), ExecCount) DESC, [LastElapsedTime(S)] DESC 

GO