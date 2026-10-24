using System;
using System.Globalization;
using System.Security.Cryptography;
namespace shopgiay.Services {
 public static class PasswordService {
  public static string Hash(string password){
   var salt=new byte[16];using(var rng=RandomNumberGenerator.Create())rng.GetBytes(salt);
   using(var kdf=new Rfc2898DeriveBytes(password,salt,210000,HashAlgorithmName.SHA256))return "210000."+Convert.ToBase64String(salt)+"."+Convert.ToBase64String(kdf.GetBytes(32));
  }
  public static bool Verify(string password,string hash){
   try{var parts=hash.Split('.');int iterations=int.Parse(parts[0],CultureInfo.InvariantCulture);if(iterations<100000||iterations>1000000)return false;
    using(var kdf=new Rfc2898DeriveBytes(password,Convert.FromBase64String(parts[1]),iterations,HashAlgorithmName.SHA256)){
     var actual=kdf.GetBytes(32);var expected=Convert.FromBase64String(parts[2]);if(expected.Length!=actual.Length)return false;int diff=0;for(int i=0;i<actual.Length;i++)diff|=actual[i]^expected[i];return diff==0;
    }
   }catch(FormatException){return false;}catch(ArgumentException){return false;}
  }
 }
}
