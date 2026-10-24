using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using shopgiay.Models;
namespace shopgiay.Services {
 public static class VnPayService {
  static string Encode(string v)=>System.Net.WebUtility.UrlEncode(v);
  public static string Canonical(IEnumerable<KeyValuePair<string,string>> values)=>string.Join("&",values.Where(p=>!string.IsNullOrEmpty(p.Value)).OrderBy(p=>p.Key,StringComparer.Ordinal).Select(p=>Encode(p.Key)+"="+Encode(p.Value)));
  public static string Sign(string raw,string secret){using(var h=new HMACSHA512(Encoding.UTF8.GetBytes(secret)))return BitConverter.ToString(h.ComputeHash(Encoding.UTF8.GetBytes(raw))).Replace("-","").ToLowerInvariant();}
  public static bool Verify(NameValueCollection query,PaymentSettings settings){
   var keys=query.AllKeys;if(keys.Any(k=>k==null||query.GetValues(k)!.Length!=1))return false;
   var signature=query["vnp_SecureHash"]??"";if(signature.Length!=128||signature.Any(c=>!Uri.IsHexDigit(c))||settings.HashSecret.Length==0)return false;
   var values=keys.Where(k=>k.StartsWith("vnp_",StringComparison.Ordinal)&&k!="vnp_SecureHash"&&k!="vnp_SecureHashType").Select(k=>new KeyValuePair<string,string>(k,query[k]??""));
   var expected=Sign(Canonical(values),settings.HashSecret);int difference=0;for(int i=0;i<128;i++)difference|=char.ToLowerInvariant(signature[i])^expected[i];return difference==0;
  }
  public static bool Matches(Order order,NameValueCollection q){decimal amount;return order.PaymentMethod=="VNPAY"&&q["vnp_TmnCode"]==order.PaymentMerchant&&decimal.TryParse(q["vnp_Amount"],NumberStyles.None,CultureInfo.InvariantCulture,out amount)&&amount==order.Total*100m;}
  public static string CreateUrl(Order order,PaymentSettings s,string ip){
   if(!s.Ready)throw new InvalidOperationException("VNPay chưa được cấu hình.");var now=DateTime.UtcNow.AddHours(7);var values=new Dictionary<string,string>{
    {"vnp_Version","2.1.0"},{"vnp_Command","pay"},{"vnp_TmnCode",s.TmnCode},{"vnp_Amount",(order.Total*100m).ToString("0",CultureInfo.InvariantCulture)},{"vnp_CreateDate",now.ToString("yyyyMMddHHmmss",CultureInfo.InvariantCulture)},{"vnp_ExpireDate",now.AddMinutes(15).ToString("yyyyMMddHHmmss",CultureInfo.InvariantCulture)},
    {"vnp_CurrCode","VND"},{"vnp_IpAddr",ip},{"vnp_Locale","vn"},{"vnp_OrderInfo","Thanh toan don hang "+order.Code},{"vnp_OrderType","other"},{"vnp_ReturnUrl",s.PublicBaseUrl+"/Payment/Return"},{"vnp_TxnRef",order.Code}};
   var raw=Canonical(values);return s.Gateway+"?"+raw+"&vnp_SecureHash="+Sign(raw,s.HashSecret);
  }
 }
}