using System.ComponentModel.DataAnnotations;
namespace shopgiay.ModelView {
 public class PaymentSettingsInput {
  public bool Enabled{get;set;}public bool Sandbox{get;set;}=true;
  [StringLength(8),RegularExpression("^[A-Za-z0-9]{8}$")]public string? TmnCode{get;set;}
  [StringLength(256),DataType(DataType.Password)]public string? HashSecret{get;set;}
  [StringLength(300),Url]public string? PublicBaseUrl{get;set;}
 }
}