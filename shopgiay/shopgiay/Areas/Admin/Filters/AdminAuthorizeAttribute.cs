using System.Web;
using System.Web.Mvc;
using System.Web.Security;
namespace shopgiay.Areas.Admin.Filters {
 public sealed class AdminAuthorizeAttribute:AuthorizeAttribute {
  protected override bool AuthorizeCore(HttpContextBase context)=>context.User.Identity.IsAuthenticated&&context.User.IsInRole("Admin");
  protected override void HandleUnauthorizedRequest(AuthorizationContext context){
   var request=context.HttpContext.Request;
   context.Result=new RedirectResult("/Admin/Account/Login?returnUrl="+HttpUtility.UrlEncode(request.RawUrl));
  }
 }
}
