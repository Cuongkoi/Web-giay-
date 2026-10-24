using System;
using System.Data.Entity;
using System.Runtime.Caching;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;
using System.Web.Security;
using shopgiay.ModelView;
using shopgiay.Services;
namespace shopgiay.Areas.Admin.Controllers
{
    public class AccountController : shopgiay.Controllers.ShopController
    {
        public ActionResult Login(string? returnUrl) { ViewBag.ReturnUrl = Url.IsLocalUrl(returnUrl) && returnUrl!.StartsWith("/Admin", StringComparison.OrdinalIgnoreCase) ? returnUrl : "/Admin"; return View(new LoginInput()); }
        [HttpPost, ValidateAntiForgeryToken]
        public async Task<ActionResult> Login(LoginInput input, string? returnUrl)
        {
            ViewBag.ReturnUrl = Url.IsLocalUrl(returnUrl) && returnUrl!.StartsWith("/Admin", StringComparison.OrdinalIgnoreCase) ? returnUrl : "/Admin";
            var key = "login:" + Request.UserHostAddress; var attempts = (int?)(MemoryCache.Default[key]) ?? 0;
            if (attempts >= 8) { ModelState.AddModelError("", "Bạn đã thử quá nhiều lần. Vui lòng đợi 15 phút."); return View(input); }
            if (!ModelState.IsValid) return View(input);
            var normalized = input.Email.Trim().ToLowerInvariant(); var user = await db.Admins.SingleOrDefaultAsync(x => x.Email == normalized);
            if (user == null || !PasswordService.Verify(input.Password, user.PasswordHash)) { MemoryCache.Default.Set(key, attempts + 1, DateTimeOffset.UtcNow.AddMinutes(15)); ModelState.AddModelError("", "Email hoặc mật khẩu không đúng."); return View(input); }
            MemoryCache.Default.Remove(key);
            SeparateAuthService.SignInAdmin(user, Request, Response);
            return Redirect((string)ViewBag.ReturnUrl);
        }
        [HttpPost, ValidateAntiForgeryToken] public ActionResult Logout() { SeparateAuthService.SignOutAdmin(Request, Response); return RedirectToAction("Login", "Account", new { area = "Admin" }); }
    }
}



