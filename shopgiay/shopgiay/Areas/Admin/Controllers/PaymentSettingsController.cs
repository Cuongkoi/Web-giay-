using System;
using System.IO;
using System.Web;
using System.Web.Mvc;
using shopgiay.Areas.Admin.Filters;
using shopgiay.ModelView;
using shopgiay.Services;
namespace shopgiay.Areas.Admin.Controllers {
 [AdminAuthorize]public class PaymentSettingsController:shopgiay.Controllers.ShopController {
  public ActionResult Index(){var s=BankTransferSettingsService.Current;return View(new BankTransferSettingsInput{Enabled=s.Enabled,BankName=s.BankName,AccountNumber=s.AccountNumber,AccountHolder=s.AccountHolder,QrImageUrl=s.QrImageUrl});}
  [HttpPost,ValidateAntiForgeryToken]public ActionResult Index([Bind(Include="Enabled,BankName,AccountNumber,AccountHolder")]BankTransferSettingsInput input,HttpPostedFileBase? qrFile,bool removeQr=false){
   PreparedProductImage? prepared=null;
   if(qrFile!=null&&qrFile.ContentLength>0){try{prepared=ProductImageService.Prepare(qrFile);}catch(ArgumentException ex){ModelState.AddModelError("qrFile",ex.Message);}}
   var current=BankTransferSettingsService.Current;
   if(input.Enabled&&prepared==null&&(removeQr||string.IsNullOrEmpty(current.QrImageUrl)))ModelState.AddModelError("qrFile","Vui lòng tải ảnh QR trước khi bật chuyển khoản.");
   string? saved=null;
   if(ModelState.IsValid){try{if(prepared!=null)saved=ProductImageService.Save(prepared,Server,"Payments");var previous=BankTransferSettingsService.Save(input,saved,removeQr);ProductImageService.DeleteManaged(previous,Server);TempData["Success"]="Đã lưu cấu hình chuyển khoản và ảnh QR.";return RedirectToAction("Index");}catch(Exception ex)when(ex is IOException||ex is UnauthorizedAccessException||ex is ArgumentException){if(saved!=null)ProductImageService.DeleteManaged(saved,Server);ModelState.AddModelError("","Không lưu được cấu hình hoặc ảnh QR. Kiểm tra dữ liệu và quyền ghi thư mục.");}}
   input.QrImageUrl=BankTransferSettingsService.Current.QrImageUrl;return View(input);
  }
 }
}