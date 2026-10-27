using shopgiay.ModelView;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;

using System.Web.Mvc;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using shopgiay.Models;
using shopgiay.Filters;
using shopgiay.Services;
namespace shopgiay.Controllers {
public class CartController : shopgiay.Controllers.ShopController {
 List<CartLine> Read()=>Session["cart"] as List<CartLine> ?? new List<CartLine>();
 void Save(List<CartLine> lines)=>Session["cart"]=lines;
 async Task<List<CartRow>> Rows(){var lines=Read();var ids=lines.Select(x=>x.VariantId).ToList();var variants=await db.Variants.Include(v=>v.Product).Where(v=>ids.Contains(v.Id)).ToListAsync();return lines.Where(l=>variants.Any(v=>v.Id==l.VariantId)).Select(l=>new CartRow(variants.Single(v=>v.Id==l.VariantId),l.Quantity)).ToList();}
 public async Task<ActionResult> Index()=>View(await Rows());
 [HttpGet,OutputCache(NoStore=true,Duration=0,VaryByParam="*")]
 public async Task<ActionResult> Availability(int productId){
  var variants=await db.Variants.AsNoTracking().Where(v=>v.ProductId==productId&&v.Product.Active).ToListAsync();
  var cart=Read();
  return Json(variants.Select(v=>new{ id=v.Id,limit=Math.Min(v.Stock,20),remaining=Math.Max(0,Math.Min(v.Stock,20)-cart.Where(l=>l.VariantId==v.Id).Sum(l=>l.Quantity)) }),JsonRequestBehavior.AllowGet);
 }
 [HttpPost, ValidateAntiForgeryToken]public async Task<ActionResult> Add(int variantId,int quantity=1){
 var v=await db.Variants.Include(v=>v.Product).SingleOrDefaultAsync(v=>v.Id==variantId);var cart=Read();var old=cart.SingleOrDefault(c=>c.VariantId==variantId);var total=(old?.Quantity??0)+quantity;
 if(v==null)return HttpNotFound();
 if(!v.Product.Active||quantity<1||quantity>20||quantity>Math.Max(0,Math.Min(v.Stock,20)-(old?.Quantity??0))){TempData["Error"]="Số lượng còn có thể thêm của size này đã thay đổi. Vui lòng chọn lại.";return RedirectToAction("Product","Home",new{id=v.ProductId});}
 cart.RemoveAll(c=>c.VariantId==variantId);cart.Add(new CartLine(variantId,total));Save(cart);TempData["Success"]="Đã thêm sản phẩm vào giỏ hàng.";return RedirectToAction("Index");
 }
 [HttpPost, ValidateAntiForgeryToken]public async Task<ActionResult> Update(int variantId,int quantity){var cart=Read();if(quantity==0){cart.RemoveAll(c=>c.VariantId==variantId);}else{var v=await db.Variants.FindAsync(variantId);if(v==null||quantity<1||quantity>Math.Min(v.Stock,20)){TempData["Error"]="Số lượng vượt quá tồn kho hoặc giới hạn 20 đôi.";return RedirectToAction("Index");}var i=cart.FindIndex(c=>c.VariantId==variantId);if(i>=0)cart[i]=new CartLine(variantId,quantity);}Save(cart);return RedirectToAction("Index");}
 [CustomerAuthorize]public async Task<ActionResult> Checkout(){var rows=await Rows();if(rows.Count==0)return RedirectToAction("Index");ViewBag.Rows=rows;ViewBag.Discount=0m;var c=CurrentCustomer!;return View(new CheckoutInput{CustomerName=c.Name,Phone=c.Phone??"",Address=c.Address??""});}
 [CustomerAuthorize,HttpPost, ValidateAntiForgeryToken]public async Task<ActionResult> Checkout(CheckoutInput input,bool applyVoucher=false){
 var rows=await Rows();if(rows.Count==0)return RedirectToAction("Index");
 foreach(var r in rows)if(!r.Variant.Product.Active||r.Quantity<1||r.Quantity>r.Variant.Stock)ModelState.AddModelError("","Sản phẩm "+r.Variant.Product.Name+" đã thay đổi tồn kho. Hãy cập nhật giỏ hàng.");
 ViewBag.Rows=rows;ViewBag.Discount=0m;var customerId=CurrentCustomer!.Id;
 if(applyVoucher){ModelState.Remove("CustomerName");ModelState.Remove("Phone");ModelState.Remove("Address");var preview=await VoucherService.Evaluate(db,customerId,input.VoucherCode,rows.Sum(r=>r.Quantity*r.Variant.Product.Price));if(preview.Error!=null)ModelState.AddModelError("VoucherCode",preview.Error);else{ViewBag.Discount=preview.Discount;ViewBag.AppliedCode=preview.Voucher?.Code;}return View(input);}
 var paymentSettings=BankTransferSettingsService.Current;
 if(input.PaymentMethod=="TRANSFER"&&!paymentSettings.Ready)ModelState.AddModelError("PaymentMethod","Chuyển khoản chưa sẵn sàng. Vui lòng chọn COD hoặc liên hệ cửa hàng.");
 if(!ModelState.IsValid)return View(input);
 using var tx=db.Database.BeginTransaction();
 var subtotal=rows.Sum(r=>r.Quantity*r.Variant.Product.Price);var shipping=subtotal>=2000000?0:35000;
 var applied=await VoucherService.Evaluate(db,customerId,input.VoucherCode,subtotal,true);if(applied.Error!=null){ModelState.AddModelError("VoucherCode",applied.Error);return View(input);}
 var customer=await db.Customers.FindAsync(customerId);if(customer==null||!customer.IsActive)return new HttpStatusCodeResult(403);
 customer.Phone=input.Phone;customer.Address=input.Address;
 var order=new Order{PaymentMethod=input.PaymentMethod,CustomerId=customerId,CustomerName=input.CustomerName,Phone=input.Phone,Address=input.Address,Note=input.Note,Shipping=shipping,Discount=applied.Discount,VoucherCode=applied.Voucher?.Code,Total=subtotal-applied.Discount+shipping};
 foreach(var r in rows){r.Variant.Stock-=r.Quantity;r.Variant.Revision++;order.Items.Add(new OrderItem{ProductId=r.Variant.ProductId,BrandName=r.Variant.Product.Brand,VariantId=r.Variant.Id,ProductName=r.Variant.Product.Name,Size=r.Variant.Size,Quantity=r.Quantity,Price=r.Variant.Product.Price});}
 db.Orders.Add(order);
 if(applied.Voucher!=null)db.VoucherRedemptions.Add(new VoucherRedemption{CustomerId=customerId,VoucherId=applied.Voucher.Id,Order=order});
 try{await db.SaveChangesAsync();tx.Commit();}catch(DbUpdateException){tx.Rollback();TempData["Error"]="Tồn kho hoặc lượt sử dụng voucher vừa thay đổi. Vui lòng kiểm tra và thử lại.";return RedirectToAction("Index");}
 Save([]);Session["lastOrder"]=order.Code;EmailOutboxService.Kick();return RedirectToAction("Complete",new{code=order.Code});
 }
 [CustomerAuthorize]public async Task<ActionResult> Complete(string code){var customerId=CurrentCustomer!.Id;var order=await db.Orders.Include(o=>o.Items).SingleOrDefaultAsync(o=>o.Code==code&&o.CustomerId==customerId);return order==null?HttpNotFound():View(order);}
}

}

