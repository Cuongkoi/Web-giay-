using System.Collections.Generic;
using shopgiay.Models;
namespace shopgiay.ModelView {
 public class AdminOverview { public List<Product> Products{get;set;}=new List<Product>();public int OrderCount{get;set;}public decimal Revenue{get;set;} }
}
