using System.Web;
using System.Web.Mvc;
namespace shopgiay.Filters {
 public sealed class CustomerAuthorizeAttribute:AuthorizeAttribute {
  protected override bool AuthorizeCore(HttpContextBase context)=>context.User.Identity.IsAuthenticated&&context.User.IsInRole("Customer")&&context.Items["Customer"]!=null;
  protected override void HandleUnauthorizedRequest(AuthorizationContext context){context.Result=new RedirectResult("/Account/Login?returnUrl="+HttpUtility.UrlEncode(context.HttpContext.Request.RawUrl));}
 }
}
