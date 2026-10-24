using System.ComponentModel.DataAnnotations;
namespace shopgiay.ModelView {
 public class LoginInput {
  [Required,EmailAddress]public string Email {get;set;}="";
  [Required,DataType(DataType.Password)]public string Password {get;set;}="";
 }
}
