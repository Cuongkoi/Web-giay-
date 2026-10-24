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
