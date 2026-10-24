create table [dbo].[AdminUsers] (
    [Id] [int] not null identity,
    [Email] [nvarchar](180) null,
    [PasswordHash] [nvarchar](max) null,
    [SecurityStamp] [nvarchar](32) null,
    primary key ([Id])
);
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
create table [dbo].[Brands] (
    [Id] [int] not null identity,
    [Name] [nvarchar](50) not null,
    [SortOrder] [int] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
create table [dbo].[Categories] (
    [Id] [int] not null identity,
    [Name] [nvarchar](180) not null,
    [SortOrder] [int] not null,
    [Active] [bit] not null,
    primary key ([Id])
);
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
create table [dbo].[ProductImages] (
    [Id] [int] not null identity,
    [ProductId] [int] not null,
    [Url] [nvarchar](500) not null,
    [SortOrder] [int] not null,
    [IsPrimary] [bit] not null,
    primary key ([Id])
);
create table [dbo].[Variants] (
    [Id] [int] not null identity,
    [ProductId] [int] not null,
    [Size] [int] not null,
    [Stock] [int] not null,
    [Revision] [int] not null,
    primary key ([Id])
);
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
create table [dbo].[VoucherRedemptions] (
    [Id] [int] not null identity,
    [CustomerId] [int] not null,
    [VoucherId] [int] not null,
    [OrderId] [int] not null,
    primary key ([Id])
);
alter table [dbo].[Orders] add constraint [Order_Customer] foreign key ([CustomerId]) references [dbo].[Customers]([Id]);
alter table [dbo].[OrderItems] add constraint [Order_Items] foreign key ([OrderId]) references [dbo].[Orders]([Id]) on delete cascade;
alter table [dbo].[Products] add constraint [Product_BrandInfo] foreign key ([BrandId]) references [dbo].[Brands]([Id]);
alter table [dbo].[Products] add constraint [Product_Category] foreign key ([CategoryId]) references [dbo].[Categories]([Id]);
alter table [dbo].[ProductImages] add constraint [Product_Images] foreign key ([ProductId]) references [dbo].[Products]([Id]) on delete cascade;
alter table [dbo].[Variants] add constraint [Product_Variants] foreign key ([ProductId]) references [dbo].[Products]([Id]) on delete cascade;
alter table [dbo].[VoucherRedemptions] add constraint [VoucherRedemption_Order] foreign key ([OrderId]) references [dbo].[Orders]([Id]);

