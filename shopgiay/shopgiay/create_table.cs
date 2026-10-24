using System;
using System.Data.Entity;
using System.IO;
using System.Linq;
using shopgiay.Models;
using shopgiay.Services;
namespace shopgiay.Tools {
 public static class CreateTable {
  public static void Main(string[] args){
   if(args.Length>1&&args[0]=="--run-sql"){
    var connection=new System.Data.SqlClient.SqlConnectionStringBuilder(System.Configuration.ConfigurationManager.ConnectionStrings["ShopDb"].ConnectionString){InitialCatalog="master"};
    using(var sql=new System.Data.SqlClient.SqlConnection(connection.ConnectionString)){
     sql.Open();foreach(var batch in System.Text.RegularExpressions.Regex.Split(File.ReadAllText(args[1]),@"^\s*GO\s*$",System.Text.RegularExpressions.RegexOptions.Multiline|System.Text.RegularExpressions.RegexOptions.IgnoreCase)){
      if(string.IsNullOrWhiteSpace(batch))continue;using(var command=sql.CreateCommand()){command.CommandText=batch;command.CommandTimeout=120;command.ExecuteNonQuery();}
     }
    }
    Console.WriteLine("SQL script executed successfully.");return;
   }
   Database.SetInitializer<ShopDb>(null);
   if(args.Length>1&&args[0]=="--set-admin-password"){
    var password=Console.ReadLine();if(string.IsNullOrWhiteSpace(password)||password.Length<8)throw new ArgumentException("Mật khẩu cần ít nhất 8 ký tự.");
    using(var db=new ShopDb()){var admin=db.Admins.SingleOrDefault(a=>a.Email=="admin@shopgiay.vn");if(admin==null)throw new InvalidOperationException("Không tìm thấy admin@shopgiay.vn.");admin.PasswordHash=PasswordService.Hash(password);admin.SecurityStamp=Guid.NewGuid().ToString("N");db.SaveChanges();File.WriteAllText(Path.GetFullPath(args[1]),"Admin URL: http://localhost:5188/Admin\r\nEmail: "+admin.Email+"\r\nPassword: "+password+"\r\n");Console.WriteLine("Đã đổi mật khẩu admin và thu hồi phiên đăng nhập cũ.");}return;
   }
   using(var db=new ShopDb()){
    if(args.Length>0&&args[0]=="--schema"){Console.WriteLine(((System.Data.Entity.Infrastructure.IObjectContextAdapter)db).ObjectContext.CreateDatabaseScript());return;}
    db.Database.CreateIfNotExists();SeedService.Initialize(db).GetAwaiter().GetResult();
    if(!db.Admins.Any()){
     var password="Step!"+Guid.NewGuid().ToString("N").Substring(0,16)+"9a";
     var admin=new AdminUser{Email="admin@shopgiay.vn",PasswordHash=PasswordService.Hash(password)};db.Admins.Add(admin);db.SaveChanges();
     var credentialFile=Path.GetFullPath(args.Length>0?args[0]:"admin-credentials.local.txt");Directory.CreateDirectory(Path.GetDirectoryName(credentialFile)!);File.WriteAllText(credentialFile,"Admin URL: http://localhost:5188/Admin\r\nEmail: "+admin.Email+"\r\nPassword: "+password+"\r\n");Console.WriteLine("Admin credentials saved to: "+credentialFile);
    }
    Console.WriteLine("Database: "+db.Database.Connection.DataSource+" / "+db.Database.Connection.Database);
    Console.WriteLine("Products: "+db.Products.Count()+"; Variants: "+db.Variants.Count()+"; Admins: "+db.Admins.Count());
   }
  }
 }
}
