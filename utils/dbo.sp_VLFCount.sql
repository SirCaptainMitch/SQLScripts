USE [master]
GO 

SET NOCOUNT ON; 

IF OBJECT_ID('tempdb..#dbs') IS NOT NULL 
	DROP TABLE #dbs 

IF OBJECT_ID('tempdb..#Loginfo') IS NOT NULL 
	DROP TABLE #Loginfo

IF OBJECT_ID('tempdb..#DatabaseVLF') IS NOT NULL 
	DROP TABLE #DatabaseVLF

CREATE TABLE #dbs (id INT IDENTITY(1,1), Name VARCHAR(MAX) ) 

DECLARE @Sql NVARCHAR(MAX) = '', 
		@count INT = 0, 
		@Index INT = 1, 
		@VLFCount INT = 0

INSERT #dbs 
SELECT Name
FROM sys.Databases d 
WHERE State_Desc = 'ONLINE'
OPTION (RECOMPILE)

SELECT @count = ( SELECT COUNT(1) FROM #dbs )

CREATE TABLE #Loginfo
			( 
			  RecoveryUnitId INT 
			 ,FileID TINYINT 
			 ,FileSize BIGINT 
			 ,StartOffset BIGINT 
			 ,FSeqNo INT 
			 ,[Status] TINYINT
			 ,Pairty INT 
			 ,CreateLSN VARCHAR(MAX)  )

CREATE TABLE #DatabaseVLF 
			( DatabaseName VARCHAR(100)
			 ,VLFCount INT
			 ,FileId INT )

DECLARE @DBName VARCHAR(MAX) 

WHILE @index <= @Count 
	BEGIN 
		
		SELECT @DBName = d.name
		FROM #dbs d 
		WHERE d.id  = @index 
		

		SELECT @sql = 'USE '  + @DBName
					+ CHAR(10) 
					+ 'DBCC LOGINFO (' + QUOTENAME(@DBName,'''') + ')'   

		INSERT #Loginfo ( 
			 RecoveryUnitId
			,FileId
			,FileSize
			,StartOffset
			,FSeqNo
			,[Status]
			,Pairty
			,CreateLSN
		) 				
		EXEC sp_executesql @sql
		
		PRINT @sql		

		INSERT #DatabaseVLF
				( DatabaseName
				  ,VLFCount
				  ,FileId ) 
		SELECT @DBName
			   ,COUNT(1) AS VlfCount
			   ,vlf.FileId
		FROM #Loginfo vlf
		GROUP BY vlf.FileID

		TRUNCATE TABLE #Loginfo
		SELECT @Index = @Index + 1 

	END 

SELECT vlf.DatabaseName  
	  ,vlf.VLFCount 
	  ,CONVERT(MONEY, ROUND(((mf.size * 8) / 1024.0 ), 2 ) ) AS [SizeInMB]
	  ,mf.growth AS [GrowthSize]
	  ,mf.is_percent_growth AS [PercentGrowth]
	  ,mf.[name] AS LogName
	  ,mf.[file_id]
	  ,mf.physical_name
FROM #DatabaseVLF vlf
	 INNER JOIN sys.Master_Files mf ON DB_NAME(mf.Database_id) = vlf.DatabaseName 
											AND mf.[Type_desc] = 'LOG'
											AND mf.[file_id] = vlf.fileId
ORDER BY VLFCount DESC
OPTION (RECOMPILE) 
