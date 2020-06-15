CREATE PROCEDURE [dbo].[MLM_UpdateFieldValue] (@ColumnID INT, @PK INT, @NewValue NVARCHAR(max), @LoginID NVARCHAR(32))
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @ColumnName NVARCHAR(255), @SearchTerm INT, @AuditTrail INT, @TableID INT, @TableName NVARCHAR(255), @PKColumnName NVARCHAR(255), @ModuleID INT, @AuthorityTableID INT, @Boolean BIT, @Length INT;
    DECLARE @NewID INT, @ExistingID INT, @ATColumnName NVARCHAR(255);
    DECLARE @OldValue NVARCHAR(max), @SQL NVARCHAR(max), @Parameter NVARCHAR(500);

    SELECT @ColumnName = C.ColumnName, @SearchTerm = C.SearchTerm, @AuditTrail = C.AuditTrail, @TableName = T.TableName, @TableID = T.TableID, @PKColumnName = T.PKColumnName, @ModuleID = T.ModuleType, @AuthorityTableID = ISNULL(C.AuthorityTableID,0), @Boolean = C.YesNo, @Length = CASE WHEN C.[Type] IN ('nchar','nvarchar','char','varchar') THEN C.[Length] END
    FROM dbo.DDColumns C
    LEFT JOIN dbo.DDTables T ON C.PhysTableID = T.TableID
    WHERE C.ColumnID = @ColumnID;

    IF @Length IS NOT NULL AND LEN(@NewValue) > @Length
    BEGIN
	   SELECT @NewValue = LEFT(@NewValue,@Length-1) + CHAR(133)
    END

    IF @AuthorityTableID = 0
    BEGIN
	   SELECT @ATColumnName = @ColumnName, @SQL = CONCAT('SELECT @Existing = CONVERT(NVARCHAR(max),ISNULL(',@ColumnName,','''')) FROM dbo.',@TableName,' WHERE ',@PKColumnName,' = @PK');
	   SET @Parameter = N'@PK INT, @Existing NVARCHAR(max) OUTPUT';
	   EXECUTE sp_executesql @SQL, @Parameter, @PK=@PK, @Existing=@OldValue OUTPUT;
    END
    ELSE
    BEGIN
	   SELECT @SQL = CONCAT('SELECT @ExistingID = ISNULL(',@ColumnName,',0) FROM dbo.',@TableName,' WHERE ',@PKColumnName,' = @PK');
	   SET @Parameter = N'@PK INT, @ExistingID INT OUTPUT';
	   EXECUTE sp_executesql @SQL, @Parameter, @PK=@PK, @ExistingID=@ExistingID OUTPUT;

	   SELECT @SQL = CONCAT('SELECT @Existing = CONVERT(NVARCHAR(max),ISNULL(',MainDataColName,','''')), @Col = ''',MainDataColName,''' FROM dbo.',TableName,' WHERE ',PKColumnName,' = @EID') FROM DDTables WHERE TableID = @AuthorityTableID;
	   SET @Parameter = N'@EID INT, @Existing NVARCHAR(max) OUTPUT, @Col NVARCHAR(255) OUTPUT';
	   EXECUTE sp_executesql @SQL, @Parameter, @EID=@ExistingID, @Existing=@OldValue OUTPUT, @Col=@ATColumnName OUTPUT;

	   SELECT @SQL = CONCAT('SELECT @NewID = ISNULL(',PKColumnName,',0) FROM dbo.',TableName,' WHERE ',MainDataColName,' = @NewValue') FROM DDTables WHERE TableID = @AuthorityTableID;
	   SET @Parameter = N'@NewValue NVARCHAR(max), @NewID INT OUTPUT';
	   EXECUTE sp_executesql @SQL, @Parameter, @NewValue=@NewValue, @NewID=@NewID OUTPUT;
    END

    IF ISNULL(@NewValue,'') COLLATE Latin1_General_CS_AS = ISNULL(@OldValue,'')
    BEGIN
		PRINT 'Update did not complete; requested value is the current value.';
		RETURN;
    END
    ELSE
    BEGIN
	   IF @AuditTrail = 1 AND @Boolean = 1
	   BEGIN
		  INSERT INTO dbo.AuditTrail (ObjectID, LoginID, ColumnName, NewValue, OldValue, TableName, ModuleID) (SELECT @PK, @LoginID, @ATColumnName, CASE WHEN @NewValue = '1' THEN 'True' ELSE 'False' END, CASE WHEN @OldValue = '1' THEN 'True' ELSE 'False' END, @TableName, @ModuleID);
	   END
	   ELSE IF @AuditTrail = 1
	   BEGIN
		  INSERT INTO dbo.AuditTrail (ObjectID, LoginID, ColumnName, NewValue, OldValue, TableName, ModuleID) (SELECT @PK, @LoginID, @ATColumnName, @NewValue, @OldValue, @TableName, @ModuleID);
	   END

	   IF @AuthorityTableID = 0
	   BEGIN
		  SELECT @SQL = CONCAT('UPDATE dbo.',@TableName,' SET ',@ColumnName,' = @NewValue WHERE ',@PKColumnName,' = @PK');
		  SET @Parameter = N'@NewValue NVARCHAR(max), @PK INT';
		  EXECUTE sp_executesql @SQL, @Parameter, @NewValue=@NewValue, @PK=@PK;
	   END
	   ELSE
	   BEGIN
		  SELECT @SQL = CONCAT('UPDATE dbo.',@TableName,' SET ',@ColumnName,' = @NewID WHERE ',@PKColumnName,' = @PK');
		  SET @Parameter = N'@NewID INT, @PK INT';
		  EXECUTE sp_executesql @SQL, @Parameter, @NewID=@NewID, @PK=@PK;
	   END

		IF @SearchTerm = 1
		BEGIN
			PRINT CONCAT('Run Maintain Search Terms on [',@TableName,'].[',@ColumnName,']');
	   END

	   PRINT 'Update completed';

    END

END

GO
