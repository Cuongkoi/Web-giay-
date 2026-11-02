using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace shopgiay.Models
{
    public class Product
    {
        [StringLength(50)] public string? Color { get; set; }
        public List<ProductImage> Images { get; set; } = new List<ProductImage>();
        [ConcurrencyCheck] public int ImagesRevision { get; set; }
        public int? BrandId { get; set; }
        public Brand? BrandInfo { get; set; }
        public int? CategoryId { get; set; }
        public Category? Category { get; set; }
        public int Id { get; set; }
        [Required, StringLength(180)] public string Name { get; set; } = "";
        [Required, StringLength(50)] public string Brand { get; set; } = "Nike";
        [Required, StringLength(60), Index(IsUnique = true)] public string Sku { get; set; } = "";
        [Range(1000, 100000000)] public decimal Price { get; set; }
        [Range(0, 100000000)] public decimal? OriginalPrice { get; set; }
        [StringLength(2000)] public string Description { get; set; } = "";
        [StringLength(500)] public string? ImageUrl { get; set; }
        public bool Featured { get; set; }
        public bool Active { get; set; } = true;
        public List<Variant> Variants { get; set; } = [];
    }
    public class Variant
    {
        public int Id { get; set; }
        [Index("IX_ProductSize", 1, IsUnique = true)] public int ProductId { get; set; }
        public Product Product { get; set; } = null!;
        [Range(30, 50), Index("IX_ProductSize", 2, IsUnique = true)] public int Size { get; set; }
        [Range(0, 10000)] public int Stock { get; set; }
        [ConcurrencyCheck] public int Revision { get; set; }
    }
    public class AdminUser { public int Id { get; set; } [StringLength(180), Index(IsUnique = true)] public string Email { get; set; } = ""; public string PasswordHash { get; set; } = ""; [StringLength(32)] public string SecurityStamp { get; set; } = Guid.NewGuid().ToString("N"); }
    public class Order
    {
        [StringLength(10)] public string PaymentMethod { get; set; } = "COD";
        [ConcurrencyCheck, StringLength(30)] public string PaymentStatus { get; set; } = "Unpaid";
        [StringLength(100)] public string? PaymentTransactionNo { get; set; }
        public DateTime? PaidAt { get; set; }
        [StringLength(8)] public string? PaymentMerchant { get; set; }
        [StringLength(30)] public string OwnerEmailStatus { get; set; } = "Pending";
        [StringLength(180)] public string? OwnerEmailRecipient { get; set; }
        public DateTime? OwnerEmailRetryAt { get; set; }
        public DateTime? OwnerEmailSentAt { get; set; }

        public int? CustomerId { get; set; }
        public Customer? Customer { get; set; }
        [StringLength(30)] public string? VoucherCode { get; set; }
        public decimal Discount { get; set; }
        public int Id { get; set; }
        [StringLength(20), Index(IsUnique = true)] public string Code { get; set; } = Guid.NewGuid().ToString("N").Substring(0, 10).ToUpperInvariant(); public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public string CustomerName { get; set; } = ""; public string Phone { get; set; } = ""; public string Address { get; set; } = ""; public string? Note { get; set; }
        [ConcurrencyCheck, StringLength(40)] public string Status { get; set; } = "Chờ xác nhận"; public decimal Shipping { get; set; }
        public decimal Total { get; set; }
        public List<OrderItem> Items { get; set; } = [];
    }
    public class OrderItem { public int Id { get; set; } public int OrderId { get; set; } public int VariantId { get; set; } public int? ProductId { get; set; } [StringLength(50)] public string? BrandName { get; set; } public string ProductName { get; set; } = ""; public int Size { get; set; } public int Quantity { get; set; } public decimal Price { get; set; } }

}
