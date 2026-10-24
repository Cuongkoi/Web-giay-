using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text.RegularExpressions;
using System.Web;
namespace shopgiay.Services {
 public sealed class PreparedProductImage {
  public byte[] Bytes{get;set;}=new byte[0];public string Extension{get;set;}="";
 }
 public static class ProductImageService {
  public static PreparedProductImage Prepare(HttpPostedFileBase file){
   var extension=Path.GetExtension(file.FileName).ToLowerInvariant();
   if(extension!=".png"&&extension!=".jpg"&&extension!=".jpeg")throw new ArgumentException("Chỉ chấp nhận ảnh PNG hoặc JPG/JPEG.");
   if(file.ContentLength<=0||file.ContentLength>5*1024*1024)throw new ArgumentException("Mỗi ảnh phải có dung lượng tối đa 5 MB.");
   try{
    using(var source=new MemoryStream()){file.InputStream.CopyTo(source);source.Position=0;
     using(var image=ReadImage(source)){
      bool png=image.RawFormat.Guid==ImageFormat.Png.Guid;bool jpg=image.RawFormat.Guid==ImageFormat.Jpeg.Guid;
      if((extension==".png"&&!png)||(extension!=".png"&&!jpg))throw new ArgumentException("Nội dung ảnh không khớp định dạng PNG/JPG.");
      if(image.Width>12000||image.Height>12000||(long)image.Width*image.Height>40000000)throw new ArgumentException("Ảnh quá lớn. Vui lòng dùng ảnh tối đa 12.000 px mỗi chiều và 40 megapixel.");
      using(var output=new MemoryStream()){image.Save(output,png?ImageFormat.Png:ImageFormat.Jpeg);return new PreparedProductImage{Bytes=output.ToArray(),Extension=png?".png":".jpg"};}
     }
    }
   }catch(OutOfMemoryException){throw new ArgumentException("File ảnh không hợp lệ hoặc vượt quá kích thước cho phép.");}catch(System.Runtime.InteropServices.ExternalException){throw new ArgumentException("Không đọc được file ảnh. Vui lòng chọn PNG/JPG hợp lệ.");}
  }
  private static Image ReadImage(Stream source){try{return Image.FromStream(source,true,true);}catch(ArgumentException){throw new ArgumentException("File ảnh PNG/JPG không hợp lệ.");}}
  public static string Save(PreparedProductImage image,HttpServerUtilityBase server,string folderName="Products"){if(folderName!="Products"&&folderName!="Banners"&&folderName!="Payments")throw new ArgumentException("Thư mục ảnh không hợp lệ.");var url="/Images/"+folderName+"/"+Guid.NewGuid().ToString("N")+image.Extension;var folder=server.MapPath("~/Images/"+folderName);Directory.CreateDirectory(folder);File.WriteAllBytes(server.MapPath("~"+url),image.Bytes);return url;}
  public static void DeleteManaged(string? url,HttpServerUtilityBase server){
   if(url==null||!Regex.IsMatch(url,@"\A/Images/(Products|Banners|Payments)/[a-f0-9]{32}\.(png|jpg)\z"))return;
   try{var path=server.MapPath("~"+url);if(File.Exists(path))File.Delete(path);}catch(IOException ex){System.Diagnostics.Trace.TraceWarning(ex.Message);}catch(UnauthorizedAccessException ex){System.Diagnostics.Trace.TraceWarning(ex.Message);}
  }
 }
}

