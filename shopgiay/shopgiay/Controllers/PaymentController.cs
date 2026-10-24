using System;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Mvc;
using shopgiay.Models;
using shopgiay.Services;
namespace shopgiay.Controllers {
 public class PaymentController:Controller {
  // IPN is server-to-server: no login/CSRF requirement. Signature, merchant and amount authorize it.
  [HttpGet]public async Task<ActionResult> Ipn(){
   var q=Request.QueryString;var s=PaymentSettingsService.Current;
   if(!VnPayService.Verify(q,s))return Reply("97","Invalid signature");
   try{using(var db=new ShopDb())using(var tx=db.Database.BeginTransaction()){
    var code=q["vnp_TxnRef"]??"";
    var order=await db.Orders.SqlQuery("SELECT * FROM dbo.Orders WITH (UPDLOCK,HOLDLOCK) WHERE Code=@p0",code).SingleOrDefaultAsync();
    if(order==null)return Reply("01","Order not found");
    if(!VnPayService.Matches(order,q))return Reply("04","Invalid amount or merchant");
    if(order.PaymentStatus!="Unpaid")return Reply("02","Order already confirmed");
    var response=q["vnp_ResponseCode"]??"";var state=q["vnp_TransactionStatus"]??"";
    if(response.Length!=2||state.Length!=2||response.Concat(state).Any(c=>c<'0'||c>'9'))return Reply("99","Invalid payment status");
    var success=response=="00"&&state=="00";
    var transaction=q["vnp_TransactionNo"]??"";
    if(success&&(transaction.Length==0||transaction.Length>100||transaction.Any(c=>c<'0'||c>'9')))return Reply("99","Invalid transaction");
    order.PaymentStatus=success?"Paid":(response=="07"||state=="07"||state=="04"?"Review":"Failed");order.PaymentTransactionNo=transaction.Length<=100?transaction:null;order.PaidAt=success?(DateTime?)DateTime.UtcNow:null;
    await db.SaveChangesAsync();tx.Commit();return Reply("00","Confirm success");
   }}catch(Exception ex){System.Diagnostics.Trace.TraceError("VNPay IPN: "+ex.GetType().Name);return Reply("99","Processing error");}
  }
  ActionResult Reply(string code,string message)=>Json(new{RspCode=code,Message=message},JsonRequestBehavior.AllowGet);
  [HttpGet]public async Task<ActionResult> Return(){var q=Request.QueryString;var settings=PaymentSettingsService.Current;
   if(!VnPayService.Verify(q,settings))return new HttpStatusCodeResult(400,"Invalid payment signature");
   using(var db=new ShopDb()){var code=q["vnp_TxnRef"]??"";var o=await db.Orders.SingleOrDefaultAsync(x=>x.Code==code);if(o==null||!VnPayService.Matches(o,q))return new HttpStatusCodeResult(400,"Invalid payment result");
    // Browser return only displays information. Only IPN changes payment state.
    TempData["Success"]=o.PaymentStatus=="Paid"?"Đã xác nhận thanh toán VNPay.":"Đã quay lại từ VNPay. Kiểm tra trạng thái thanh toán bên dưới; hệ thống đang chờ đối soát từ VNPay.";
    return RedirectToAction("Complete","Cart",new{code=o.Code});}
  }
 }
}