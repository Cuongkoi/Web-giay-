using System;
using System.Linq;
using System.Data.Entity;
using System.Threading.Tasks;
using shopgiay.Models;
namespace shopgiay.Services {
public static class SeedService {
 public static async Task Initialize(ShopDb db){
 if(await db.Products.AnyAsync())return;
 var names=new[]{("Nike","Air Force 1 '07 All White",2490000m,3050000m),("Nike","Air Jordan 1 Low Panda",2790000m,4500000m),("Adidas","Samba OG Cloud White",2290000m,2800000m),("New Balance","530 White Natural Indigo",1890000m,2790000m),("Puma","Palermo Leather White",1690000m,2190000m),("MLB","Chunky Liner New York",2590000m,2990000m),("Nike","V2K Run Summit White",2590000m,3350000m),("Adidas","Gazelle Indoor Green",2390000m,2890000m)};
 int i=0;foreach(var n in names)db.Products.Add(new Product{Name="Giày "+n.Item1+" "+n.Item2,Brand=n.Item1,Sku="SG-"+(++i).ToString("000"),Price=n.Item3,OriginalPrice=n.Item4,Featured=i<=4,Description="Thiết kế dễ phối đồ, phù hợp đi học, đi làm và dạo phố. Liên hệ cửa hàng để được tư vấn kích thước và thông tin sản phẩm.",Variants=Enumerable.Range(36,9).Select(s=>new Variant{Size=s,Stock=5}).ToList()});
 await db.SaveChangesAsync();
 foreach(var product in await db.Products.Where(p=>p.BrandId==null).ToListAsync()){var brand=db.Brands.Local.FirstOrDefault(b=>b.Name==product.Brand)??await db.Brands.FirstOrDefaultAsync(b=>b.Name==product.Brand);if(brand==null){brand=new Brand{Name=product.Brand};db.Brands.Add(brand);}product.BrandInfo=brand;}
 await db.SaveChangesAsync();
 }
}

}