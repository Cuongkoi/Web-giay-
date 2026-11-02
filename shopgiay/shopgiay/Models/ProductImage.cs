using System.ComponentModel.DataAnnotations;
namespace shopgiay.Models
{
    public class ProductImage
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public Product Product { get; set; } = null!;
        [Required, StringLength(500)] public string Url { get; set; } = "";
        public int SortOrder { get; set; }
        public bool IsPrimary { get; set; }
    }
}
