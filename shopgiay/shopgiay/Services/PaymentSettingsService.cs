using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Hosting;
using System.Xml.Linq;
using shopgiay.ModelView;
namespace shopgiay.Services {
 public class PaymentSettings {
  public bool Enabled{get;set;}public bool Sandbox{get;set;}=true;public string TmnCode{get;set;}="";public string HashSecret{get;set;}="";public string PublicBaseUrl{get;set;}="";
  public bool Ready=>Enabled&&TmnCode.Length==8&&HashSecret.Length>0&&PublicBaseUrl.Length>0;
  public string Gateway=>Sandbox?"https://sandbox.vnpayment.vn/paymentv2/vpcpay.html":"https://pay.vnpay.vn/vpcpay.html";
 }
 public static class PaymentSettingsService {
  static readonly object Sync=new object();
  static string PathName=>HostingEnvironment.MapPath("~/App_Data/vnpay.local.config")??Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"App_Data","vnpay.local.config");
  public static PaymentSettings Current{get{lock(Sync){if(!File.Exists(PathName))return new PaymentSettings();var doc=XDocument.Load(PathName);Func<string,string> val=k=>(string?)doc.Root?.Elements("add").FirstOrDefault(e=>(string?)e.Attribute("key")==k)?.Attribute("value")??"";var secret="";try{if(val("Secret").Length>0)secret=Encoding.UTF8.GetString(ProtectedData.Unprotect(Convert.FromBase64String(val("Secret")),null,DataProtectionScope.CurrentUser));}catch(CryptographicException){}catch(FormatException){}
   return new PaymentSettings{Enabled=val("Enabled")=="true",Sandbox=val("Sandbox")!="false",TmnCode=val("TmnCode"),PublicBaseUrl=val("BaseUrl"),HashSecret=secret};
  }}}
  public static void Save(PaymentSettingsInput i){lock(Sync){var secret=string.IsNullOrWhiteSpace(i.HashSecret)?Current.HashSecret:i.HashSecret!.Trim();var root=new XElement("appSettings");Action<string,string> add=(k,v)=>root.Add(new XElement("add",new XAttribute("key",k),new XAttribute("value",v)));add("Enabled",i.Enabled?"true":"false");add("Sandbox",i.Sandbox?"true":"false");add("TmnCode",(i.TmnCode??"").Trim());add("BaseUrl",(i.PublicBaseUrl??"").Trim().TrimEnd('/'));add("Secret",secret.Length==0?"":Convert.ToBase64String(ProtectedData.Protect(Encoding.UTF8.GetBytes(secret),null,DataProtectionScope.CurrentUser)));Directory.CreateDirectory(Path.GetDirectoryName(PathName)!);var tmp=PathName+".tmp";try{new XDocument(root).Save(tmp);if(File.Exists(PathName))File.Replace(tmp,PathName,null);else File.Move(tmp,PathName);}finally{if(File.Exists(tmp))File.Delete(tmp);}}}
 }
}