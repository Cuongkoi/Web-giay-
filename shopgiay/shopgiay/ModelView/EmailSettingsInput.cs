using System.ComponentModel.DataAnnotations;
namespace shopgiay.ModelView
{
    public class EmailSettingsInput
    {
        public bool Enabled { get; set; }
        public bool OrderNotificationsEnabled { get; set; }
        [EmailAddress, StringLength(180)] public string? OwnerEmail { get; set; }
        [Required, StringLength(180), RegularExpression(@"[A-Za-z0-9.-]+", ErrorMessage = "Máy chủ SMTP không hợp lệ.")] public string Host { get; set; } = "smtp.gmail.com";
        [Range(1, 65535)] public int Port { get; set; } = 587;
        [EmailAddress, StringLength(180)] public string? User { get; set; }
        [EmailAddress, StringLength(180)] public string? FromAddress { get; set; }
        [Required, StringLength(100)] public string SenderName { get; set; } = "STEP STORE";
        [StringLength(100), DataType(DataType.Password)] public string? AppPassword { get; set; }
    }
    public class TestEmailInput { [Required, EmailAddress, StringLength(180)] public string Recipient { get; set; } = ""; }
}
