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
