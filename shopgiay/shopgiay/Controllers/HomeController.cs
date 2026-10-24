using shopgiay.ModelView;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Web.Mvc;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using shopgiay.Models;
namespace shopgiay.Controllers {
public class HomeController : shopgiay.Controllers.ShopController {
 public async Task<ActionResult> Index(string? q,string? brand,string? sort,bool sale=false,int? categoryId=null,int? brandId=null){
 var query=db.Products.AsNoTracking().Include(p=>p.Variants).Where(p=>p.Active);
 Brand? selectedBrand=null;
 if(brandId.HasValue){selectedBrand=await db.Brands.SingleOrDefaultAsync(b=>b.Id==brandId.Value&&b.Active);if(selectedBrand==null)return HttpNotFound();query=query.Where(p=>p.BrandId==brandId);}
 Category? selectedCategory=null;
 if(categoryId.HasValue){selectedCategory=await db.Categories.SingleOrDefaultAsync(c=>c.Id==categoryId.Value&&c.Active);if(selectedCategory==null)return HttpNotFound();query=query.Where(p=>p.CategoryId==categoryId);}
 if(!string.IsNullOrWhiteSpace(q))query=query.Where(p=>p.Name.Contains(q)||p.Sku.Contains(q));
 if(selectedBrand==null&&!string.IsNullOrEmpty(brand))query=query.Where(p=>p.Brand==brand);
 if(sale)query=query.Where(p=>p.OriginalPrice>p.Price);
 query=sort switch{"price-asc"=>query.OrderBy(p=>p.Price),"price-desc"=>query.OrderByDescending(p=>p.Price),_=>query.OrderByDescending(p=>p.Featured).ThenBy(p=>p.Id)};
 ViewBag.HomeBanners=await db.Banners.AsNoTracking().Where(b=>b.Active).OrderBy(b=>b.SortOrder).ThenBy(b=>b.Id).ToListAsync();
 return View(new Catalog{Products=await query.ToListAsync(),Q=q,Brand=selectedBrand?.Name??brand,BrandId=brandId,Sort=sort,Sale=sale,CategoryId=categoryId,CategoryName=selectedCategory?.Name});
 }
 public async Task<ActionResult> Product(int id){var p=await db.Products.Include(p=>p.Images).Include(p=>p.Variants).Include(p=>p.Category).SingleOrDefaultAsync(p=>p.Id==id&&p.Active);return p==null?HttpNotFound():View(p);}
 public ActionResult Error()=>View();
}

}
