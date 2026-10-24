using System;
using System.Configuration;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Hosting;
using shopgiay.Models;
namespace shopgiay.Services {
 public static class EmailOutboxService {
  private static int running;private static Timer? timer;
  public static bool IsConfigured {get{var settings=EmailSettingsService.Current;return settings.Enabled&&settings.HasCredentials;}}
  public static void Start(){timer=new Timer(_=>Kick(),null,TimeSpan.FromSeconds(10),TimeSpan.FromMinutes(1));}
  public static void Stop(){timer?.Dispose();}
  public static void Kick(){if(Interlocked.CompareExchange(ref running,1,0)!=0)return;try{HostingEnvironment.QueueBackgroundWorkItem(async token=>{try{await Process();}catch(Exception ex){System.Diagnostics.Trace.TraceError("Voucher email worker: "+ex.GetType().Name);}finally{Interlocked.Exchange(ref running,0);}});}catch{Interlocked.Exchange(ref running,0);}}
  private static async Task Enqueue(ShopDb db){
   var now=DateTime.UtcNow;var vouchers=await db.Vouchers.Where(v=>v.Active&&v.ValidFrom<=now&&v.ValidUntil>=now).ToListAsync();
   foreach(var voucher in vouchers){
    var ids=await db.Customers.Where(c=>c.IsActive&&c.ReceiveVoucherEmails&&db.Orders.Count(o=>o.CustomerId==c.Id&&o.Status=="Hoàn thành")>=3&&!db.VoucherEmails.Any(e=>e.CustomerId==c.Id&&e.VoucherId==voucher.Id)&&!db.VoucherRedemptions.Any(r=>r.CustomerId==c.Id&&r.VoucherId==voucher.Id)).Select(c=>c.Id).ToListAsync();
    foreach(var id in ids){var item=new VoucherEmail{CustomerId=id,VoucherId=voucher.Id};db.VoucherEmails.Add(item);try{await db.SaveChangesAsync();}catch(DbUpdateException){db.Entry(item).State=EntityState.Detached;}}
   }
  }
  private static async Task Process(){
   using(var db=new ShopDb()){
    await OwnerOrderEmailService.Process();await Enqueue(db);if(!IsConfigured)return;
    var now=DateTime.UtcNow;var stale=now.AddMinutes(-10);
    await db.Database.ExecuteSqlCommandAsync("UPDATE dbo.VoucherEmails SET Status='Pending' WHERE Status='Sending' AND LockedAt<@p0",stale);
    var ids=await db.VoucherEmails.Where(e=>(e.Status=="Pending"||e.Status=="Failed")&&(!e.RetryAfter.HasValue||e.RetryAfter<=now)).OrderBy(e=>e.Id).Select(e=>e.Id).Take(20).ToListAsync();
    foreach(var id in ids){if(!IsConfigured)break;
     if(await db.Database.ExecuteSqlCommandAsync("UPDATE dbo.VoucherEmails SET Status='Sending',LockedAt=@p0,Attempts=Attempts+1 WHERE Id=@p1 AND Status IN ('Pending','Failed')",DateTime.UtcNow,id)!=1)continue;
     var email=await db.VoucherEmails.FindAsync(id);var customer=await db.Customers.FindAsync(email.CustomerId);var voucher=await db.Vouchers.FindAsync(email.VoucherId);now=DateTime.UtcNow;
     if(customer==null||voucher==null||!customer.IsActive||!customer.ReceiveVoucherEmails||!voucher.Active||voucher.ValidFrom>now||voucher.ValidUntil<now||await db.Orders.CountAsync(o=>o.CustomerId==customer.Id&&o.Status=="Hoàn thành")<3||await db.VoucherRedemptions.AnyAsync(r=>r.CustomerId==customer.Id&&r.VoucherId==voucher.Id)){email.Status="Cancelled";email.LastError="Không còn đủ điều kiện nhận thông báo.";await db.SaveChangesAsync();continue;}
     try{
      using(var message=new MailMessage()){message.To.Add(customer.Email);message.Subject="Ưu đãi dành riêng cho khách quen: giảm "+voucher.Percent+"%";message.SubjectEncoding=Encoding.UTF8;message.BodyEncoding=Encoding.UTF8;message.Body="Chào "+customer.Name+",\r\n\r\nCảm ơn bạn đã đồng hành cùng STEP STORE. Bạn đã có ít nhất 3 đơn hàng hoàn thành và trở thành khách quen.\r\n\r\nMã voucher: "+voucher.Code+"\r\nGiảm: "+voucher.Percent+"% giá trị sản phẩm\r\nĐơn tối thiểu: "+voucher.MinimumSubtotal.ToString("N0")+"đ\r\nHết hạn: "+voucher.ValidUntil.AddHours(7).ToString("dd/MM/yyyy HH:mm")+" (giờ Việt Nam)\r\n\r\nĐăng nhập đúng tài khoản này và nhập mã khi thanh toán. Mỗi tài khoản dùng mã một lần; phí vận chuyển không được giảm.\r\nBạn có thể tắt nhận email voucher trong mục Tài khoản.\r\nSTEP STORE";
       await EmailTransport.Send(message);
      }
      email.Status="Sent";email.SentAt=DateTime.UtcNow;email.LastError=null;email.RetryAfter=null;
     }catch(SmtpException){email.Status="Failed";email.LastError="SMTP gửi thất bại. Kiểm tra Gmail, App Password và kết nối mạng.";email.RetryAfter=DateTime.UtcNow.AddMinutes(15);}catch(Exception){email.Status="Failed";email.LastError="Không thể gửi email. Kiểm tra cấu hình gửi thư.";email.RetryAfter=DateTime.UtcNow.AddMinutes(15);}
     await db.SaveChangesAsync();
    }
   }
  }
 }
}


