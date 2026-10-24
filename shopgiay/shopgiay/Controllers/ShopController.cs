using System.Web.Mvc;
using System.Linq;
using shopgiay.Models;
namespace shopgiay.Controllers {
 public abstract class ShopController:Controller {
  protected readonly ShopDb db=new ShopDb();
  protected Customer? CurrentCustomer=>HttpContext.Items["Customer"] as Customer;
  protected override void OnActionExecuting(ActionExecutingContext context){ViewBag.FilterBrands=db.Brands.AsNoTracking().Where(b=>b.Active).OrderBy(b=>b.SortOrder).ThenBy(b=>b.Name).ToList();ViewBag.MenuCategories=db.Categories.AsNoTracking().Where(c=>c.Active).OrderBy(c=>c.SortOrder).ThenBy(c=>c.Name).ToList();base.OnActionExecuting(context);}
  protected override void Dispose(bool disposing){if(disposing)db.Dispose();base.Dispose(disposing);}
 }
}

