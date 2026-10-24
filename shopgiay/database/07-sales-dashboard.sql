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
