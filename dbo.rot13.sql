-- =============================================
-- Author:      Mitchell Hamann 
-- Create date: 
-- Description: Direction: 
--						0 = Encrypt 
--						1 = decrypt
-- boilerplate from: https://spaghettidba.com/2011/07/08/my-stored-procedure-code-template/
-- =============================================
ALTER PROCEDURE dbo.rot13
				( @cipher VARCHAR(254) = 'Check out my string!'
				 ,@direction BIT = 0 ) 
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT,
        QUOTED_IDENTIFIER,
        ANSI_NULLS,
        ANSI_PADDING,
        ANSI_WARNINGS,
        ARITHABORT,
        CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
 
    DECLARE @localTran bit
    IF @@TRANCOUNT = 0
    BEGIN
        SET @localTran = 1
        BEGIN TRANSACTION LocalTran
    END
 
	BEGIN TRY
 
		DECLARE @index INT = 1
				,@count INT 
				,@holder VARCHAR(254) = ''

		SELECT @count = DATALENGTH(@cipher)
			   ,@cipher = ( SELECT UPPER(@cipher) )
			   

		IF @direction = 0
			BEGIN 						
				WHILE @index <= @count
					BEGIN 
						SELECT @holder = @holder + CASE WHEN ASCII(SUBSTRING(@cipher, @index, 1)) BETWEEN 65 AND 77 
															THEN CHAR(ASCII(SUBSTRING(@cipher, @index, 1)) + 13) 
														WHEN ASCII(SUBSTRING(@cipher, @index, 1)) BETWEEN 78 AND 90 
															THEN CHAR(ASCII(SUBSTRING(@cipher, @index, 1)) - 13) 
														ELSE SUBSTRING(@cipher, @index, 1)
													END 

						SELECT @index = @index + 1
							  
					END 		
			END
		ELSE 
			BEGIN 						
				WHILE @index <= @count
					BEGIN 
						SELECT @holder = @holder + CASE WHEN ASCII(SUBSTRING(@cipher, @index, 1)) BETWEEN 65 AND 77 
															THEN CHAR(ASCII(SUBSTRING(@cipher, @index, 1)) - 13) 
														WHEN ASCII(SUBSTRING(@cipher, @index, 1)) BETWEEN 78 AND 90 
															THEN CHAR(ASCII(SUBSTRING(@cipher, @index, 1)) + 13) 
														ELSE SUBSTRING(@cipher, @index, 1)
													END 

						SELECT @index = @index + 1
							  
					END 		
			END

		
		PRINT @holder
		
		SELECT @cipher AS Entered
			  ,@holder AS Result

 
		IF @localTran = 1 AND XACT_STATE() = 1
			COMMIT TRAN LocalTran
 
	END TRY
    BEGIN CATCH
 
        DECLARE @ErrorMessage NVARCHAR(4000)
        DECLARE @ErrorSeverity INT
        DECLARE @ErrorState INT
 
        SELECT  @ErrorMessage = ERROR_MESSAGE(),
                @ErrorSeverity = ERROR_SEVERITY(),
                @ErrorState = ERROR_STATE()
 
        IF @localTran = 1 AND XACT_STATE() <> 0
            ROLLBACK TRAN
 
        RAISERROR ( @ErrorMessage, @ErrorSeverity, @ErrorState)
 
    END CATCH
 
END