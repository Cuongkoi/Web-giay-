using System.Web.Mvc;
using System.Web.Routing;
namespace shopgiay {
 public static class RouteConfig {
  public static void RegisterRoutes(RouteCollection routes){
   routes.IgnoreRoute("{resource}.axd/{*pathInfo}");
   var route=routes.MapRoute("Default","{controller}/{action}/{id}",new{controller="Home",action="Index",id=UrlParameter.Optional},new[]{"shopgiay.Controllers"});route.DataTokens["UseNamespaceFallback"]=false;
  }
 }
}
