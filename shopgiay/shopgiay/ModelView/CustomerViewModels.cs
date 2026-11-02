using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using shopgiay.Models;
namespace shopgiay.ModelView
{
    public class RegisterInput
    {
        [Required, StringLength(100)] public string Name { get; set; } = "";
        [Required, EmailAddress, StringLength(180)] public string Email { get; set; } = "";
        [Required, StringLength(100, MinimumLength = 8), DataType(DataType.Password)] public string Password { get; set; } = "";
        [Required, Compare("Password", ErrorMessage = "Mật khẩu xác nhận chưa khớp."), DataType(DataType.Password)] public string ConfirmPassword { get; set; } = "";
        public bool ReceiveVoucherEmails { get; set; } = true;
    }
    public class CustomerAccountView
    {
        public Customer Customer { get; set; } = null!; public int CompletedOrders { get; set; }
        public List<Order> Orders { get; set; } = new List<Order>(); public List<Voucher> Vouchers { get; set; } = new List<Voucher>();
    }
    public class CustomerRow { public Customer Customer { get; set; } = null!; public int CompletedOrders { get; set; } }
    public class VoucherEditInput
    {
        public int Id { get; set; }
        [Required, StringLength(30), RegularExpression(@"[A-Za-z0-9_-]{3,30}")] public string Code { get; set; } = "";
        [Range(1, 100)] public int Percent { get; set; } = 10;
        [Range(0, 1000000000)] public decimal MinimumSubtotal { get; set; }
        public DateTime StartsLocal { get; set; } = DateTime.UtcNow.AddHours(7); public DateTime EndsLocal { get; set; } = DateTime.UtcNow.AddHours(7).AddDays(30); public bool Active { get; set; } = true;
    }
}
