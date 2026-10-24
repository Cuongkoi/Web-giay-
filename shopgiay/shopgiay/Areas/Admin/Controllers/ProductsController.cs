using shopgiay.ModelView;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;

using System.Web.Mvc;
using System.Web;
using System.IO;
using shopgiay.Services;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using shopgiay.Models;
namespace shopgiay.Areas.Admin.Controllers {
[shopgiay.Areas.Admin.Filters.AdminAuthorize]
public class ProductsController : shopgiay.Controllers.ShopController {
 protected override void OnActionExecuting(ActionExecutingContext context){base.OnActionExecuting(context);ViewBag.ProductBrands=new SelectList(db.Brands.AsNoTracking().OrderBy(b=>b.SortOrder).ThenBy(b=>b.Name).ToList().Select(b=>new {b.Id,Name=b.Name+(b.Active?"":" (đã ẩn)")}),"Id","Name");ViewBag.ProductCategories=new SelectList(db.Categories.AsNoTracking().OrderBy(c=>c.SortOrder).ThenBy(c=>c.Name).ToList(),"Id","Name");}

 private shopgiay.Areas.Admin.Data.AdminRepository Repository=>new shopgiay.Areas.Admin.Data.AdminRepository(db);
 public async Task<ActionResult> Index(string? q){var result=await Repository.Overview(q);ViewBag.Q=q;ViewBag.OrderCount=result.OrderCount;ViewBag.Revenue=result.Revenue;return View(result.Products);}
 public async Task<ActionResult> Edit(int? id){if(id==null)return View(new Product{Variants=Enumerable.Range(36,9).Select(s=>new Variant{Size=s}).ToList()});var p=await Repository.FindProduct(id.Value);return p==null?HttpNotFound():View(p);}
 [HttpPost, ValidateAntiForgeryToken]public async Task<ActionResult> Edit(int id,[Bind(Include="CategoryId,Name,BrandId,Color,Price,OriginalPrice,Description,Featured,Active,Variants")]Product input,IEnumerable<HttpPostedFileBase>? imageFiles,int[]? removeImageIds,HttpPostedFileBase? avatarFile,bool removeAvatar=false){
 var selectedBrand=input.BrandId.HasValue?await db.Brands.FindAsync(input.BrandId.Value):null;
 ModelState.Remove("Brand");ModelState.Remove("BrandInfo");input.Brand=selectedBrand?.Name??"";
 if(selectedBrand==null)ModelState.AddModelError("BrandId","Vui lòng chọn thương hiệu hợp lệ.");
 ModelState.Remove("Variants.Product");for(int i=0;i<input.Variants.Count;i++)ModelState.Remove($"Variants[{i}].Product");
 if(input.Variants.Count==0||input.Variants.Count>21||input.Variants.Select(v=>v.Size).Distinct().Count()!=input.Variants.Count)ModelState.AddModelError("","Danh sách size không hợp lệ.");
 if(input.OriginalPrice.HasValue&&input.OriginalPrice<input.Price)ModelState.AddModelError("OriginalPrice","Giá gốc phải lớn hơn hoặc bằng giá bán.");
 if(input.CategoryId.HasValue&&!await db.Categories.AnyAsync(c=>c.Id==input.CategoryId.Value))ModelState.AddModelError("CategoryId","Danh mục không tồn tại.");

 var current=id==0?null:await Repository.FindProduct(id);if(id!=0&&current==null)return HttpNotFound();
 ModelState.Remove("Sku");input.Sku=current?.Sku??("SG-"+Guid.NewGuid().ToString("N").ToUpperInvariant());
 input.Color=(input.Color??"").Trim();if(!ProductColors.All.Contains(input.Color))ModelState.AddModelError("Color","Vui lòng chọn màu sắc của giày.");
 var existing=current?.Images.ToList()??new List<ProductImage>();var removed=new HashSet<int>(removeImageIds??new int[0]);
 var previousAvatar=existing.SingleOrDefault(i=>i.IsPrimary);var gallery=existing.Where(i=>!i.IsPrimary).ToList();
 if(removed.Except(gallery.Select(i=>i.Id)).Any())ModelState.AddModelError("","Ảnh thông tin cần xóa không thuộc sản phẩm này.");
 var kept=gallery.Where(i=>!removed.Contains(i.Id)).OrderBy(i=>i.SortOrder).ThenBy(i=>i.Id).ToList();
 var uploads=(imageFiles??Enumerable.Empty<HttpPostedFileBase>()).Where(f=>f!=null&&!string.IsNullOrEmpty(f.FileName)).ToList();
 if(kept.Count+uploads.Count>8)ModelState.AddModelError("","Chỉ được có tối đa 8 ảnh thông tin sản phẩm (không tính ảnh đại diện).");
 var prepared=new List<PreparedProductImage>();PreparedProductImage? preparedAvatar=null;
 if(ModelState.IsValid){
  foreach(var file in uploads){try{prepared.Add(ProductImageService.Prepare(file));}catch(ArgumentException ex){ModelState.AddModelError("",ex.Message);}}
  if(avatarFile!=null&&!string.IsNullOrEmpty(avatarFile.FileName)){try{preparedAvatar=ProductImageService.Prepare(avatarFile);}catch(ArgumentException ex){ModelState.AddModelError("","Ảnh đại diện: "+ex.Message);}}
 }
 if(previousAvatar!=null&&(removeAvatar||preparedAvatar!=null))removed.Add(previousAvatar.Id);
 if(!ModelState.IsValid)return await InvalidEdit(input,id);
 var p=current??new Product();if(id==0)db.Products.Add(p);
 p.Color=input.Color;p.BrandId=input.BrandId;p.CategoryId=input.CategoryId;p.Name=input.Name;p.Brand=input.Brand;p.Sku=input.Sku;p.Price=input.Price;p.OriginalPrice=input.OriginalPrice;p.Description=input.Description;p.Featured=input.Featured;p.Active=input.Active;
 foreach(var v in input.Variants){var existingVariant=p.Variants.SingleOrDefault(x=>x.Size==v.Size);if(existingVariant==null)p.Variants.Add(new Variant{Size=v.Size,Stock=v.Stock});else{existingVariant.Stock=v.Stock;existingVariant.Revision++;}}
 var savedUrls=new List<string>();var newImages=new List<ProductImage>();
 ProductImage? primary=removeAvatar?null:previousAvatar;
 try{
  if(preparedAvatar!=null){var url=ProductImageService.Save(preparedAvatar,Server);savedUrls.Add(url);primary=new ProductImage{Url=url,SortOrder=0};p.Images.Add(primary);}
  foreach(var image in prepared){var url=ProductImageService.Save(image,Server);savedUrls.Add(url);var entry=new ProductImage{Url=url,SortOrder=kept.Count+newImages.Count+1};newImages.Add(entry);p.Images.Add(entry);}
 }catch(Exception ex)when(ex is IOException||ex is UnauthorizedAccessException){foreach(var url in savedUrls)ProductImageService.DeleteManaged(url,Server);ModelState.AddModelError("","Không lưu được ảnh. Kiểm tra quyền ghi thư mục Images/Products.");return await InvalidEdit(input,id);}
 foreach(var image in existing)image.IsPrimary=false;
 foreach(var image in existing.Where(i=>removed.Contains(i.Id)))db.ProductImages.Remove(image);
 var all=kept.Concat(newImages).ToList();for(int i=0;i<all.Count;i++){all[i].SortOrder=i+1;all[i].IsPrimary=false;}
 if(primary!=null){primary.IsPrimary=false;primary.SortOrder=0;}p.ImageUrl=primary?.Url;p.ImagesRevision++;
 using(var tx=db.Database.BeginTransaction()){
  try{
   // Clear the previous primary before enabling another one (filtered unique index).
   await db.SaveChangesAsync();if(primary!=null){primary.IsPrimary=true;await db.SaveChangesAsync();}tx.Commit();
  }catch(DbUpdateException){tx.Rollback();foreach(var url in savedUrls)ProductImageService.DeleteManaged(url,Server);ModelState.AddModelError("","Dữ liệu vừa thay đổi. Hãy tải lại và thử lại.");return await InvalidEdit(input,id);}
 }
 foreach(var image in existing.Where(i=>removed.Contains(i.Id)))if(!await db.ProductImages.AnyAsync(i=>i.Url==image.Url))ProductImageService.DeleteManaged(image.Url,Server);
 TempData["Success"]="Đã lưu sản phẩm và ảnh.";return RedirectToAction("Index");
 }
 private async Task<ActionResult> InvalidEdit(Product input,int id){input.Id=id;input.Images=id==0?new List<ProductImage>():await db.ProductImages.AsNoTracking().Where(i=>i.ProductId==id).OrderBy(i=>i.SortOrder).ToListAsync();return View("Edit",input);}
 [HttpPost, ValidateAntiForgeryToken]public async Task<ActionResult> Delete(int id){var p=await Repository.FindProduct(id);if(p==null)return HttpNotFound();var imageUrls=p.Images.Select(i=>i.Url).ToList();db.Products.Remove(p);try{await db.SaveChangesAsync();foreach(var url in imageUrls)if(!await db.ProductImages.AnyAsync(i=>i.Url==url))ProductImageService.DeleteManaged(url,Server);TempData["Success"]="Đã xóa sản phẩm. Lịch sử đơn hàng được giữ lại.";}catch(DbUpdateConcurrencyException){TempData["Error"]="Sản phẩm vừa thay đổi. Vui lòng thử lại.";}return RedirectToAction("Index");}
 [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> ConfirmTransfer(int id){var o=await db.Orders.FindAsync(id);if(o==null)return HttpNotFound();if(o.PaymentMethod!="TRANSFER"||o.Status=="Đã hủy"){TempData["Error"]="Không thể xác nhận chuyển khoản cho đơn này.";return RedirectToAction("Orders");}if(o.PaymentStatus=="Paid"){TempData["Success"]="Đơn đã được xác nhận thanh toán trước đó.";return RedirectToAction("Orders");}o.PaymentStatus="Paid";o.PaidAt=DateTime.UtcNow;try{await db.SaveChangesAsync();TempData["Success"]="Đã xác nhận nhận tiền chuyển khoản.";}catch(DbUpdateConcurrencyException){TempData["Error"]="Đơn vừa thay đổi. Vui lòng tải lại.";}return RedirectToAction("Orders");}
  public async Task<ActionResult> Orders()=>View(await Repository.Orders());
 [HttpPost, ValidateAntiForgeryToken]public async Task<ActionResult> Status(int id,string status){var o=await db.Orders.FindAsync(id);if(o==null)return HttpNotFound();var allowed=o.Status switch{"Chờ xác nhận"=>new[]{"Đã xác nhận","Đã hủy"},"Đã xác nhận"=>new[]{"Đang giao","Đã hủy"},"Đang giao"=>new[]{"Hoàn thành"},_=>Array.Empty<string>()};if(!allowed.Contains(status)){TempData["Error"]="Không thể chuyển sang trạng thái này.";return RedirectToAction("Orders");}
 if((o.PaymentMethod=="VNPAY"||o.PaymentMethod=="TRANSFER")&&o.PaymentStatus!="Paid"&&status!="Đã hủy"){TempData["Error"]="Chưa xác nhận nhận tiền, không thể giao hoặc hoàn thành đơn.";return RedirectToAction("Orders");}
  if((o.PaymentMethod=="VNPAY"||o.PaymentMethod=="TRANSFER")&&(o.PaymentStatus=="Paid"||o.PaymentStatus=="Review")&&status=="Đã hủy"){TempData["Error"]="Đơn đã nhận tiền. Cần liên hệ khách hàng để xử lý hoàn tiền; website chưa hỗ trợ hoàn tiền tự động.";return RedirectToAction("Orders");}
  if(o.PaymentMethod=="VNPAY"&&o.PaymentStatus=="Unpaid"&&status=="Đã hủy"&&o.CreatedAt>DateTime.UtcNow.AddMinutes(-20)){TempData["Error"]="Giao dịch VNPay đang trong thời gian thanh toán. Hãy chờ hết thời hạn trước khi hủy.";return RedirectToAction("Orders");}
  using var tx=db.Database.BeginTransaction();if(status=="Đã hủy"){await db.Entry(o).Collection(x=>x.Items).LoadAsync();foreach(var item in o.Items){var v=await db.Variants.FindAsync(item.VariantId);if(v!=null){v.Stock+=item.Quantity;v.Revision++;}}}if(status=="Đã hủy"){var redemptions=await db.VoucherRedemptions.Where(r=>r.OrderId==o.Id).ToListAsync();db.VoucherRedemptions.RemoveRange(redemptions);}o.Status=status;if(status=="Hoàn thành"&&o.PaymentMethod=="COD"){o.PaymentStatus="Paid";o.PaidAt=DateTime.UtcNow;}try{await db.SaveChangesAsync();tx.Commit();if(status=="Hoàn thành")EmailOutboxService.Kick();}catch(DbUpdateConcurrencyException){tx.Rollback();TempData["Error"]="Dữ liệu vừa thay đổi. Vui lòng thử lại.";}return RedirectToAction("Orders");}
}

}






