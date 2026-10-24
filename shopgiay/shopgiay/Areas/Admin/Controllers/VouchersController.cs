using System;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Mvc;
using shopgiay.Areas.Admin.Filters;
using shopgiay.Models;
using shopgiay.ModelView;
using shopgiay.Services;
namespace shopgiay.Areas.Admin.Controllers {
 [AdminAuthorize]public class VouchersController:shopgiay.Controllers.ShopController {
  public async Task<ActionResult> Index()=>View(await db.Vouchers.OrderByDescending(v=>v.Id).ToListAsync());
  public async Task<ActionResult> Edit(int? id){if(!id.HasValue)return View(new VoucherEditInput());var v=await db.Vouchers.FindAsync(id.Value);return v==null?HttpNotFound():View(new VoucherEditInput{Id=v.Id,Code=v.Code,Percent=v.Percent,MinimumSubtotal=v.MinimumSubtotal,StartsLocal=v.ValidFrom.AddHours(7),EndsLocal=v.ValidUntil.AddHours(7),Active=v.Active});}
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Edit(int id,VoucherEditInput input){
   input.Code=(input.Code??"").Trim().ToUpperInvariant();if(input.EndsLocal<=input.StartsLocal)ModelState.AddModelError("EndsLocal","Thời gian kết thúc phải sau thời gian bắt đầu.");
   if(await db.Vouchers.AnyAsync(v=>v.Code==input.Code&&v.Id!=id))ModelState.AddModelError("Code","Mã voucher đã tồn tại.");if(!ModelState.IsValid){input.Id=id;return View(input);}
   var voucher=id==0?new Voucher():await db.Vouchers.FindAsync(id);if(voucher==null)return HttpNotFound();if(id==0)db.Vouchers.Add(voucher);
   voucher.Code=input.Code;voucher.Percent=input.Percent;voucher.MinimumSubtotal=input.MinimumSubtotal;voucher.ValidFrom=DateTime.SpecifyKind(input.StartsLocal.AddHours(-7),DateTimeKind.Utc);voucher.ValidUntil=DateTime.SpecifyKind(input.EndsLocal.AddHours(-7),DateTimeKind.Utc);voucher.Active=input.Active;
   try{await db.SaveChangesAsync();}catch(DbUpdateException){ModelState.AddModelError("","Không lưu được voucher. Mã có thể đã tồn tại.");input.Id=id;return View(input);}EmailOutboxService.Kick();TempData["Success"]="Đã lưu voucher. Hệ thống sẽ xếp email cho khách quen đã đăng ký nhận tin.";return RedirectToAction("Index");
  }
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Delete(int id){var v=await db.Vouchers.FindAsync(id);if(v==null)return HttpNotFound();v.Active=false;await db.SaveChangesAsync();TempData["Success"]="Đã ngừng voucher; lịch sử sử dụng được giữ lại.";return RedirectToAction("Index");}
  public async Task<ActionResult> Emails(){ViewBag.SmtpConfigured=EmailOutboxService.IsConfigured;ViewBag.Customers=await db.Customers.AsNoTracking().ToDictionaryAsync(c=>c.Id,c=>c.Email);ViewBag.Vouchers=await db.Vouchers.AsNoTracking().ToDictionaryAsync(v=>v.Id,v=>v.Code);return View(await db.VoucherEmails.OrderByDescending(e=>e.Id).Take(200).ToListAsync());}
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> RetryEmails(){await db.Database.ExecuteSqlCommandAsync("UPDATE dbo.VoucherEmails SET Status='Pending', RetryAfter=NULL WHERE Status='Failed'");EmailOutboxService.Kick();TempData["Success"]="Đã yêu cầu xử lý hàng đợi email. Chưa có SMTP thì thư vẫn ở trạng thái chờ.";return RedirectToAction("Emails");}
 }
}
