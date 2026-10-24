using System;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using shopgiay.Models;
namespace shopgiay.Services {
 public class VoucherResult {public Voucher? Voucher{get;set;}public decimal Discount{get;set;}public string? Error{get;set;}}
 public static class VoucherService {
  public static async Task<VoucherResult> Evaluate(ShopDb db,int customerId,string? code,decimal subtotal,bool lockVoucher=false){
   code=(code??"").Trim().ToUpperInvariant();if(code.Length==0)return new VoucherResult();
   if(await db.Orders.CountAsync(o=>o.CustomerId==customerId&&o.Status=="Hoàn thành")<3)return new VoucherResult{Error="Voucher này chỉ dành cho khách quen có ít nhất 3 đơn đã hoàn thành."};
   var voucher=lockVoucher?await db.Database.SqlQuery<Voucher>("SELECT * FROM dbo.Vouchers WITH (UPDLOCK,HOLDLOCK) WHERE Code=@p0",code).SingleOrDefaultAsync():await db.Vouchers.AsNoTracking().SingleOrDefaultAsync(v=>v.Code==code);
   var now=DateTime.UtcNow;
   if(voucher==null||!voucher.Active||voucher.ValidFrom>now||voucher.ValidUntil<now)return new VoucherResult{Error="Mã voucher không tồn tại, chưa đến thời gian dùng hoặc đã hết hạn."};
   if(subtotal<voucher.MinimumSubtotal)return new VoucherResult{Error="Đơn hàng chưa đạt giá trị tối thiểu "+voucher.MinimumSubtotal.ToString("N0")+"₫."};
   if(await db.VoucherRedemptions.AnyAsync(r=>r.CustomerId==customerId&&r.VoucherId==voucher.Id))return new VoucherResult{Error="Bạn đã sử dụng voucher này."};
   return new VoucherResult{Voucher=voucher,Discount=Math.Round(subtotal*voucher.Percent/100m,0,MidpointRounding.AwayFromZero)};
  }
 }
}
