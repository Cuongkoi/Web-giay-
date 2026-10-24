using System;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using System.Web.Mvc;
using shopgiay.Areas.Admin.Filters;
using shopgiay.Models;
using shopgiay.Services;
namespace shopgiay.Areas.Admin.Controllers
{
    [AdminAuthorize]
    public class BannersController : shopgiay.Controllers.ShopController
    {
        public async Task<ActionResult> Index() => View(await db.Banners.OrderBy(b => b.SortOrder).ThenBy(b => b.Id).ToListAsync());
        public async Task<ActionResult> Edit(int? id) { if (!id.HasValue) return View(new Banner()); var b = await db.Banners.FindAsync(id.Value); return b == null ? HttpNotFound() : View(b); }
        [HttpPost, ValidateAntiForgeryToken]
        public async Task<ActionResult> Edit(int id, [Bind(Include = "Title,Subtitle,ButtonText,LinkUrl,SortOrder,Active")] Banner input, HttpPostedFileBase? imageFile)
        {
            if (!string.IsNullOrWhiteSpace(input.LinkUrl) && (!(input.LinkUrl ?? "").StartsWith("/") || (input.LinkUrl ?? "").StartsWith("//") || (input.LinkUrl ?? "").Contains("\\"))) ModelState.AddModelError("LinkUrl", "Nhập liên kết trong website, ví dụ /?categoryId=1.");
            PreparedProductImage? prepared = null; if (imageFile != null && !string.IsNullOrEmpty(imageFile.FileName)) { try { prepared = ProductImageService.Prepare(imageFile); } catch (ArgumentException ex) { ModelState.AddModelError("", ex.Message); } }
            var banner = id == 0 ? new Banner() : await db.Banners.FindAsync(id); if (banner == null) return HttpNotFound(); if (!ModelState.IsValid) { input.Id = id; input.ImageUrl = banner.ImageUrl; return View(input); }
            var old = banner.ImageUrl; string? uploaded = null; if (prepared != null) { try { uploaded = ProductImageService.Save(prepared, Server, "Banners"); } catch (System.IO.IOException) { ModelState.AddModelError("", "Không lưu được ảnh banner."); input.Id = id; input.ImageUrl = old; return View(input); } catch (UnauthorizedAccessException) { ModelState.AddModelError("", "Không có quyền ghi ảnh banner."); input.Id = id; input.ImageUrl = old; return View(input); } }
            banner.Title = input.Title; banner.Subtitle = input.Subtitle; banner.ButtonText = input.ButtonText; banner.LinkUrl = input.LinkUrl; banner.SortOrder = input.SortOrder; banner.Active = input.Active; if (uploaded != null) banner.ImageUrl = uploaded; if (id == 0) db.Banners.Add(banner);
            try { await db.SaveChangesAsync(); } catch (DbUpdateException) { if (uploaded != null) ProductImageService.DeleteManaged(uploaded, Server); ModelState.AddModelError("", "Không lưu được banner. Vui lòng thử lại."); input.Id = id; input.ImageUrl = old; return View(input); }
            if (uploaded != null && old != null && !await db.Banners.AnyAsync(b => b.ImageUrl == old)) ProductImageService.DeleteManaged(old, Server); TempData["Success"] = "Đã lưu banner."; return RedirectToAction("Index");
        }
        [HttpPost, ValidateAntiForgeryToken] public async Task<ActionResult> Delete(int id) { var banner = await db.Banners.FindAsync(id); if (banner == null) return HttpNotFound(); var url = banner.ImageUrl; db.Banners.Remove(banner); await db.SaveChangesAsync(); if (url != null && !await db.Banners.AnyAsync(b => b.ImageUrl == url)) ProductImageService.DeleteManaged(url, Server); return RedirectToAction("Index"); }
    }
}

