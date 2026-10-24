USE [ShopGiay];
GO
IF COL_LENGTH(N'dbo.Products',N'Color') IS NULL
 ALTER TABLE dbo.Products ADD Color nvarchar(50) NULL;
GO
