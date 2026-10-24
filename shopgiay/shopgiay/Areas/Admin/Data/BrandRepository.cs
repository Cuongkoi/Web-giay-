using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using shopgiay.Models;
namespace shopgiay.Areas.Admin.Data {
 public class BrandRepository {
  private readonly ShopDb db;
  public BrandRepository(ShopDb context){db=context;}
  public Task<List<Brand>> List()=>db.Brands.AsNoTracking().OrderBy(b=>b.SortOrder).ThenBy(b=>b.Name).ToListAsync();
 }
}
