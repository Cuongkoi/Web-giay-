using System.Threading.Tasks;
using System.Web.Mvc;
using shopgiay.Areas.Admin.Filters;
using shopgiay.Areas.Admin.Data;
namespace shopgiay.Areas.Admin.Controllers {
 [AdminAuthorize]public class DashboardController:shopgiay.Controllers.ShopController {
  public async Task<ActionResult> Index(string range="30")=>View(await new DashboardRepository(db).Load(range));
 }
}
