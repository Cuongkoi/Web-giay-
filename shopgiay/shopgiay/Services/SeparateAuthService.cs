using System;
using System.Data.Entity;
using System.Linq;
using System.Security.Principal;
using System.Web;
using System.Web.Security;
using shopgiay.Models;
namespace shopgiay.Services {
 public static class SeparateAuthService {
  public const string AdminCookie="ShopGiay.AdminAuth";
  public const string CustomerCookie="ShopGiay.CustomerAuth";
  private static string CookiePath(HttpRequestBase request)=>string.IsNullOrEmpty(request.ApplicationPath)||request.ApplicationPath=="/"?"/":request.ApplicationPath.TrimEnd('/')+"/";
  private static void Write(string name,string email,string data,TimeSpan lifetime,HttpRequestBase request,HttpResponseBase response){
   var ticket=new FormsAuthenticationTicket(1,email,DateTime.Now,DateTime.Now.Add(lifetime),false,data);
   response.Cookies.Add(new HttpCookie(name,FormsAuthentication.Encrypt(ticket)){Path=CookiePath(request),HttpOnly=true,Secure=request.IsSecureConnection,SameSite=SameSiteMode.Lax});ClearLegacy(request,response);
  }
  public static void SignInAdmin(AdminUser user,HttpRequestBase request,HttpResponseBase response)=>Write(AdminCookie,user.Email,"Admin|"+user.SecurityStamp,TimeSpan.FromHours(4),request,response);
  public static void SignInCustomer(Customer user,HttpRequestBase request,HttpResponseBase response)=>Write(CustomerCookie,user.Email,"Customer|"+user.Id+"|"+user.SecurityStamp,TimeSpan.FromDays(7),request,response);
  public static void SignOutAdmin(HttpRequestBase request,HttpResponseBase response){Expire(AdminCookie,CookiePath(request),request,response);ClearLegacy(request,response);}
  public static void SignOutCustomer(HttpRequestBase request,HttpResponseBase response){Expire(CustomerCookie,CookiePath(request),request,response);ClearLegacy(request,response);}
  private static void Expire(string name,string path,HttpRequestBase request,HttpResponseBase response)=>response.Cookies.Add(new HttpCookie(name,""){Path=path,Expires=DateTime.UtcNow.AddDays(-1),HttpOnly=true,Secure=request.IsSecureConnection,SameSite=SameSiteMode.Lax});
  private static void ClearLegacy(HttpRequestBase request,HttpResponseBase response){if(request.Cookies[FormsAuthentication.FormsCookieName]!=null)Expire(FormsAuthentication.FormsCookieName,FormsAuthentication.FormsCookiePath,request,response);}
  public static IPrincipal Authenticate(HttpContext context){
   var request=new HttpRequestWrapper(context.Request);var response=new HttpResponseWrapper(context.Response);ClearLegacy(request,response);
   // Select one authentication context by URL; never inherit the other role or legacy Forms cookie.
   var path=request.AppRelativeCurrentExecutionFilePath;
   bool adminRequest=path.Equals("~/Admin",StringComparison.OrdinalIgnoreCase)||path.StartsWith("~/Admin/",StringComparison.OrdinalIgnoreCase);
   var cookieName=adminRequest?AdminCookie:CustomerCookie;var cookie=request.Cookies[cookieName];
   if(cookie!=null){try{var ticket=FormsAuthentication.Decrypt(cookie.Value);if(ticket!=null&&!ticket.Expired){var parts=ticket.UserData.Split('|');using(var db=new ShopDb()){
    if(adminRequest&&parts.Length==2&&parts[0]=="Admin"){var user=db.Admins.AsNoTracking().SingleOrDefault(a=>a.Email==ticket.Name);if(user!=null&&user.SecurityStamp==parts[1])return new GenericPrincipal(new FormsIdentity(ticket),new[]{"Admin"});}
    int id;if(!adminRequest&&parts.Length==3&&parts[0]=="Customer"&&int.TryParse(parts[1],out id)){var user=db.Customers.AsNoTracking().SingleOrDefault(c=>c.Id==id&&c.IsActive);if(user!=null&&user.SecurityStamp==parts[2]){context.Items["Customer"]=user;return new GenericPrincipal(new FormsIdentity(ticket),new[]{"Customer"});}}
   }}}catch(ArgumentException){}catch(System.Security.Cryptography.CryptographicException){}Expire(cookieName,CookiePath(request),request,response);}
   return new GenericPrincipal(new GenericIdentity(""),new string[0]);
  }
 }
}

