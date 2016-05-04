/****** Object:  StoredProcedure [dbo].[util_backupTable]    Script Date: 12/17/2015 8:37:00 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/********************************************************
PROC NAME: util_backuptable 
EXEC: EXEC dbo.util_backupTable 'liprod.glas'
********************************************************/
ALTER PROCEDURE [dbo].[util_backupTable] 
					( @tablename VARCHAR(MAX)) 
AS 
	BEGIN
	SET NOCOUNT ON;
	DECLARE @table  VARCHAR(MAX) = ''

	IF @tablename LIKE '%.%'
		BEGIN 
			SELECT @table = REVERSE(SUBSTRING(REVERSE(@tablename), 0, CHARINDEX('.',REVERSE(@tablename)))) 
			SELECT @tablename = REVERSE(SUBSTRING(REVERSE(@tablename), CHARINDEX('.',REVERSE(@tablename)), LEN(@tablename))) 
		END
	ELSE 
		BEGIN 
			SELECT @table = @tablename
			SELECT @tablename = ''
		END 


	IF EXISTS ( SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @table ) 
		BEGIN 
			DECLARE @output VARCHAR(MAX)
				   ,@create VARCHAR(MAX)
				   ,@insert VARCHAR(MAX)
				   ,@select VARCHAR(MAX)
				   ,@sql    VARCHAR(MAX)
				   ,@date   VARCHAR(MAX) = CONVERT(VARCHAR(10),GETDATE(), 112)
				   ,@index  INT = 0 
				   ,@count  INT = 1				  				

			DECLARE @newtablename VARCHAR(MAX) = 'zz' + @table + '_' + @date
			DECLARE @dupeCount INT = ( SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE @newtablename + '%') + 1 
			
			IF @dupeCount > 0 
				BEGIN 

					SELECT @newtablename = @newtablename + '_' + CONVERT(VARCHAR(100), @dupeCount)

				END 
			-- Make sure the schema is database is added. 
			SELECT @newtablename = @tablename + @newtablename

			SELECT @create = CONCAT('CREATE TABLE ',  @newtablename, '(' )   
				  ,@insert = CONCAT('INSERT INTO ',  @newtablename , '(' )
				  ,@select = 'SELECT ' 

			CREATE TABLE #Columns ( PK INT IDENTITY(1,1), Position INT, Name VARCHAR(MAX), DataType VARCHAR(MAX)) 

			-- Gather the column information 
			-- Needs to do PK's as well. Not sure how I want to handle that just yet. Since the constraint must be uniquely named. 
			-- Also, possibly need to handle the 
			INSERT INTO #Columns ( Position, Name, DataType) 
			SELECT c.ORDINAL_POSITION
					,c.COLUMN_NAME
					,CASE WHEN c.CHARACTER_MAXIMUM_LENGTH IS NOT NULL 
						THEN c.DATA_TYPE +'(' + CONVERT(VARCHAR(30),c.CHARACTER_MAXIMUM_LENGTH) + ')'
						WHEN c.NUMERIC_PRECISION IS NOT NULL AND c.NUMERIC_SCALE > 0
						THEN c.DATA_TYPE +'(' + CONVERT(VARCHAR(30),c.NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR(30),c.NUMERIC_SCALE) + ')'
						ELSE c.DATA_TYPE
						END
			FROM INFORMATION_SCHEMA.TABLES t
					INNER JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME					
			WHERE t.TABLE_NAME = @table
			
			SELECT @index = (SELECT COUNT(*) FROM #Columns) 

			WHILE @count <= @index 
				BEGIN 

					SELECT @create = @create + 
									c.Name + SPACE(1) + 
									CASE WHEN c.DataType = 'timestamp' THEN 'varbinary(8)'
										 ELSE c.DataType
									END + SPACE(1) + 									
									CASE WHEN @count < @index THEN ', '
										ELSE ')' 
									END
						  ,@insert = @insert + c.Name + 
									CASE WHEN @count < @index THEN ', '
										 ELSE ')' 
									END
						  ,@select = @select + c.Name + 
									CASE WHEN @count < @index THEN ', '
										 ELSE ' FROM '  +  @tablename + @table
									END
					FROM #Columns c 
					WHERE c.PK = @count

					SELECT @count = @count + 1 

				END 

				SELECT @SQL = @create + CHAR(10) + CHAR(13) + @insert + CHAR(10) + CHAR(13) +  @select
				EXEC (@sql) 

				--PRINT @sql 

				PRINT @newtablename 

		END
	ELSE 
		BEGIN 
			
			PRINT 'This is not a table.'

		END 
		
	END 

GO


