from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
schema=(root/'database/schema.sqlserver.sql').read_text(encoding='utf-8-sig')
tables=re.findall(r'create table \[dbo\]\.\[(\w+)\] \([\s\S]*?\n\);',schema)
output='''-- STEP STORE / ASP.NET MVC 5 + Entity Framework 6 / SQL Server
-- Connect in SSMS to WINDOWS-PC\\SQLEXPRESS, open this file, press F5.
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
'''
for name in tables:
 stmt=re.search(r'create table \[dbo\]\.\['+name+r'\] \([\s\S]*?\n\);',schema).group(0)
 output+=f"\nIF OBJECT_ID(N'dbo.{name}', N'U') IS NULL\nBEGIN\n{stmt}\nEND;\n"
output+='''
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.OrderItems') AND referenced_object_id=OBJECT_ID(N'dbo.Orders'))
 ALTER TABLE dbo.OrderItems ADD CONSTRAINT Order_Items FOREIGN KEY(OrderId) REFERENCES dbo.Orders(Id) ON DELETE CASCADE;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.Variants') AND referenced_object_id=OBJECT_ID(N'dbo.Products'))
 ALTER TABLE dbo.Variants ADD CONSTRAINT Product_Variants FOREIGN KEY(ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE;
'''
for table,name,columns,unique in [('Products','IX_Sku','Sku',True),('Variants','IX_ProductSize','ProductId, Size',True),('AdminUsers','IX_Email','Email',True),('Orders','IX_Code','Code',True),('OrderItems','IX_OrderId','OrderId',False)]:
 output+=f"IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.{table}') AND name=N'{name}')\n CREATE {'UNIQUE ' if unique else ''}INDEX [{name}] ON dbo.[{table}]({columns});\n"
output+='''
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
'''
output+='\n'+(root/'database/02-admin-categories.sql').read_text(encoding='utf-8-sig')
output+='\n'+(root/'database/03-admin-brands.sql').read_text(encoding='utf-8-sig')
output+='\n'+(root/'database/04-product-images.sql').read_text(encoding='utf-8-sig')
output+='\n'+(root/'database/05-product-colors.sql').read_text(encoding='utf-8-sig')
output+='\n'+(root/'database/06-customers-vouchers-banners.sql').read_text(encoding='utf-8-sig')
output+='\n'+(root/'database/07-sales-dashboard.sql').read_text(encoding='utf-8-sig')
output+='\n'+(root/'database/08-vnpay-order-emails.sql').read_text(encoding='utf-8-sig')
(root/'database/01-create-shopgiay.sql').write_text(output,encoding='utf-8-sig')

