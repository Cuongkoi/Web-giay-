using System;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using shopgiay.Models;
using shopgiay.ModelView;
namespace shopgiay.Areas.Admin.Data {
 public class DashboardRepository {
  private readonly ShopDb db;public DashboardRepository(ShopDb context){db=context;}
  public async Task<DashboardViewModel> Load(string range){
   var valid=new[]{"7","30","90","all"};if(!valid.Contains(range))range="30";
   var query=db.Orders.AsNoTracking().Where(o=>o.Status=="Hoàn thành");if(range!="all"){var from=DateTime.UtcNow.AddHours(7).Date.AddDays(1-int.Parse(range)).AddHours(-7);query=query.Where(o=>o.CreatedAt>=from);}
   var orders=await query.Select(o=>new {o.Id,o.CustomerId,o.Phone,o.Total,Name=o.Customer!=null?o.Customer.Name:o.CustomerName,Email=o.Customer!=null?o.Customer.Email:null}).ToListAsync();
   var lines=await (from item in db.Set<OrderItem>().AsNoTracking() join order in query on item.OrderId equals order.Id select new{item.OrderId,item.ProductId,item.ProductName,item.BrandName,item.Quantity}).ToListAsync();
   var products=lines.GroupBy(l=>l.ProductId.HasValue?"p:"+l.ProductId.Value:"n:"+l.ProductName).Select(g=>new SalesBar{ProductId=g.First().ProductId,Name=g.OrderByDescending(x=>x.OrderId).First().ProductName,Units=g.Sum(x=>x.Quantity)}).OrderByDescending(x=>x.Units).ThenBy(x=>x.Name).Take(8).ToList();
   var brands=lines.GroupBy(l=>string.IsNullOrWhiteSpace(l.BrandName)?"Chưa xác định":l.BrandName!).Select(g=>new SalesBar{Name=g.Key,Units=g.Sum(x=>x.Quantity)}).OrderByDescending(x=>x.Units).ThenBy(x=>x.Name).ToList();
   var topBrands=brands.Take(6).ToList();if(brands.Count>6)topBrands.Add(new SalesBar{Name="Thương hiệu khác",Units=brands.Skip(6).Sum(b=>b.Units)});
   var unitsByOrder=lines.GroupBy(l=>l.OrderId).ToDictionary(g=>g.Key,g=>g.Sum(x=>x.Quantity));
   var customers=orders.GroupBy(o=>o.CustomerId.HasValue?"c:"+o.CustomerId:"g:"+o.Phone).Select(g=>new CustomerSales{CustomerId=g.First().CustomerId,Name=g.OrderByDescending(o=>o.Id).First().Name,Email=g.First().Email,Orders=g.Count(),Units=g.Sum(o=>unitsByOrder.ContainsKey(o.Id)?unitsByOrder[o.Id]:0),Spending=g.Sum(o=>o.Total)}).OrderByDescending(c=>c.Units).ThenByDescending(c=>c.Spending).ToList();
   return new DashboardViewModel{Range=range,Revenue=orders.Sum(o=>o.Total),OrderCount=orders.Count,Units=lines.Sum(l=>l.Quantity),CustomerCount=customers.Count,Products=products,Brands=topBrands,Customers=customers.Take(8).ToList()};
  }
 }
}
