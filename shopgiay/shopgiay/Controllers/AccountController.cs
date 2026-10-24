using System;
using System.Linq;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Runtime.Caching;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;
using System.Web.Security;
using shopgiay.Models;
using shopgiay.ModelView;
using shopgiay.Services;
using shopgiay.Filters;
namespace shopgiay.Controllers {
 public class AccountController:ShopController {
  public ActionResult Register()=>View(new RegisterInput());
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Register(RegisterInput input){
   input.Email=(input.Email??"").Trim().ToLowerInvariant();input.Name=(input.Name??"").Trim();
   if(input.Name.Length==0)ModelState.AddModelError("Name","Vui lòng nhập họ tên.");
   if(await db.Customers.AnyAsync(c=>c.Email==input.Email))ModelState.AddModelError("Email","Email đã được đăng ký.");
   if(!ModelState.IsValid)return View(input);
   var customer=new Customer{Name=input.Name,Email=input.Email,PasswordHash=PasswordService.Hash(input.Password),ReceiveVoucherEmails=input.ReceiveVoucherEmails};db.Customers.Add(customer);
   try{await db.SaveChangesAsync();}catch(DbUpdateException){ModelState.AddModelError("Email","Email đã được đăng ký. Vui lòng dùng email khác.");return View(input);}
   SignIn(customer);return RedirectToAction("Index");
  }
  public ActionResult Login(string? returnUrl){ViewBag.ReturnUrl=Url.IsLocalUrl(returnUrl)?returnUrl:"/Account";return View(new LoginInput());}
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Login(LoginInput input,string? returnUrl){
   ViewBag.ReturnUrl=Url.IsLocalUrl(returnUrl)?returnUrl:"/Account";var key="customer-login:"+Request.UserHostAddress;var attempts=(int?)MemoryCache.Default[key]??0;
   if(attempts>=8){ModelState.AddModelError("","Bạn đã thử quá nhiều lần. Vui lòng đợi 15 phút.");return View(input);}if(!ModelState.IsValid)return View(input);
   var email=input.Email.Trim().ToLowerInvariant();var customer=await db.Customers.SingleOrDefaultAsync(c=>c.Email==email);
   if(customer==null||!customer.IsActive||!PasswordService.Verify(input.Password,customer.PasswordHash)){MemoryCache.Default.Set(key,attempts+1,DateTimeOffset.UtcNow.AddMinutes(15));ModelState.AddModelError("","Email hoặc mật khẩu không đúng, hoặc tài khoản đã bị khóa.");return View(input);}
   MemoryCache.Default.Remove(key);SignIn(customer);return Redirect((string)ViewBag.ReturnUrl);
  }
  private void SignIn(Customer c)=>SeparateAuthService.SignInCustomer(c,Request,Response);
  [CustomerAuthorize]public async Task<ActionResult> Index(){var customer=CurrentCustomer!;var orders=await db.Orders.Include(o=>o.Items).Where(o=>o.CustomerId==customer.Id).OrderByDescending(o=>o.Id).ToListAsync();var completed=orders.Count(o=>o.Status=="Hoàn thành");var now=DateTime.UtcNow;
   var vouchers=completed>=3?await db.Vouchers.Where(v=>v.Active&&v.ValidFrom<=now&&v.ValidUntil>=now&&!db.VoucherRedemptions.Any(r=>r.VoucherId==v.Id&&r.CustomerId==customer.Id)).OrderBy(v=>v.ValidUntil).ToListAsync():new System.Collections.Generic.List<Voucher>();
   return View(new CustomerAccountView{Customer=customer,Orders=orders,CompletedOrders=completed,Vouchers=vouchers});
  }
  [CustomerAuthorize,HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> EmailPreference(bool receiveVoucherEmails=false){var customer=await db.Customers.FindAsync(CurrentCustomer!.Id);customer.ReceiveVoucherEmails=receiveVoucherEmails;await db.SaveChangesAsync();EmailOutboxService.Kick();TempData["Success"]="Đã lưu lựa chọn nhận email voucher.";return RedirectToAction("Index");}
  [HttpPost,ValidateAntiForgeryToken]public ActionResult Logout(){SeparateAuthService.SignOutCustomer(Request,Response);return RedirectToAction("Index","Home");}
 }
}

