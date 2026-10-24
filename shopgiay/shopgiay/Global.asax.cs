using System;
using System.Data.Entity;
using System.Globalization;
using System.Linq;
using System.Security.Principal;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using System.Web.Security;
using shopgiay.Models;
using shopgiay.Services;
namespace shopgiay {
 public class MvcApplication:HttpApplication {
  protected void Application_Start(){Database.SetInitializer<ShopDb>(null);AreaRegistration.RegisterAllAreas();FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);BundleConfig.RegisterBundles(System.Web.Optimization.BundleTable.Bundles);RouteConfig.RegisterRoutes(RouteTable.Routes);EmailOutboxService.Start();}
  protected void Application_End(){EmailOutboxService.Stop();}
  protected void Application_BeginRequest(){System.Threading.Thread.CurrentThread.CurrentCulture=CultureInfo.GetCultureInfo("vi-VN");System.Threading.Thread.CurrentThread.CurrentUICulture=CultureInfo.GetCultureInfo("vi-VN");}
  protected void Application_Error(){var error=Server.GetLastError();if(error!=null&&error.GetBaseException() is HttpAntiForgeryException){Server.ClearError();Response.StatusCode=400;Response.TrySkipIisCustomErrors=true;Response.Write("Invalid request verification token.");}}
  protected void Application_PostAuthenticateRequest(){var principal=SeparateAuthService.Authenticate(Context);Context.User=principal;System.Threading.Thread.CurrentPrincipal=principal;}
 }
}

