-- TẠO BẢNG BACKUP CHO ORIGINAL_DATA
    SELECT * INTO clean_data
    FROM ORIGINAL_DATA

--1. Loại bỏ đơn vị ở cột price và chuyển sang kiểu số 
CREATE PROC Price 
AS 
BEGIN 
    -- Xử lý 'đồng/tháng'
    UPDATE clean_data
    SET price = CAST(REPLACE(price, N'đồng/tháng','') AS FLOAT)/1000
    WHERE price LIKE N'%đồng/tháng%';

    -- Xử lý 'triệu/tháng'
    UPDATE clean_data
    SET price = CAST(REPLACE(price, N'triệu/tháng','') AS FLOAT)
    WHERE price LIKE N'%triệu/tháng%';

    -- Xử lý giá trị ngoại lệ 
    DELETE FROM clean_data  
    WHERE TRY_CAST(price AS FLOAT) IS NULL;
END;
-- Thực thi hàm
EXEC Price;

--2. Chỉ lấy ngày trong 2 cột published_date và expiration_date
	CREATE FUNCTION ExtractDate(@DateString NVARCHAR(50))
	RETURNS DATE
	AS
	BEGIN
		DECLARE @datePart NVARCHAR(10);
		DECLARE @convertedDate DATE;

		-- Lấy 10 ký tự cuối cùng chứa phần ngày
		SET @datePart = RIGHT(@DateString, 10);

		-- Chuyển đổi chuỗi dd/MM/yyyy sang DATE
		SET @convertedDate = TRY_CONVERT(DATE, @datePart, 103); -- 103 là định dạng dd/MM/yyyy

		RETURN @convertedDate;
	END;

	--Cập nhật cho 2 cột published_time và expiration_date
	UPDATE clean_data  
	SET published_date = dbo.ExtractDate(published_date),
		expiration_date = dbo.ExtractDate(expiration_date);
 

--3. Xóa đơn vị trong cột area 
	CREATE PROC Area  
	AS 
	BEGIN 
		UPDATE clean_data
		SET area= CAST(REPLACE(area, 'm2', '') AS Float)
	END; 
	 
	EXEC Area; 

--4.Tạo cột district và lấy Quận,Huyện từ cột address 
	CREATE FUNCTION onlyDistrict(@address NVARCHAR(255))
	RETURNS NVARCHAR(255)
	AS
	BEGIN
		DECLARE @district NVARCHAR(255);
	
		-- Xóa TP HCM  
		SET @address = CASE
			WHEN @address like N'%, Hồ Chí Minh%'  THEN REPLACE(@address,  N', Hồ Chí Minh', '') 
			WHEN @address like N'%, TP.HCM%'	   THEN REPLACE(@address,  N', TP.HCM', '') 
			WHEN @address like N'%, TPHCM%'		   THEN REPLACE(@address,  N', TPHCM', '')
			ELSE @address
		END;

		-- Lấy QUẬN, HUYỆN từ phải qua cho tới dấu , đầu tiên
		SET @district = RIGHT(@address, CHARINDEX(',', REVERSE(@address) + ',') - 1);

		-- Xóa từ khóa "Quận", "Huyện", "Thành phố", "TP" trong cột 'district'
		SET @district = CASE
			WHEN @district LIKE N'%Quận%'      THEN TRIM(REPLACE(@district, N'Quận', ''))
			WHEN @district LIKE N'%Huyện%'     THEN TRIM(REPLACE(@district, N'Huyện', ''))
			WHEN @district LIKE N'%Thành phố%' THEN TRIM(REPLACE(@district, N'Thành phố', ''))
			WHEN @district LIKE N'%Q.%'        THEN TRIM(REPLACE(@district, N'Q.', ''))
			ELSE TRIM(@district)
		END;

		-- Trả về kết quả
		RETURN @district;
	END;

	--Tạo cột districst 
	ALTER TABLE clean_data
	ADD district NVARCHAR(255)

	-- Cập nhật cột district 
	UPDATE clean_data
	SET district = dbo.onlyDistrict(address); 

-- Kiểm tra các cột district lỗi
	SELECT DISTINCT district 
	FROM clean_data 
	WHERE LEN(district) > 20 

	GO
-- Cập nhật thủ công những cột district lỗi
	UPDATE clean_data 
	SET district = CASE		
					WHEN district like N'%Khu Him Lam Trung Sơn - (gần LOTTE Q7 và gần cầu Nguyễn Văn Cừ )' THEN '7'
					WHEN district like N'%(sát gần AEON Mall TÂN PHÚ)%' THEN 'Tân Phú'
					WHEN district like N'%gần AEON MALL Tân Phú)%' THEN 'Tân Phú'
					ELSE district 
				END 

--5. Xử lý các dữ liệu 'không có thông tin'
	CREATE FUNCTION Info(@input NVARCHAR(MAX))
	RETURNS NVARCHAR(MAX)
	AS
	BEGIN
		RETURN CASE 
			WHEN @input = N'không có thông tin' THEN N'không có'
			ELSE @input
		END 
	END;

--Cập nhật cho 3 cột basic_amenities, security, public_amenities
	UPDATE clean_data
	SET basic_amenities  = dbo.Info(basic_amenities),
		security         = dbo.Info(security),
		public_amenities = dbo.Info(public_amenities);
	GO
-- Thêm INTERNET vào public_amentities
	UPDATE clean_data
	SET public_amenities = CASE 
								WHEN public_amenities = N'không có'  THEN iif(has_internet = 'có', 'internet', public_amenities)
								ELSE concat(public_amenities, iif(has_internet = 'có', ', internet', ''))						
							END

--6. Đổi giá trị trong cột convenient_location
	UPDATE clean_data 
	SET convenient_location = iif(convenient_location = N'có', N'gần đại học', N'không có') 

--7. XÓA NHỮNG CỘT KHÔNG CẦN THIẾT
CREATE PROCEDURE RemoveUnnecessaryColumns
    @table_name NVARCHAR(128),
    @columns_to_remove NVARCHAR(MAX)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);

    -- Kiểm tra nếu bảng tồn tại
    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME = @table_name
    )
    BEGIN
        PRINT 'Bảng không tồn tại';
        RETURN;
    END

    -- Tạo câu lệnh SQL để xóa các cột
    SET @sql = 'ALTER TABLE ' + QUOTENAME(@table_name) + ' DROP COLUMN ' + @columns_to_remove + ';';

    -- Thực thi câu lệnh SQL
    EXEC sp_executesql @sql;
END;

GO	
EXEC RemoveUnnecessaryColumns 
    @table_name = 'clean_data', 
    @columns_to_remove = 'title, listing_type, tenant_type, has_internet, address';



-- Tạo mô hình CSDL mới 
	CREATE TABLE Room (
		room_id VARCHAR(6) PRIMARY KEY,
		district NVARCHAR(50),
		area FLOAT,
		price FLOAT,
		published_date DATE,
		expiration_date DATE)
    GO
	CREATE TABLE Amenities (
		amenities_id INT PRIMARY KEY,
		amenity_name NVARCHAR(20),
		amenity_type NVARCHAR(20))
	
    GO
	CREATE TABLE Room_Amenities (
		room_id VARCHAR(6),
		amenities_id INT,
		PRIMARY KEY (room_id, amenities_id),
		FOREIGN KEY (room_id) REFERENCES Room(room_id),
		FOREIGN KEY (amenities_id) REFERENCES Amenities(amenities_id))
    
    GO
-- Tạo một bảng tạm mới 
	CREATE TABLE temp_amenities ( 
		room_id INT,
		amenity_type NVARCHAR(20),
		amenity_name NVARCHAR(20))

	GO
-- Xử lý basic_amenities
	INSERT INTO temp_amenities (room_id, amenity_type, amenity_name)
	SELECT room_id,
		   'basic_amenities' AS amenity_type, 
		   TRIM(
				CASE 
					WHEN TRIM(value) IN (N'nệm') THEN N'giường'
					WHEN TRIM(value) IN (N'nấu ăn') THEN N'bếp'
					ELSE TRIM(value) 
				END
				)		AS amenity_name
	FROM		
		   clean_data
	CROSS APPLY 
			STRING_SPLIT(basic_amenities, ',') AS s
	WHERE 
			TRIM(value) IN (N'bếp', N'tủ lạnh', N'máy lạnh', N'máy giặt', N'giường', N'tủ')
		
	GO
-- Xử lý security 
	INSERT INTO temp_amenities (room_id, amenity_type, amenity_name)
	SELECT 
		room_id, 
		'security' AS amenity_type,
		TRIM(
			  CASE 
				 WHEN TRIM (value) IN (N'khóa điện tử') THEN N'khóa thông minh'
				 WHEN TRIM (value) IN (N'khóa')		    THEN N'khóa thông minh'
				 WHEN TRIM (value) IN (N'vân')		    THEN N'khóa thông minh'
				 WHEN TRIM (value) IN (N'an ninh')	    THEN N'bảo vệ'
				 ELSE TRIM(value)
			  END
			)    AS amenity_name
	FROM 
			clean_data 
	CROSS APPLY 
			STRING_SPLIT(security, ',')
	WHERE 
			TRIM(value) != '';
	GO
-- Xử lý PUBLIC
	INSERT INTO temp_amenities (room_id, amenity_type, amenity_name)
	SELECT 
			room_id, 
			'public' AS amenity_type,
			TRIM(VALUE) AS amenity_name			
	FROM 
			clean_data 
	CROSS APPLY 
			STRING_SPLIT(public_amenities, ',')
	WHERE 
			TRIM(value) != '';

-- Xử lý CONVENIENT_LOCATION 
    
    INSERT INTO temp_amenities (room_id, amenity_type, amenity_name)
    SELECT 
        room_id, 
        'convenient_location' AS amenity_type,
        CASE 
            WHEN TRIM(convenient_location) LIKE N'%gần đại học%' THEN N'gần đại học'
            WHEN TRIM(convenient_location) LIKE N'%không có%' THEN N'không có'
        END AS amenity_name
    FROM 
        clean_data
    WHERE 
        TRIM(convenient_location) LIKE N'%gần đại học%' 
        OR TRIM(convenient_location) LIKE N'%không có%';


-- INSERT DỮ LIỆU VÀO BẢNG ROOM 
	INSERT INTO Room(room_id, district, area, published_date, expiration_date, price) 
	SELECT room_id, district, area, published_date, expiration_date, price
	FROM clean_data 

-- INSERT DỮ LIỆU VÀO AMENTITIES
	WITH UniqueAmenities AS (SELECT DISTINCT 
							 	            amenity_type,
								            amenity_name
							 FROM 
								            temp_amenities),
		AmenityID		 AS (SELECT 
                                    amenity_type,
                                    amenity_name,
                                    RIGHT('0' + CAST(DENSE_RANK() OVER (ORDER BY amenity_type, amenity_name) AS VARCHAR), 2) AS amenities_id
							FROM 
								    UniqueAmenities)

	INSERT INTO Amenities (amenities_id, amenity_name, amenity_type)
	SELECT 
            amenities_id,
            amenity_name,
            amenity_type
	FROM 
		    AmenityID;

--INSERT VÀO ROOM_AMENITIES
	INSERT INTO Room_Amenities (room_id, amenities_id)
	SELECT DISTINCT 
					t.room_id,
					a.amenities_id
	FROM 
	    	temp_amenities AS t
	JOIN 
		    Amenities AS a 
	ON 
		    t.amenity_name = a.amenity_name	AND t.amenity_type = a.amenity_type;


select amenity_name, amenity_type from Amenities
join Room_Amenities RA on RA.amenities_id=Amenities.amenities_id
where  room_id = 301478


select * from [dbo].[clean_data]
where  room_id = 301478




