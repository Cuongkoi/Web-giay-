using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using shopgiay.Models;
namespace shopgiay.Areas.Admin.Data {
 public class CategoryRepository {
  private readonly ShopDb db;
  public CategoryRepository(ShopDb context){db=context;}
  public Task<List<Category>> List()=>db.Categories.AsNoTracking().OrderBy(c=>c.SortOrder).ThenBy(c=>c.Name).ToListAsync();
 }
}
