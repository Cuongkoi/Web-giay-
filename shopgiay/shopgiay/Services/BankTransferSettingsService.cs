using System;
using System.IO;
using System.Linq;
using System.Web.Hosting;
using System.Xml.Linq;
using shopgiay.ModelView;
namespace shopgiay.Services {
 public class BankTransferSettings {
  public bool Enabled{get;set;}public string BankName{get;set;}="";public string AccountNumber{get;set;}="";public string AccountHolder{get;set;}="";public string QrImageUrl{get;set;}="";
  public bool Ready=>Enabled&&System.Text.RegularExpressions.Regex.IsMatch(QrImageUrl,@"\A/Images/Payments/[a-f0-9]{32}\.(png|jpg)\z");
 }
 public static class BankTransferSettingsService {
  static readonly object Sync=new object();
  static string SettingsPath=>HostingEnvironment.MapPath("~/App_Data/bank-transfer.local.config")??Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"App_Data","bank-transfer.local.config");
  public static BankTransferSettings Current{get{lock(Sync){if(!File.Exists(SettingsPath))return new BankTransferSettings();XDocument doc;try{doc=XDocument.Load(SettingsPath);}catch(System.Xml.XmlException){return new BankTransferSettings();}catch(IOException){return new BankTransferSettings();}Func<string,string> val=k=>(string?)doc.Root?.Elements("add").FirstOrDefault(e=>(string?)e.Attribute("key")==k)?.Attribute("value")??"";return new BankTransferSettings{Enabled=val("Enabled")=="true",BankName=val("BankName"),AccountNumber=val("AccountNumber"),AccountHolder=val("AccountHolder"),QrImageUrl=val("QrImageUrl")};}}}
  public static string Save(BankTransferSettingsInput i,string? newQr,bool removeQr){lock(Sync){var old=Current;var qr=newQr??(removeQr?"":old.QrImageUrl);if(i.Enabled&&string.IsNullOrEmpty(qr))throw new ArgumentException("Vui lòng tải ảnh QR trước khi bật chuyển khoản.");var root=new XElement("appSettings");Action<string,string> add=(k,v)=>root.Add(new XElement("add",new XAttribute("key",k),new XAttribute("value",v)));add("Enabled",i.Enabled?"true":"false");add("BankName",(i.BankName??"").Trim());add("AccountNumber",(i.AccountNumber??"").Trim());add("AccountHolder",(i.AccountHolder??"").Trim());add("QrImageUrl",qr);Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);var tmp=SettingsPath+".tmp";try{new XDocument(root).Save(tmp);if(File.Exists(SettingsPath))File.Replace(tmp,SettingsPath,null);else File.Move(tmp,SettingsPath);}finally{if(File.Exists(tmp))File.Delete(tmp);}return old.QrImageUrl==qr?"":old.QrImageUrl;}}
 }
}