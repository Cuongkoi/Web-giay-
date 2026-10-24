using System;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Mvc;
using shopgiay.Areas.Admin.Filters;
using shopgiay.ModelView;
namespace shopgiay.Areas.Admin.Controllers {
 [AdminAuthorize]public class UsersController:shopgiay.Controllers.ShopController {
  public async Task<ActionResult> Index(string? q){var customers=db.Customers.AsNoTracking().AsQueryable();if(!string.IsNullOrWhiteSpace(q))customers=customers.Where(c=>c.Name.Contains(q)||c.Email.Contains(q));ViewBag.Q=q;return View(await customers.OrderByDescending(c=>c.Id).Select(c=>new CustomerRow{Customer=c,CompletedOrders=db.Orders.Count(o=>o.CustomerId==c.Id&&o.Status=="Hoàn thành")}).ToListAsync());}
  public async Task<ActionResult> Details(int id){var customer=await db.Customers.AsNoTracking().SingleOrDefaultAsync(c=>c.Id==id);if(customer==null)return HttpNotFound();var orders=await db.Orders.Include(o=>o.Items).Where(o=>o.CustomerId==id).OrderByDescending(o=>o.Id).ToListAsync();return View(new CustomerAccountView{Customer=customer,Orders=orders,CompletedOrders=orders.Count(o=>o.Status=="Hoàn thành")});}
  [HttpPost,ValidateAntiForgeryToken]public async Task<ActionResult> SetActive(int id,bool active){var customer=await db.Customers.FindAsync(id);if(customer==null)return HttpNotFound();customer.IsActive=active;customer.SecurityStamp=Guid.NewGuid().ToString("N");await db.SaveChangesAsync();TempData["Success"]=active?"Đã mở khóa tài khoản.":"Đã khóa tài khoản và thu hồi các phiên đăng nhập.";return RedirectToAction("Index");}
 }
}
