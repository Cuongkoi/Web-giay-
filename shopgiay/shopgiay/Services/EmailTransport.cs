using System;
using System.Net;
using System.Net.Mail;
using System.Text;
using System.Threading.Tasks;
namespace shopgiay.Services {
 public static class EmailTransport {
  public static async Task Send(MailMessage message){var settings=EmailSettingsService.Current;if(!settings.HasCredentials)throw new InvalidOperationException("Chưa cấu hình Gmail hoặc App Password.");message.From=new MailAddress(string.IsNullOrWhiteSpace(settings.FromAddress)?settings.User:settings.FromAddress,settings.SenderName,Encoding.UTF8);
   using(var smtp=new SmtpClient(settings.Host,settings.Port)){smtp.EnableSsl=true;smtp.UseDefaultCredentials=false;smtp.Credentials=new NetworkCredential(settings.User,settings.Password);smtp.Timeout=30000;var send=smtp.SendMailAsync(message);if(await Task.WhenAny(send,Task.Delay(30000))!=send){smtp.SendAsyncCancel();try{await send;}catch{}throw new SmtpException("SMTP timeout");}await send;}
  }
 }
}
