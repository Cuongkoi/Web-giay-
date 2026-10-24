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
 public class CategoriesController:shopgiay.Controllers.ShopController {
  public async Task<ActionResult> Index()=>View(await new CategoryRepository(db).List());
  public async Task<ActionResult> Edit(int? id){if(!id.HasValue)return View(new Category());var c=await db.Categories.FindAsync(id.Value);return c==null?HttpNotFound():View(c);}
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Edit(int id,[Bind(Include="Name,SortOrder,Active")]Category input){
   input.Name=(input.Name??"").Trim();if(input.Name.Length==0)ModelState.AddModelError("Name","Vui lòng nhập tên danh mục.");
   if(await db.Categories.AnyAsync(c=>c.Name==input.Name&&c.Id!=id))ModelState.AddModelError("Name","Tên danh mục đã tồn tại.");
   if(!ModelState.IsValid){input.Id=id;return View(input);}
   Category c;if(id==0){c=new Category();db.Categories.Add(c);}else{c=(await db.Categories.FindAsync(id))!;if(c==null)return HttpNotFound();}
   c.Name=input.Name;c.SortOrder=input.SortOrder;c.Active=input.Active;
   try{await db.SaveChangesAsync();}catch(DbUpdateException){ModelState.AddModelError("","Không thể lưu. Tên danh mục có thể vừa được sử dụng.");input.Id=id;return View(input);}
   TempData["Success"]="Đã lưu danh mục.";return RedirectToAction("Index");
  }
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> Delete(int id){
   var category=await db.Categories.FindAsync(id);if(category==null)return HttpNotFound();
   if(await db.Products.AnyAsync(p=>p.CategoryId==id)){TempData["Error"]="Danh mục đang có sản phẩm. Hãy chuyển sản phẩm sang danh mục khác hoặc ẩn danh mục này.";return RedirectToAction("Index");}
   db.Categories.Remove(category);try{await db.SaveChangesAsync();TempData["Success"]="Đã xóa danh mục.";}catch(DbUpdateException){TempData["Error"]="Danh mục vừa thay đổi hoặc đang có sản phẩm. Vui lòng tải lại.";}return RedirectToAction("Index");
  }
 }
}
