using System.Linq;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Threading.Tasks;
using System.Web.Mvc;
using shopgiay.Models;
using shopgiay.Areas.Admin.Filters;
using shopgiay.Areas.Admin.Data;
namespace shopgiay.Areas.Admin.Controllers {
 [AdminAuthorize]
 public class BrandsController:shopgiay.Controllers.ShopController {
  public async Task<ActionResult> Index()=>View(await new BrandRepository(db).List());
  public async Task<ActionResult> Edit(int? id){if(!id.HasValue)return View(new Brand());var b=await db.Brands.FindAsync(id.Value);return b==null?HttpNotFound():View(b);}
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Edit(int id,[Bind(Include="Name,SortOrder,Active")]Brand input){
   input.Name=(input.Name??"").Trim();if(input.Name.Length==0)ModelState.AddModelError("Name","Vui lòng nhập tên thương hiệu.");
   if(await db.Brands.AnyAsync(b=>b.Name==input.Name&&b.Id!=id))ModelState.AddModelError("Name","Tên thương hiệu đã tồn tại.");
   if(!ModelState.IsValid){input.Id=id;return View(input);}
   Brand brand;if(id==0){brand=new Brand();db.Brands.Add(brand);}else{brand=(await db.Brands.FindAsync(id))!;if(brand==null)return HttpNotFound();}
   brand.Name=input.Name;brand.SortOrder=input.SortOrder;brand.Active=input.Active;
   foreach(var product in await db.Products.Where(p=>p.BrandId==id&&id!=0).ToListAsync())product.Brand=input.Name;
   try{await db.SaveChangesAsync();}catch(DbUpdateException){ModelState.AddModelError("","Không thể lưu. Tên thương hiệu có thể vừa được sử dụng.");input.Id=id;return View(input);}
   TempData["Success"]="Đã lưu thương hiệu.";return RedirectToAction("Index");
  }
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Delete(int id){
   var brand=await db.Brands.FindAsync(id);if(brand==null)return HttpNotFound();
   if(await db.Products.AnyAsync(p=>p.BrandId==id)){TempData["Error"]="Thương hiệu đang có sản phẩm. Hãy chuyển sản phẩm sang thương hiệu khác hoặc ẩn thương hiệu này.";return RedirectToAction("Index");}
   db.Brands.Remove(brand);try{await db.SaveChangesAsync();TempData["Success"]="Đã xóa thương hiệu.";}catch(DbUpdateException){TempData["Error"]="Thương hiệu vừa thay đổi hoặc đang có sản phẩm. Vui lòng tải lại.";}return RedirectToAction("Index");
  }
 }
}
