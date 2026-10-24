using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using shopgiay.Models;
using shopgiay.ModelView;
namespace shopgiay.Areas.Admin.Data {
 public sealed class AdminRepository {
  private readonly ShopDb db;
  public AdminRepository(ShopDb context){db=context;}
  public async Task<AdminOverview> Overview(string? search){
   var query=db.Products.AsNoTracking().Include(p=>p.Variants).AsQueryable();
   if(!string.IsNullOrWhiteSpace(search))query=query.Where(p=>p.Name.Contains(search)||p.Sku.Contains(search));
   return new AdminOverview {Products=await query.OrderByDescending(p=>p.Id).ToListAsync(),OrderCount=await db.Orders.CountAsync(),Revenue=await db.Orders.Where(o=>o.Status=="Hoàn thành").Select(o=>(decimal?)o.Total).SumAsync()??0};
  }
  public Task<Product?> FindProduct(int id)=>db.Products.Include(p=>p.Images).Include(p=>p.Variants).SingleOrDefaultAsync(p=>p.Id==id)!;
  public Task<List<Order>> Orders()=>db.Orders.Include(o=>o.Items).Include(o=>o.Customer).OrderByDescending(o=>o.Id).ToListAsync();
 }
}

