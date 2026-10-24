using System.Collections.Generic;
namespace shopgiay.ModelView {
 public class SalesBar {public int? ProductId{get;set;}public string Name{get;set;}="";public int Units{get;set;}}
 public class CustomerSales {public int? CustomerId{get;set;}public string Name{get;set;}="";public string? Email{get;set;}public int Units{get;set;}public int Orders{get;set;}public decimal Spending{get;set;}}
 public class DashboardViewModel {
  public string Range{get;set;}="30";public decimal Revenue{get;set;}public int OrderCount{get;set;}public int Units{get;set;}public int CustomerCount{get;set;}
  public List<SalesBar> Products{get;set;}=new List<SalesBar>();public List<SalesBar> Brands{get;set;}=new List<SalesBar>();public List<CustomerSales> Customers{get;set;}=new List<CustomerSales>();
 }
}
