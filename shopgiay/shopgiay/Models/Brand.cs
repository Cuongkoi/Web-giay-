using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace shopgiay.Models
{
    public class Brand
    {
        public int Id { get; set; }
        [Required(ErrorMessage = "Vui lòng nhập tên thương hiệu"), StringLength(50), Index(IsUnique = true)] public string Name { get; set; } = "";
        [Range(0, 10000)] public int SortOrder { get; set; }
        public bool Active { get; set; } = true;
    }
}
