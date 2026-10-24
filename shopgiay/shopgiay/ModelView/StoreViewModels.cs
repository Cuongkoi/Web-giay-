using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using shopgiay.Models;
namespace shopgiay.ModelView {
public class CheckoutInput {
 [Required,RegularExpression("^(COD|TRANSFER)$",ErrorMessage="Phương thức thanh toán không hợp lệ.")]public string PaymentMethod{get;set;}="COD";
 [StringLength(30)]public string? VoucherCode{get;set;}
 [Required(ErrorMessage="Vui lòng nhập họ tên"),StringLength(100)]public string CustomerName{get;set;}="";
 [Required,RegularExpression(@"0[0-9]{9,10}",ErrorMessage="Số điện thoại gồm 10–11 chữ số, bắt đầu bằng 0")]public string Phone{get;set;}="";
 [Required(ErrorMessage="Vui lòng nhập địa chỉ"),StringLength(500),MinLength(10)]public string Address{get;set;}="";
 [StringLength(1000)]public string? Note{get;set;}
}
public class CartLine {public int VariantId{get;set;} public int Quantity{get;set;} public CartLine(int variantId,int quantity){VariantId=variantId;Quantity=quantity;}}
public class CartRow {public Variant Variant{get;set;} public int Quantity{get;set;} public CartRow(Variant variant,int quantity){Variant=variant;Quantity=quantity;}}
public class Catalog {public int? BrandId{get;set;}public int? CategoryId{get;set;}public string? CategoryName{get;set;}public List<Product> Products{get;set;}=[];public string? Q{get;set;}public string? Brand{get;set;}public string? Sort{get;set;}public bool Sale{get;set;}}

}
