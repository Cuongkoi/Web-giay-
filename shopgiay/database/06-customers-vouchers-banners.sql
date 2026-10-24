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
