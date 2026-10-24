-- STEP STORE / ASP.NET MVC 5 + Entity Framework 6 / SQL Server
-- Connect in SSMS to WINDOWS-PC\SQLEXPRESS, open this file, press F5.
-- Safe to rerun: no DROP, no DELETE, no overwriting existing products or stock.
-- Requires CREATE DATABASE privilege on first run.
USE [master];
GO
IF DB_ID(N'ShopGiay') IS NULL
BEGIN
    CREATE DATABASE [ShopGiay];
END;
GO
USE [ShopGiay];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.AdminUsers', N'U') IS NULL
BEGIN
create table [dbo].[AdminUsers] (
    [Id] [int] not null identity,
    [Email] [nvarchar](180) null,
    [PasswordHash] [nvarchar](max) null,
    [SecurityStamp] [nvarchar](32) null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Banners', N'U') IS NULL
BEGIN
create table [dbo].[Banners] (
    [Id] [int] not null identity,
    [Title] [nvarchar](160) not null,
    [Subtitle] [nvarchar](500) null,
    [ButtonText] [nvarchar](50) null,
    [LinkUrl] [nvarchar](500) null,
    [ImageUrl] [nvarchar](500) null,
    [SortOrder] [int] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Brands', N'U') IS NULL
BEGIN
create table [dbo].[Brands] (
    [Id] [int] not null identity,
    [Name] [nvarchar](50) not null,
    [SortOrder] [int] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Categories', N'U') IS NULL
BEGIN
create table [dbo].[Categories] (
    [Id] [int] not null identity,
    [Name] [nvarchar](180) not null,
    [SortOrder] [int] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL
BEGIN
create table [dbo].[Customers] (
    [Id] [int] not null identity,
    [Name] [nvarchar](100) not null,
    [Email] [nvarchar](180) not null,
    [PasswordHash] [nvarchar](max) not null,
    [Phone] [nvarchar](20) null,
    [Address] [nvarchar](500) null,
    [IsActive] [bit] not null,
    [ReceiveVoucherEmails] [bit] not null,
    [CreatedAt] [datetime] not null,
    [SecurityStamp] [nvarchar](32) not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
create table [dbo].[Orders] (
    [Id] [int] not null identity,
    [CustomerId] [int] null,
    [VoucherCode] [nvarchar](30) null,
    [Discount] [decimal](18, 0) not null,
    [Code] [nvarchar](20) null,
    [CreatedAt] [datetime] not null,
    [CustomerName] [nvarchar](max) null,
    [Phone] [nvarchar](max) null,
    [Address] [nvarchar](max) null,
    [Note] [nvarchar](max) null,
    [Status] [nvarchar](40) null,
    [Shipping] [decimal](18, 0) not null,
    [Total] [decimal](18, 0) not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NULL
BEGIN
create table [dbo].[OrderItems] (
    [Id] [int] not null identity,
    [OrderId] [int] not null,
    [VariantId] [int] not null,
    [ProductId] [int] null,
    [BrandName] [nvarchar](50) null,
    [ProductName] [nvarchar](max) null,
    [Size] [int] not null,
    [Quantity] [int] not null,
    [Price] [decimal](18, 0) not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Products', N'U') IS NULL
BEGIN
create table [dbo].[Products] (
    [Id] [int] not null identity,
    [Color] [nvarchar](50) null,
    [ImagesRevision] [int] not null,
    [BrandId] [int] null,
    [CategoryId] [int] null,
    [Name] [nvarchar](180) not null,
    [Brand] [nvarchar](50) not null,
    [Sku] [nvarchar](60) not null,
    [Price] [decimal](18, 0) not null,
    [OriginalPrice] [decimal](18, 0) null,
    [Description] [nvarchar](2000) null,
    [ImageUrl] [nvarchar](500) null,
    [Featured] [bit] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.ProductImages', N'U') IS NULL
BEGIN
create table [dbo].[ProductImages] (
    [Id] [int] not null identity,
    [ProductId] [int] not null,
    [Url] [nvarchar](500) not null,
    [SortOrder] [int] not null,
    [IsPrimary] [bit] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Variants', N'U') IS NULL
BEGIN
create table [dbo].[Variants] (
    [Id] [int] not null identity,
    [ProductId] [int] not null,
    [Size] [int] not null,
    [Stock] [int] not null,
    [Revision] [int] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.Vouchers', N'U') IS NULL
BEGIN
create table [dbo].[Vouchers] (
    [Id] [int] not null identity,
    [Code] [nvarchar](30) not null,
    [Percent] [int] not null,
    [MinimumSubtotal] [decimal](18, 0) not null,
    [ValidFrom] [datetime] not null,
    [ValidUntil] [datetime] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.VoucherEmails', N'U') IS NULL
BEGIN
create table [dbo].[VoucherEmails] (
    [Id] [int] not null identity,
    [CustomerId] [int] not null,
    [VoucherId] [int] not null,
    [Status] [nvarchar](20) not null,
    [Attempts] [int] not null,
    [CreatedAt] [datetime] not null,
    [SentAt] [datetime] null,
    [LockedAt] [datetime] null,
    [RetryAfter] [datetime] null,
    [LastError] [nvarchar](1000) null,
    primary key ([Id])
);
END;

IF OBJECT_ID(N'dbo.VoucherRedemptions', N'U') IS NULL
BEGIN
create table [dbo].[VoucherRedemptions] (
    [Id] [int] not null identity,
    [CustomerId] [int] not null,
    [VoucherId] [int] not null,
    [OrderId] [int] not null,
    primary key ([Id])
);
END;

IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.OrderItems') AND referenced_object_id=OBJECT_ID(N'dbo.Orders'))
 ALTER TABLE dbo.OrderItems ADD CONSTRAINT Order_Items FOREIGN KEY(OrderId) REFERENCES dbo.Orders(Id) ON DELETE CASCADE;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.Variants') AND referenced_object_id=OBJECT_ID(N'dbo.Products'))
 ALTER TABLE dbo.Variants ADD CONSTRAINT Product_Variants FOREIGN KEY(ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Products') AND name=N'IX_Sku')
 CREATE UNIQUE INDEX [IX_Sku] ON dbo.[Products](Sku);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Variants') AND name=N'IX_ProductSize')
 CREATE UNIQUE INDEX [IX_ProductSize] ON dbo.[Variants](ProductId, Size);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.AdminUsers') AND name=N'IX_Email')
 CREATE UNIQUE INDEX [IX_Email] ON dbo.[AdminUsers](Email);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Orders') AND name=N'IX_Code')
 CREATE UNIQUE INDEX [IX_Code] ON dbo.[Orders](Code);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.OrderItems') AND name=N'IX_OrderId')
 CREATE INDEX [IX_OrderId] ON dbo.[OrderItems](OrderId);

-- Eight sample products. Replace ImageUrl through the Admin UI after adding images.
INSERT INTO dbo.Products (Name,Brand,Sku,Price,OriginalPrice,Description,ImageUrl,Featured,Active,ImagesRevision)
SELECT s.Name,s.Brand,s.Sku,s.Price,s.OriginalPrice,
 N'Thiết kế dễ phối đồ, phù hợp đi học, đi làm và dạo phố. Liên hệ cửa hàng để được tư vấn kích thước và thông tin sản phẩm.',NULL,s.Featured,1,0
FROM (VALUES
 (N'Giày Nike Air Force 1 ''07 All White',N'Nike',N'SG-001',2490000,3050000,1),
 (N'Giày Nike Air Jordan 1 Low Panda',N'Nike',N'SG-002',2790000,4500000,1),
 (N'Giày Adidas Samba OG Cloud White',N'Adidas',N'SG-003',2290000,2800000,1),
 (N'Giày New Balance 530 White Natural Indigo',N'New Balance',N'SG-004',1890000,2790000,1),
 (N'Giày Puma Palermo Leather White',N'Puma',N'SG-005',1690000,2190000,0),
 (N'Giày MLB Chunky Liner New York',N'MLB',N'SG-006',2590000,2990000,0),
 (N'Giày Nike V2K Run Summit White',N'Nike',N'SG-007',2590000,3350000,0),
 (N'Giày Adidas Gazelle Indoor Green',N'Adidas',N'SG-008',2390000,2890000,0)
) AS s(Name,Brand,Sku,Price,OriginalPrice,Featured)
WHERE NOT EXISTS(SELECT 1 FROM dbo.Products p WHERE p.Sku=s.Sku);

-- Only insert missing sizes; never reset stock from an existing order.
INSERT INTO dbo.Variants(ProductId,Size,Stock,Revision)
SELECT p.Id,s.Size,5,0 FROM dbo.Products p
CROSS JOIN (VALUES(36),(37),(38),(39),(40),(41),(42),(43),(44)) AS s(Size)
WHERE p.Sku IN(N'SG-001',N'SG-002',N'SG-003',N'SG-004',N'SG-005',N'SG-006',N'SG-007',N'SG-008')
AND NOT EXISTS(SELECT 1 FROM dbo.Variants v WHERE v.ProductId=p.Id AND v.Size=s.Size);

-- AdminUsers stores PBKDF2-SHA256 password hashes. No plaintext default password.
-- The local admin account has already been created by create_table.exe.
-- On a new machine, run tools/DatabaseSetup to bootstrap an admin if none exists.
COMMIT TRANSACTION;
GO
SELECT DB_NAME() AS DatabaseName;
SELECT N'Products' AS TableName,COUNT(*) AS [RowCount] FROM dbo.Products
UNION ALL SELECT N'Variants',COUNT(*) FROM dbo.Variants
UNION ALL SELECT N'Orders',COUNT(*) FROM dbo.Orders
UNION ALL SELECT N'OrderItems',COUNT(*) FROM dbo.OrderItems
UNION ALL SELECT N'AdminUsers',COUNT(*) FROM dbo.AdminUsers;
GO

-- Add admin-managed categories without deleting products or creating default categories.
USE [ShopGiay];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Categories',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Categories(Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,Name nvarchar(180) NOT NULL,SortOrder int NOT NULL,Active bit NOT NULL);
END;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Categories') AND name=N'IX_Name')
 CREATE UNIQUE INDEX IX_Name ON dbo.Categories(Name);
IF COL_LENGTH(N'dbo.Products',N'CategoryId') IS NULL
 ALTER TABLE dbo.Products ADD CategoryId int NULL;
COMMIT TRANSACTION;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.Products') AND referenced_object_id=OBJECT_ID(N'dbo.Categories'))
 ALTER TABLE dbo.Products ADD CONSTRAINT FK_Products_Categories FOREIGN KEY(CategoryId) REFERENCES dbo.Categories(Id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Products') AND name=N'IX_CategoryId')
 CREATE INDEX IX_CategoryId ON dbo.Products(CategoryId);
GO

-- Preserve existing product brand names and move them to admin-managed Brands.
USE [ShopGiay];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Brands',N'U') IS NULL
 CREATE TABLE dbo.Brands(Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Brands PRIMARY KEY,Name nvarchar(50) NOT NULL,SortOrder int NOT NULL,Active bit NOT NULL);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Brands') AND name=N'IX_Name')
 CREATE UNIQUE INDEX IX_Name ON dbo.Brands(Name);
IF COL_LENGTH(N'dbo.Products',N'BrandId') IS NULL
 ALTER TABLE dbo.Products ADD BrandId int NULL;
COMMIT TRANSACTION;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
INSERT INTO dbo.Brands(Name,SortOrder,Active)
SELECT DISTINCT LTRIM(RTRIM(p.Brand)),0,1 FROM dbo.Products p
WHERE p.BrandId IS NULL AND LEN(LTRIM(RTRIM(p.Brand)))>0
AND NOT EXISTS(SELECT 1 FROM dbo.Brands b WHERE b.Name=LTRIM(RTRIM(p.Brand)));
UPDATE p SET BrandId=b.Id FROM dbo.Products p INNER JOIN dbo.Brands b ON b.Name=LTRIM(RTRIM(p.Brand)) WHERE p.BrandId IS NULL;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.Products') AND referenced_object_id=OBJECT_ID(N'dbo.Brands'))
 ALTER TABLE dbo.Products ADD CONSTRAINT FK_Products_Brands FOREIGN KEY(BrandId) REFERENCES dbo.Brands(Id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Products') AND name=N'IX_BrandId')
 CREATE INDEX IX_BrandId ON dbo.Products(BrandId);
COMMIT TRANSACTION;
GO

USE [ShopGiay];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'dbo.Products',N'ImagesRevision') IS NULL ALTER TABLE dbo.Products ADD ImagesRevision int NOT NULL CONSTRAINT DF_Products_ImagesRevision DEFAULT(0);
IF OBJECT_ID(N'dbo.ProductImages',N'U') IS NULL
 CREATE TABLE dbo.ProductImages(Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductImages PRIMARY KEY,ProductId int NOT NULL,Url nvarchar(500) NOT NULL,SortOrder int NOT NULL,IsPrimary bit NOT NULL,CONSTRAINT FK_ProductImages_Products FOREIGN KEY(ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.ProductImages') AND referenced_object_id=OBJECT_ID(N'dbo.Products'))
 ALTER TABLE dbo.ProductImages ADD CONSTRAINT FK_ProductImages_Products FOREIGN KEY(ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ProductImages') AND name=N'IX_ProductImages_ProductId') CREATE INDEX IX_ProductImages_ProductId ON dbo.ProductImages(ProductId);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ProductImages') AND name=N'IX_ProductImages_Primary') CREATE UNIQUE INDEX IX_ProductImages_Primary ON dbo.ProductImages(ProductId) WHERE IsPrimary=1;
INSERT INTO dbo.ProductImages(ProductId,Url,SortOrder,IsPrimary)
SELECT p.Id,p.ImageUrl,0,1 FROM dbo.Products p WHERE LEN(p.ImageUrl)>0 AND NOT EXISTS(SELECT 1 FROM dbo.ProductImages i WHERE i.ProductId=p.Id);
COMMIT TRANSACTION;
GO

USE [ShopGiay];
GO
IF COL_LENGTH(N'dbo.Products',N'Color') IS NULL
 ALTER TABLE dbo.Products ADD Color nvarchar(50) NULL;
GO

USE [ShopGiay];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Customers',N'U') IS NULL CREATE TABLE dbo.Customers(Id int IDENTITY PRIMARY KEY,Name nvarchar(100) NOT NULL,Email nvarchar(180) NOT NULL,PasswordHash nvarchar(max) NOT NULL,Phone nvarchar(20) NULL,Address nvarchar(500) NULL,IsActive bit NOT NULL,ReceiveVoucherEmails bit NOT NULL,CreatedAt datetime NOT NULL,SecurityStamp nvarchar(32) NOT NULL);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Customers') AND name=N'IX_Email')CREATE UNIQUE INDEX IX_Email ON dbo.Customers(Email);
IF OBJECT_ID(N'dbo.Vouchers',N'U') IS NULL CREATE TABLE dbo.Vouchers(Id int IDENTITY PRIMARY KEY,Code nvarchar(30) NOT NULL,[Percent] int NOT NULL,MinimumSubtotal decimal(18,0) NOT NULL,ValidFrom datetime NOT NULL,ValidUntil datetime NOT NULL,Active bit NOT NULL);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Vouchers') AND name=N'IX_Code')CREATE UNIQUE INDEX IX_Code ON dbo.Vouchers(Code);
IF OBJECT_ID(N'dbo.Banners',N'U') IS NULL CREATE TABLE dbo.Banners(Id int IDENTITY PRIMARY KEY,Title nvarchar(160) NOT NULL,Subtitle nvarchar(500) NULL,ButtonText nvarchar(50) NULL,LinkUrl nvarchar(500) NULL,ImageUrl nvarchar(500) NULL,SortOrder int NOT NULL,Active bit NOT NULL);
IF COL_LENGTH(N'dbo.AdminUsers',N'SecurityStamp') IS NULL ALTER TABLE dbo.AdminUsers ADD SecurityStamp nvarchar(32) NOT NULL CONSTRAINT DF_AdminUsers_Stamp DEFAULT(REPLACE(CONVERT(nvarchar(36),NEWID()),'-',''));
IF COL_LENGTH(N'dbo.Orders',N'CustomerId') IS NULL ALTER TABLE dbo.Orders ADD CustomerId int NULL;
IF COL_LENGTH(N'dbo.Orders',N'VoucherCode') IS NULL ALTER TABLE dbo.Orders ADD VoucherCode nvarchar(30) NULL;
IF COL_LENGTH(N'dbo.Orders',N'Discount') IS NULL ALTER TABLE dbo.Orders ADD Discount decimal(18,0) NOT NULL CONSTRAINT DF_Orders_Discount DEFAULT(0);
COMMIT TRANSACTION;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.Orders') AND referenced_object_id=OBJECT_ID(N'dbo.Customers')) ALTER TABLE dbo.Orders ADD CONSTRAINT FK_Orders_Customers FOREIGN KEY(CustomerId) REFERENCES dbo.Customers(Id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Orders') AND name=N'IX_CustomerId')CREATE INDEX IX_CustomerId ON dbo.Orders(CustomerId);
IF OBJECT_ID(N'dbo.VoucherRedemptions',N'U') IS NULL CREATE TABLE dbo.VoucherRedemptions(Id int IDENTITY PRIMARY KEY,CustomerId int NOT NULL,VoucherId int NOT NULL,OrderId int NOT NULL);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.VoucherRedemptions') AND name=N'IX_CustomerVoucher')CREATE UNIQUE INDEX IX_CustomerVoucher ON dbo.VoucherRedemptions(CustomerId,VoucherId);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.VoucherRedemptions') AND referenced_object_id=OBJECT_ID(N'dbo.Orders')) ALTER TABLE dbo.VoucherRedemptions ADD CONSTRAINT FK_Redemptions_Orders FOREIGN KEY(OrderId) REFERENCES dbo.Orders(Id);
IF OBJECT_ID(N'dbo.VoucherEmails',N'U') IS NULL CREATE TABLE dbo.VoucherEmails(Id int IDENTITY PRIMARY KEY,CustomerId int NOT NULL,VoucherId int NOT NULL,Status nvarchar(20) NOT NULL,Attempts int NOT NULL,CreatedAt datetime NOT NULL,SentAt datetime NULL,LockedAt datetime NULL,RetryAfter datetime NULL,LastError nvarchar(1000) NULL);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.VoucherEmails') AND name=N'IX_VoucherEmail')CREATE UNIQUE INDEX IX_VoucherEmail ON dbo.VoucherEmails(CustomerId,VoucherId);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.VoucherRedemptions') AND referenced_object_id=OBJECT_ID(N'dbo.Customers'))ALTER TABLE dbo.VoucherRedemptions ADD CONSTRAINT FK_Redemptions_Customers FOREIGN KEY(CustomerId) REFERENCES dbo.Customers(Id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.VoucherRedemptions') AND referenced_object_id=OBJECT_ID(N'dbo.Vouchers'))ALTER TABLE dbo.VoucherRedemptions ADD CONSTRAINT FK_Redemptions_Vouchers FOREIGN KEY(VoucherId) REFERENCES dbo.Vouchers(Id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.VoucherEmails') AND referenced_object_id=OBJECT_ID(N'dbo.Customers'))ALTER TABLE dbo.VoucherEmails ADD CONSTRAINT FK_VoucherEmails_Customers FOREIGN KEY(CustomerId) REFERENCES dbo.Customers(Id);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.VoucherEmails') AND referenced_object_id=OBJECT_ID(N'dbo.Vouchers'))ALTER TABLE dbo.VoucherEmails ADD CONSTRAINT FK_VoucherEmails_Vouchers FOREIGN KEY(VoucherId) REFERENCES dbo.Vouchers(Id);
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.Vouchers') AND name=N'CK_Vouchers_Values')ALTER TABLE dbo.Vouchers ADD CONSTRAINT CK_Vouchers_Values CHECK([Percent] BETWEEN 1 AND 100 AND MinimumSubtotal>=0 AND ValidUntil>ValidFrom);
GO

USE [ShopGiay];
GO
IF COL_LENGTH(N'dbo.OrderItems',N'ProductId') IS NULL ALTER TABLE dbo.OrderItems ADD ProductId int NULL;
IF COL_LENGTH(N'dbo.OrderItems',N'BrandName') IS NULL ALTER TABLE dbo.OrderItems ADD BrandName nvarchar(50) NULL;
GO
UPDATE item SET ProductId=product.Id,BrandName=product.Brand
FROM dbo.OrderItems item INNER JOIN dbo.Variants variant ON variant.Id=item.VariantId INNER JOIN dbo.Products product ON product.Id=variant.ProductId
WHERE item.ProductId IS NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Orders') AND name=N'IX_Orders_Status_CreatedAt')CREATE INDEX IX_Orders_Status_CreatedAt ON dbo.Orders(Status,CreatedAt);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.OrderItems') AND name=N'IX_OrderItems_OrderId')CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);
GO

USE [ShopGiay];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH('dbo.Orders','PaymentMethod') IS NULL ALTER TABLE dbo.Orders ADD PaymentMethod nvarchar(10) NOT NULL CONSTRAINT DF_Orders_PaymentMethod DEFAULT N'COD';
IF COL_LENGTH('dbo.Orders','PaymentStatus') IS NULL ALTER TABLE dbo.Orders ADD PaymentStatus nvarchar(30) NOT NULL CONSTRAINT DF_Orders_PaymentStatus DEFAULT N'Unpaid';
IF COL_LENGTH('dbo.Orders','PaymentTransactionNo') IS NULL ALTER TABLE dbo.Orders ADD PaymentTransactionNo nvarchar(100) NULL;
IF COL_LENGTH('dbo.Orders','PaidAt') IS NULL ALTER TABLE dbo.Orders ADD PaidAt datetime NULL;
IF COL_LENGTH('dbo.Orders','PaymentMerchant') IS NULL ALTER TABLE dbo.Orders ADD PaymentMerchant nvarchar(8) NULL;
IF COL_LENGTH('dbo.Orders','OwnerEmailStatus') IS NULL ALTER TABLE dbo.Orders ADD OwnerEmailStatus nvarchar(30) NOT NULL CONSTRAINT DF_Orders_OwnerEmailStatus DEFAULT N'Skipped';
IF COL_LENGTH('dbo.Orders','OwnerEmailRecipient') IS NULL ALTER TABLE dbo.Orders ADD OwnerEmailRecipient nvarchar(180) NULL;
IF COL_LENGTH('dbo.Orders','OwnerEmailRetryAt') IS NULL ALTER TABLE dbo.Orders ADD OwnerEmailRetryAt datetime NULL;
IF COL_LENGTH('dbo.Orders','OwnerEmailSentAt') IS NULL ALTER TABLE dbo.Orders ADD OwnerEmailSentAt datetime NULL;
COMMIT;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Orders_OwnerEmail' AND object_id=OBJECT_ID('dbo.Orders')) CREATE INDEX IX_Orders_OwnerEmail ON dbo.Orders(OwnerEmailStatus,OwnerEmailRetryAt);
GO
