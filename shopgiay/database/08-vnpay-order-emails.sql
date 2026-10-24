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
