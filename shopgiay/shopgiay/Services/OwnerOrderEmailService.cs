using System;
using System.Data.Entity;
using System.Linq;
using System.Net.Mail;
using System.Text;
using System.Threading.Tasks;
using shopgiay.Models;
namespace shopgiay.Services {
 public static class OwnerOrderEmailService {
  public static async Task Process(){var s=EmailSettingsService.Current;if(!s.OrderNotificationsEnabled||!s.HasCredentials||string.IsNullOrWhiteSpace(s.OwnerEmail))return;
   using(var db=new ShopDb()){
    var now=DateTime.UtcNow;
    await db.Database.ExecuteSqlCommandAsync("UPDATE dbo.Orders SET OwnerEmailStatus='Pending' WHERE OwnerEmailStatus='Sending' AND OwnerEmailRetryAt<@p0",now);
    var ids=await db.Orders.Where(o=>(o.OwnerEmailStatus=="Pending"||o.OwnerEmailStatus=="Failed")&&(!o.OwnerEmailRetryAt.HasValue||o.OwnerEmailRetryAt<=now)).OrderBy(o=>o.Id).Select(o=>o.Id).Take(20).ToListAsync();
    foreach(var id in ids){if(!EmailSettingsService.Current.OrderNotificationsEnabled)break;
     if(await db.Database.ExecuteSqlCommandAsync("UPDATE dbo.Orders SET OwnerEmailStatus='Sending',OwnerEmailRetryAt=@p0,OwnerEmailRecipient=COALESCE(OwnerEmailRecipient,@p1) WHERE Id=@p2 AND OwnerEmailStatus IN ('Pending','Failed')",DateTime.UtcNow.AddMinutes(10),s.OwnerEmail,id)!=1)continue;
     var o=await db.Orders.Include(x=>x.Items).Include(x=>x.Customer).SingleAsync(x=>x.Id==id);
     try{using(var mail=new MailMessage()){mail.To.Add(o.OwnerEmailRecipient);mail.Subject="[Đơn mới #"+o.Code+"] Qúy Cường Sneaker";mail.SubjectEncoding=Encoding.UTF8;mail.BodyEncoding=Encoding.UTF8;
      mail.Body="Có đơn hàng mới lúc "+o.CreatedAt.AddHours(7).ToString("dd/MM/yyyy HH:mm")+" (Việt Nam)\r\nMã đơn: "+o.Code+"\r\nKhách: "+o.CustomerName+"\r\nEmail: "+o.Customer?.Email+"\r\nĐiện thoại: "+o.Phone+"\r\nĐịa chỉ: "+o.Address+"\r\nGhi chú: "+o.Note+"\r\n\r\n"+string.Join("\r\n",o.Items.Select(i=>i.ProductName+" / EU "+i.Size+" x "+i.Quantity+" / "+i.Price.ToString("N0")+"đ"))+"\r\nGiảm giá: "+o.Discount.ToString("N0")+"đ\r\nPhí giao hàng: "+o.Shipping.ToString("N0")+"đ\r\nTổng: "+o.Total.ToString("N0")+"đ\r\nThanh toán: "+(o.PaymentMethod=="TRANSFER"?"Chuyển khoản ngân hàng":o.PaymentMethod)+" - "+(o.PaymentStatus=="Paid"?"Đã thanh toán":"Chưa thanh toán")+"\r\nTrạng thái đơn: "+o.Status+"\r\nMở trang quản trị để kiểm tra trạng thái mới nhất trước khi giao hàng.";
      await EmailTransport.Send(mail);}
      o.OwnerEmailStatus="Sent";o.OwnerEmailSentAt=DateTime.UtcNow;o.OwnerEmailRetryAt=null;
     }catch(Exception){o.OwnerEmailStatus="Failed";o.OwnerEmailRetryAt=DateTime.UtcNow.AddMinutes(15);}
     // Only update mail columns, leaving concurrent payment/order updates untouched.
     await db.Database.ExecuteSqlCommandAsync("UPDATE dbo.Orders SET OwnerEmailStatus=@p0,OwnerEmailSentAt=@p1,OwnerEmailRetryAt=@p2 WHERE Id=@p3 AND OwnerEmailStatus='Sending'",o.OwnerEmailStatus,(object?)o.OwnerEmailSentAt??DBNull.Value,(object?)o.OwnerEmailRetryAt??DBNull.Value,o.Id);
    }
   }
  }
 }
}