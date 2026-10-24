using System;
using System.IO;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;
using shopgiay.Areas.Admin.Filters;
using shopgiay.ModelView;
using shopgiay.Services;
namespace shopgiay.Areas.Admin.Controllers {
 [AdminAuthorize]public class EmailSettingsController:shopgiay.Controllers.ShopController {
  private void Status(){ViewBag.PasswordConfigured=EmailSettingsService.Current.HasCredentials;}
  public ActionResult Index(){var s=EmailSettingsService.Current;Status();return View(new EmailSettingsInput{OrderNotificationsEnabled=s.OrderNotificationsEnabled,OwnerEmail=s.OwnerEmail,Enabled=s.Enabled,Host=s.Host,Port=s.Port,User=s.User,FromAddress=s.FromAddress,SenderName=s.SenderName});}
  [HttpPost,ValidateAntiForgeryToken]public ActionResult Index(EmailSettingsInput input){
   input.User=(input.User??"").Trim();input.FromAddress=(input.FromAddress??"").Trim();input.Host=(input.Host??"").Trim().ToLowerInvariant();
   var previous=EmailSettingsService.Current;
   if(previous.HasCredentials&&string.IsNullOrWhiteSpace(input.AppPassword)&&(!string.Equals(previous.User,input.User,StringComparison.OrdinalIgnoreCase)||!string.Equals(previous.Host,input.Host,StringComparison.OrdinalIgnoreCase)||previous.Port!=input.Port))ModelState.AddModelError("","Khi đổi Gmail hoặc máy chủ/cổng SMTP, hãy nhập App Password mới.");
   if(input.OrderNotificationsEnabled&&string.IsNullOrWhiteSpace(input.OwnerEmail))ModelState.AddModelError("OwnerEmail","Nhập email chủ shop nhận đơn mới.");
   if((input.Enabled||input.OrderNotificationsEnabled)&&input.User.Length==0)ModelState.AddModelError("User","Vui lòng nhập Gmail gửi thư.");
   if((input.Enabled||input.OrderNotificationsEnabled)&&string.IsNullOrWhiteSpace(input.AppPassword)&&!EmailSettingsService.Current.HasCredentials)ModelState.AddModelError("AppPassword","Vui lòng nhập App Password của Gmail.");
   if(!ModelState.IsValid){input.AppPassword=null;ModelState.Remove("AppPassword");ModelState.AddModelError("","Kiểm tra các trường bắt buộc. Nếu cần đổi App Password, vui lòng nhập lại.");Status();return View(input);}
   try{EmailSettingsService.Save(input);}catch(Exception ex)when(ex is IOException||ex is UnauthorizedAccessException||ex is CryptographicException){input.AppPassword=null;ModelState.Remove("AppPassword");ModelState.AddModelError("","Không lưu được cấu hình email. Kiểm tra quyền ghi thư mục App_Data.");Status();return View(input);}
   if(input.Enabled||input.OrderNotificationsEnabled)EmailOutboxService.Kick();TempData["Success"]="Đã lưu cấu hình email. Các thay đổi có hiệu lực ngay.";return RedirectToAction("Index");
  }
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Test(TestEmailInput input){
   if(!ModelState.IsValid){TempData["Error"]="Vui lòng nhập địa chỉ email nhận thử hợp lệ.";return RedirectToAction("Index");}
   if(!EmailSettingsService.Current.HasCredentials){TempData["Error"]="Hãy lưu Gmail và App Password trước khi gửi thử.";return RedirectToAction("Index");}
   try{using(var mail=new MailMessage()){mail.To.Add(input.Recipient);mail.Subject="STEP STORE - Kiểm tra cấu hình email";mail.SubjectEncoding=Encoding.UTF8;mail.BodyEncoding=Encoding.UTF8;mail.Body="Email kiểm tra cấu hình gửi thư của STEP STORE. Nếu bạn nhận được thư này, kết nối SMTP đã hoạt động.";await EmailTransport.Send(mail);}TempData["Success"]="Máy chủ SMTP đã nhận email gửi thử đến "+input.Recipient+". Hãy kiểm tra cả mục thư rác.";}catch(Exception ex)when(ex is SmtpException||ex is InvalidOperationException||ex is FormatException){TempData["Error"]="Gửi thử thất bại. Kiểm tra Gmail, App Password, máy chủ và cổng SMTP.";}return RedirectToAction("Index");
  }
 }
}
