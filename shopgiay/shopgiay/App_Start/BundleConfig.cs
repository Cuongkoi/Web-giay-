using System.Web.Optimization;
namespace shopgiay {
 public static class BundleConfig {
  public static void RegisterBundles(BundleCollection bundles){bundles.Add(new StyleBundle("~/bundles/store-css").Include("~/Content/site.css"));bundles.Add(new ScriptBundle("~/bundles/store-js").Include("~/Scripts/site.js"));BundleTable.EnableOptimizations=false;}
 }
}
