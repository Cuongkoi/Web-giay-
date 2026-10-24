using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace shopgiay.Models {
 public class Customer {
  public int Id{get;set;}
  [Required,StringLength(100)]public string Name{get;set;}="";
  [Required,StringLength(180),Index(IsUnique=true)]public string Email{get;set;}="";
  [Required]public string PasswordHash{get;set;}="";
  [StringLength(20)]public string? Phone{get;set;}
  [StringLength(500)]public string? Address{get;set;}
  public bool IsActive{get;set;}=true;public bool ReceiveVoucherEmails{get;set;}
  public DateTime CreatedAt{get;set;}=DateTime.UtcNow;
  [Required,StringLength(32)]public string SecurityStamp{get;set;}=Guid.NewGuid().ToString("N");
 }
 public class Voucher {
  public int Id{get;set;}
  [Required,StringLength(30),Index(IsUnique=true),RegularExpression(@"[A-Z0-9_-]{3,30}",ErrorMessage="Mã gồm 3–30 chữ cái in hoa, số, dấu - hoặc _.")]public string Code{get;set;}="";
  [Range(1,100)]public int Percent{get;set;}
  [Range(0,1000000000)]public decimal MinimumSubtotal{get;set;}
  public DateTime ValidFrom{get;set;}=DateTime.UtcNow;public DateTime ValidUntil{get;set;}=DateTime.UtcNow.AddDays(30);
  public bool Active{get;set;}=true;
 }
 public class VoucherRedemption {
  public int Id{get;set;}
  [Index("IX_CustomerVoucher",1,IsUnique=true)]public int CustomerId{get;set;}
  [Index("IX_CustomerVoucher",2,IsUnique=true)]public int VoucherId{get;set;}
  public int OrderId{get;set;}public Order Order{get;set;}=null!;
 }
 public class VoucherEmail {
  public int Id{get;set;}
  [Index("IX_VoucherEmail",1,IsUnique=true)]public int CustomerId{get;set;}
  [Index("IX_VoucherEmail",2,IsUnique=true)]public int VoucherId{get;set;}
  [Required,StringLength(20)]public string Status{get;set;}="Pending";
  public int Attempts{get;set;}public DateTime CreatedAt{get;set;}=DateTime.UtcNow;public DateTime? SentAt{get;set;}public DateTime? LockedAt{get;set;}public DateTime? RetryAfter{get;set;}
  [StringLength(1000)]public string? LastError{get;set;}
 }
 public class Banner {
  public int Id{get;set;}
  [Required,StringLength(160)]public string Title{get;set;}="";
  [StringLength(500)]public string? Subtitle{get;set;}
  [StringLength(50)]public string? ButtonText{get;set;}
  [StringLength(500)]public string? LinkUrl{get;set;}
  [StringLength(500)]public string? ImageUrl{get;set;}
  [Range(0,10000)]public int SortOrder{get;set;}
  public bool Active{get;set;}=true;
 }
}
