using System.ComponentModel.DataAnnotations;
namespace shopgiay.ModelView {
 public class BankTransferSettingsInput {
  public bool Enabled{get;set;}
  [StringLength(100)]public string? BankName{get;set;}
  [StringLength(50)]public string? AccountNumber{get;set;}
  [StringLength(100)]public string? AccountHolder{get;set;}
  public string? QrImageUrl{get;set;}
 }
}