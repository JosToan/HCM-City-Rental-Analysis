USE master
GO

-- Tạo thủ tục để tạo login 
CREATE PROCEDURE sp_CreateNewLogin
    @LoginName varchar(50),
    @Password nvarchar(50),
    @CheckExpiration bit = 0,
    @CheckPolicy bit = 0
AS
BEGIN
    BEGIN TRY
        DECLARE @SQL nvarchar(max)
        SET @SQL = 'CREATE LOGIN ' + QUOTENAME(@LoginName) + 
                   ' WITH PASSWORD = ' + QUOTENAME(@Password, '''') + 
                   ', CHECK_EXPIRATION = ' + CASE WHEN @CheckExpiration = 1 THEN 'ON' ELSE 'OFF' END +
                   ', CHECK_POLICY = ' + CASE WHEN @CheckPolicy = 1 THEN 'ON' ELSE 'OFF' END
        EXEC sp_executesql @SQL
        PRINT 'Login ' + @LoginName + N' đã được tạo thành công'
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi: Không thể tạo login ' + @LoginName
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

USE PhongTro
GO


-- Thủ tục tạo user cho một login
CREATE PROCEDURE sp_CreateNewUser
    @UserName varchar(50),
    @LoginName varchar(50)
AS
BEGIN
    BEGIN TRY
        DECLARE @SQL nvarchar(max)
        SET @SQL = 'CREATE USER ' + QUOTENAME(@UserName) + 
                   ' FOR LOGIN ' + QUOTENAME(@LoginName)
        EXEC sp_executesql @SQL
        PRINT 'User ' + @UserName + N' đã được tạo thành công'
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi: Không thể tạo user ' + @UserName
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- Thủ tục tổng hợp để tạo login và user
CREATE PROCEDURE sp_CreateLoginAndUser
    @Name varchar(50),
    @Password nvarchar(50)
AS
BEGIN
    BEGIN TRY
        -- Tạo login
        EXEC master.dbo.sp_CreateNewLogin 
            @LoginName = @Name,
            @Password = @Password

        -- Tạo user
        EXEC sp_CreateNewUser
            @UserName = @Name,
            @LoginName = @Name

        PRINT N'Tạo login và user ' + @Name + N' thành công'
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi trong quá trình tạo login và user'
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- Sử dụng thủ tục để tạo 3 người dùng
EXEC sp_CreateLoginAndUser 'Admin', 'admin123'
GO
EXEC sp_CreateLoginAndUser 'DE', 'de123'
GO
EXEC sp_CreateLoginAndUser 'DA', 'da123'
GO

-- Tạo thủ tục phân quyền assignpermission
USE PhongTro
GO

-- Tạo các roles
CREATE ROLE Admin_Role
GO
CREATE ROLE DE_Role
GO
CREATE ROLE DA_Role
GO

-- Thủ tục phân quyền cho Admin
CREATE PROCEDURE sp_AssignAdminPermissions
    @UserName NVARCHAR(50)
AS
BEGIN
    BEGIN TRY
        -- Thêm user vào role Admin
        EXEC sp_addrolemember 'Admin_Role', @UserName

        -- Cấp full quyền trên database
        DECLARE @SQL NVARCHAR(MAX)
        SET @SQL = 'GRANT CONTROL TO ' + QUOTENAME(@UserName)
        EXEC sp_executesql @SQL

        PRINT N'Đã cấp quyền Admin cho user ' + @UserName
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi khi cấp quyền Admin cho user ' + @UserName
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- Thủ tục phân quyền cho Data Engineer (DE)
CREATE PROCEDURE sp_AssignDEPermissions
    @UserName NVARCHAR(50)
AS
BEGIN
    BEGIN TRY
        -- Thêm user vào role DE
        EXEC sp_addrolemember 'DE_Role', @UserName

        -- Cấp quyền cho DE
        DECLARE @SQL NVARCHAR(MAX)

        -- Quyền trên tất cả các bảng
        SET @SQL = 'GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ' + QUOTENAME(@UserName)
        EXEC sp_executesql @SQL

        -- Quyền tạo, sửa, xóa procedure và function
        SET @SQL = 'GRANT CREATE PROCEDURE, ALTER, DELETE TO ' + QUOTENAME(@UserName)
        EXEC sp_executesql @SQL
        SET @SQL = 'GRANT CREATE FUNCTION TO ' + QUOTENAME(@UserName)
        EXEC sp_executesql @SQL

        PRINT N'Đã cấp quyền Data Engineer cho user ' + @UserName
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi khi cấp quyền Data Engineer cho user ' + @UserName
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- Thủ tục phân quyền cho Data Analyst (DA)
CREATE PROCEDURE sp_AssignDAPermissions
    @UserName NVARCHAR(50)
AS
BEGIN
    BEGIN TRY
        -- Thêm user vào role DA
        EXEC sp_addrolemember 'DA_Role', @UserName

        -- Cấp quyền SELECT trên tất cả các bảng
        DECLARE @SQL NVARCHAR(MAX)
        SET @SQL = 'GRANT SELECT ON SCHEMA::dbo TO ' + QUOTENAME(@UserName)
        EXEC sp_executesql @SQL

        PRINT N'Đã cấp quyền Data Analyst cho user ' + @UserName
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi khi cấp quyền Data Analyst cho user ' + @UserName
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- Áp dụng phân quyền cho các users
-- Admin
EXEC sp_AssignAdminPermissions 'Admin'
GO

-- User2 - Data Engineer
EXEC sp_AssignDEPermissions 'DE'
GO

-- User3 - Data Analyst
EXEC sp_AssignDAPermissions 'DA'
GO



--KIỂM TRA QUYỀN CỦA NGƯỜI DÙNG 
CREATE PROCEDURE GeneratePermissionsSummary
AS
BEGIN
    -- 1. Tạo bảng tổng hợp quyền (bảng tạm thời)
    CREATE TABLE #PermissionsSummary (
        PermissionName NVARCHAR(100),
        Level NVARCHAR(20),
        Admin NVARCHAR(10),
        DE NVARCHAR(10),
        DA NVARCHAR(10)
    );

    -- 2. Khai báo bảng tạm và danh sách người dùng
    DECLARE @TempPermissions TABLE (
        PermissionName NVARCHAR(100), 
        UserName NVARCHAR(50),
        Level NVARCHAR(20)
    );
    DECLARE @Users TABLE (UserName NVARCHAR(50));
    INSERT INTO @Users (UserName) VALUES ('Admin'), ('DE'), ('DA');

    -- 3. Lấy tất cả quyền có sẵn
    DECLARE @AllPermissions TABLE (
        PermissionName NVARCHAR(100),
        Level NVARCHAR(20)
    );
    INSERT INTO @AllPermissions (PermissionName, Level)
    SELECT DISTINCT permission_name, 'SERVER' AS Level FROM sys.fn_builtin_permissions('SERVER')
    UNION ALL
    SELECT DISTINCT permission_name, 'DATABASE' AS Level FROM sys.fn_builtin_permissions('DATABASE')
    UNION ALL
    SELECT DISTINCT permission_name, 'OBJECT' AS Level FROM sys.fn_builtin_permissions('OBJECT');

    -- 4. Kiểm tra quyền của từng người dùng
    DECLARE @User NVARCHAR(50);
    DECLARE UserCursor CURSOR FOR SELECT UserName FROM @Users;
    OPEN UserCursor;
    FETCH NEXT FROM UserCursor INTO @User;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Chuyển ngữ cảnh sang user
        EXECUTE AS USER = @User;

        -- Lấy quyền của user
        INSERT INTO @TempPermissions (PermissionName, UserName, Level)
        SELECT DISTINCT 
            p.permission_name, 
            @User,
            'OBJECT' AS Level
        FROM sys.objects o
        CROSS APPLY fn_my_permissions(QUOTENAME(o.name), 'OBJECT') p
        WHERE schema_name(o.schema_id) = 'dbo'

        UNION ALL

        SELECT DISTINCT 
            p.permission_name, 
            @User,
            'DATABASE' AS Level
        FROM sys.fn_my_permissions(NULL, 'DATABASE') p

        UNION ALL

        SELECT DISTINCT 
            p.permission_name, 
            @User,
            'SERVER' AS Level
        FROM sys.fn_my_permissions(NULL, 'SERVER') p;

        -- Trở lại ngữ cảnh cũ
        REVERT;

        FETCH NEXT FROM UserCursor INTO @User;
    END;

    CLOSE UserCursor;
    DEALLOCATE UserCursor;

    -- 5. Tổng hợp kết quả vào bảng #PermissionsSummary
    INSERT INTO #PermissionsSummary (PermissionName, Level, Admin, DE, DA)
    SELECT 
        p.PermissionName,
        p.Level,
        CASE WHEN EXISTS (SELECT 1 FROM @TempPermissions WHERE UserName = 'Admin' AND PermissionName = p.PermissionName AND Level = p.Level) THEN 'x' ELSE '' END AS Admin,
        CASE WHEN EXISTS (SELECT 1 FROM @TempPermissions WHERE UserName = 'DE' AND PermissionName = p.PermissionName AND Level = p.Level) THEN 'x' ELSE '' END AS DE,
        CASE WHEN EXISTS (SELECT 1 FROM @TempPermissions WHERE UserName = 'DA' AND PermissionName = p.PermissionName AND Level = p.Level) THEN 'x' ELSE '' END AS DA
    FROM @AllPermissions p
    WHERE EXISTS (
        SELECT 1 
        FROM @TempPermissions 
        WHERE PermissionName = p.PermissionName
        AND Level = p.Level
    )
    GROUP BY p.PermissionName, p.Level;

    -- 6. Hiển thị kết quả
    SELECT * FROM #PermissionsSummary;
END;


EXEC GeneratePermissionsSummary;


-- Thủ tục thu hồi quyền cụ thể 
CREATE PROCEDURE sp_RevokeSpecificPermission
    @UserName NVARCHAR(50),      
    @Permission NVARCHAR(50),     
    @ObjectName NVARCHAR(255)     
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    BEGIN TRY
        -- Kiểm tra các tham số đầu vào
        IF @Permission IS NULL OR @ObjectName IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp cả quyền và đối tượng áp dụng.';
            RETURN;
        END

        -- Tạo câu lệnh REVOKE
        SET @SQL = 'REVOKE ' + @Permission + ' ON ' + @ObjectName + ' FROM ' + QUOTENAME(@UserName);

        -- Thực thi câu lệnh
        EXEC sp_executesql @SQL;

        -- Thông báo thành công
        PRINT N'Đã thu hồi quyền ' + @Permission + N' trên ' + @ObjectName + N' từ người dùng ' + @UserName;
    END TRY
    BEGIN CATCH
        -- Xử lý lỗi
        PRINT N'Lỗi khi thu hồi quyền từ người dùng ' + @UserName;
        PRINT N'Thông tin lỗi:';
        PRINT ERROR_MESSAGE();
        PRINT 'Dòng lỗi: ' + CAST(ERROR_LINE() AS NVARCHAR);
        PRINT 'Thủ tục lỗi: ' + ISNULL(ERROR_PROCEDURE(), N'Không xác định');
    END CATCH
END;
GO


EXEC sp_RevokeSpecificPermission 
    @UserName = 'DA', 
    @Permission = 'SELECT', 
    @ObjectName = 'DATABASE::PhongTro';

-- Thu hồi toàn bộ quyền 
CREATE PROCEDURE sp_RevokeAllPermissions
    @UserName NVARCHAR(50)       
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Permission NVARCHAR(50);
    DECLARE @ObjectName NVARCHAR(255);

    -- Bảng tạm lưu thông tin các quyền cần thu hồi
    CREATE TABLE #UserPermissions (
        Permission NVARCHAR(50),
        ObjectName NVARCHAR(255)
    );

    BEGIN TRY
        -- Lấy danh sách toàn bộ quyền của người dùng
        INSERT INTO #UserPermissions (Permission, ObjectName)
        SELECT 
            permission_name AS Permission,
            class_desc + '::' + OBJECT_NAME(major_id) AS ObjectName
        FROM sys.database_permissions dp
        JOIN sys.database_principals dpn
            ON dp.grantee_principal_id = dpn.principal_id
        WHERE dpn.name = @UserName;

        -- Lặp qua danh sách quyền và thu hồi từng quyền
        DECLARE cur CURSOR FOR 
        SELECT Permission, ObjectName 
        FROM #UserPermissions;

        OPEN cur;
        FETCH NEXT FROM cur INTO @Permission, @ObjectName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Xây dựng và thực thi lệnh REVOKE
            SET @SQL = 'REVOKE ' + @Permission + ' ON ' + @ObjectName + ' FROM ' + QUOTENAME(@UserName);
            EXEC sp_executesql @SQL;

            PRINT N'Đã thu hồi quyền ' + @Permission + N' trên ' + @ObjectName + N' từ người dùng ' + @UserName;

            FETCH NEXT FROM cur INTO @Permission, @ObjectName;
        END;

        CLOSE cur;
        DEALLOCATE cur;

        -- Thông báo thành công
        PRINT N'Tất cả các quyền của người dùng ' + @UserName + N' đã được thu hồi.';
    END TRY
    BEGIN CATCH
        -- Xử lý lỗi
        PRINT N'Lỗi khi thu hồi quyền từ người dùng ' + @UserName;
        PRINT ERROR_MESSAGE();
    END CATCH

    -- Dọn dẹp bảng tạm
    DROP TABLE #UserPermissions;
END;
GO


EXEC sp_RevokeAllPermissions @UserName = 'DA';
