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
