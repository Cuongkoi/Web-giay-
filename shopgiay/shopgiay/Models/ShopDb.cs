using System.Data.Entity;
namespace shopgiay.Models
{
    public class ShopDb : DbContext
    {
        public ShopDb() : base("name=ShopDb") { Configuration.LazyLoadingEnabled = false; }
        public DbSet<Product> Products { get; set; } = null!;
        public DbSet<Variant> Variants { get; set; } = null!;
        public DbSet<Order> Orders { get; set; } = null!;
        public DbSet<AdminUser> Admins { get; set; } = null!;
        public DbSet<Category> Categories { get; set; } = null!;
        public DbSet<Brand> Brands { get; set; } = null!;
        public DbSet<ProductImage> ProductImages { get; set; } = null!;
        public DbSet<Customer> Customers { get; set; } = null!; public DbSet<Voucher> Vouchers { get; set; } = null!; public DbSet<VoucherRedemption> VoucherRedemptions { get; set; } = null!; public DbSet<VoucherEmail> VoucherEmails { get; set; } = null!; public DbSet<Banner> Banners { get; set; } = null!;
        protected override void OnModelCreating(DbModelBuilder b)
        {
            b.Entity<Order>().HasOptional(x => x.Customer).WithMany().HasForeignKey(x => x.CustomerId).WillCascadeOnDelete(false);
            b.Entity<Order>().Property(x => x.Discount).HasPrecision(18, 0); b.Entity<Voucher>().Property(x => x.MinimumSubtotal).HasPrecision(18, 0);
            b.Entity<VoucherRedemption>().HasRequired(x => x.Order).WithMany().HasForeignKey(x => x.OrderId).WillCascadeOnDelete(false);
            b.Entity<Product>().HasMany(x => x.Images).WithRequired(x => x.Product).HasForeignKey(x => x.ProductId).WillCascadeOnDelete(true);
            b.Entity<Product>().HasOptional(x => x.BrandInfo).WithMany().HasForeignKey(x => x.BrandId).WillCascadeOnDelete(false);
            b.Entity<Product>().HasOptional(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).WillCascadeOnDelete(false);
            b.Entity<Product>().Property(x => x.Price).HasPrecision(18, 0); b.Entity<Product>().Property(x => x.OriginalPrice).HasPrecision(18, 0);
            b.Entity<Order>().Property(x => x.Total).HasPrecision(18, 0); b.Entity<Order>().Property(x => x.Shipping).HasPrecision(18, 0); b.Entity<OrderItem>().Property(x => x.Price).HasPrecision(18, 0);
            b.Entity<Product>().HasMany(x => x.Variants).WithRequired(x => x.Product).HasForeignKey(x => x.ProductId).WillCascadeOnDelete(true);
            b.Entity<Order>().HasMany(x => x.Items).WithRequired().HasForeignKey(x => x.OrderId).WillCascadeOnDelete(true);
            base.OnModelCreating(b);
        }
    }
}
