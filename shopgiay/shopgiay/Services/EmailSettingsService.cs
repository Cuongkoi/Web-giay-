using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Hosting;
using System.Xml.Linq;
using shopgiay.ModelView;
namespace shopgiay.Services {
 public class SmtpSettings {
  public bool OrderNotificationsEnabled{get;set;}public string OwnerEmail{get;set;}="";public bool Enabled{get;set;}public string Host{get;set;}="smtp.gmail.com";public int Port{get;set;}=587;
  public string User{get;set;}="";public string Password{get;set;}="";public string FromAddress{get;set;}="";public string SenderName{get;set;}="STEP STORE";
  public bool HasCredentials=>!string.IsNullOrWhiteSpace(User)&&!string.IsNullOrWhiteSpace(Password);
 }
 public static class EmailSettingsService {
  private static readonly object Sync=new object();
  private static string SettingsPath=>HostingEnvironment.MapPath("~/App_Data/smtp.local.config")??Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"App_Data","smtp.local.config");
  public static SmtpSettings Current {get{lock(Sync){if(!File.Exists(SettingsPath))return new SmtpSettings();XDocument document;try{document=XDocument.Load(SettingsPath);}catch(System.Xml.XmlException){return new SmtpSettings();}catch(IOException){return new SmtpSettings();}
   Func<string,string> value=key=>(string?)document.Root?.Elements("add").FirstOrDefault(e=>(string?)e.Attribute("key")==key)?.Attribute("value")??"";
   var password=value("Smtp.Password");var encrypted=value("Smtp.PasswordProtected");if(encrypted.Length>0){try{password=Encoding.UTF8.GetString(ProtectedData.Unprotect(Convert.FromBase64String(encrypted),null,DataProtectionScope.CurrentUser));}catch(CryptographicException){password="";}catch(FormatException){password="";}}
   int port;if(!int.TryParse(value("Smtp.Port"),out port)||port<1||port>65535)port=587;
   return new SmtpSettings{OwnerEmail=value("Smtp.OwnerEmail"),OrderNotificationsEnabled=value("Smtp.OrderNotificationsEnabled")=="true",Enabled=value("Smtp.Enabled").Equals("true",StringComparison.OrdinalIgnoreCase),Host=string.IsNullOrWhiteSpace(value("Smtp.Host"))?"smtp.gmail.com":value("Smtp.Host"),Port=port,User=value("Smtp.User"),Password=password,FromAddress=value("Smtp.From"),SenderName=string.IsNullOrWhiteSpace(value("Smtp.SenderName"))?"STEP STORE":value("Smtp.SenderName")};
  }}}
  public static void Save(EmailSettingsInput input){lock(Sync){var previous=Current;var password=string.IsNullOrWhiteSpace(input.AppPassword)?previous.Password:input.AppPassword!.Trim();if(input.Host=="smtp.gmail.com")password=password.Replace(" ","");
   var protectedPassword=password.Length==0?"":Convert.ToBase64String(ProtectedData.Protect(Encoding.UTF8.GetBytes(password),null,DataProtectionScope.CurrentUser));
   var root=new XElement("appSettings");Action<string,string> add=(key,value)=>root.Add(new XElement("add",new XAttribute("key",key),new XAttribute("value",value)));
   add("Smtp.OwnerEmail",(input.OwnerEmail??"").Trim());add("Smtp.OrderNotificationsEnabled",input.OrderNotificationsEnabled?"true":"false");add("Smtp.Enabled",input.Enabled?"true":"false");add("Smtp.Host",input.Host.Trim());add("Smtp.Port",input.Port.ToString());add("Smtp.User",(input.User??"").Trim());add("Smtp.From",(input.FromAddress??"").Trim());add("Smtp.SenderName",input.SenderName.Trim());add("Smtp.PasswordProtected",protectedPassword);
   var document=new XDocument(new XDeclaration("1.0","utf-8",null),root);var path=SettingsPath;Directory.CreateDirectory(Path.GetDirectoryName(path)!);var temporary=path+"."+Guid.NewGuid().ToString("N")+".tmp";
   try{document.Save(temporary);if(File.Exists(path))File.Replace(temporary,path,null);else File.Move(temporary,path);}finally{if(File.Exists(temporary))File.Delete(temporary);}
  }}
 }
}
