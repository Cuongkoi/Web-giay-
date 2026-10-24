# STEP STORE — ASP.NET MVC 5 / SQL Server

Dự án dùng C#, ASP.NET MVC 5, .NET Framework 4.8 và Entity Framework 6. Đã chuyển từ ASP.NET Core/MySQL sang MVC 5/SQL Server theo yêu cầu mới. Mở `shopgiay.sln` bằng Visual Studio với workload ASP.NET and web development. Nếu Visual Studio đang mở bản cũ, chấp nhận Reload Project khi được hỏi.

## Cấu trúc

```text
shopgiay/
├── App_Data/
├── App_Start/
│   ├── BundleConfig.cs
│   ├── FilterConfig.cs
│   └── RouteConfig.cs
├── Areas/
│   └── Admin/
│       ├── Controllers/
│       │   ├── AccountController.cs
│       │   └── ProductsController.cs
│       ├── Data/AdminRepository.cs
│       ├── Filters/AdminAuthorizeAttribute.cs
│       ├── Views/
│       │   ├── Account/
│       │   ├── Products/
│       │   ├── Shared/_AdminLayout.cshtml
│       │   ├── _ViewStart.cshtml
│       │   └── Web.config
│       └── AdminAreaRegistration.cs
├── Content/
├── Controllers/
├── Images/
├── Models/
├── ModelView/
├── Properties/
├── Scripts/
├── Services/
├── Views/
├── Global.asax
├── Global.asax.cs
├── Web.config
└── shopgiay.csproj
```

Admin có route, bộ lọc quyền, lớp truy vấn dữ liệu và layout riêng. Controller khách hàng đặt ở Controllers, view ở Views, entity và DbContext ở Models. Các NuGet package được quản lý bằng PackageReference trong csproj; không cần packages.config. Không chép các file exe/folder ModelView bị lặp trong ảnh mẫu.

## Database / SSMS

- Máy chủ: `WINDOWS-PC\SQLEXPRESS`.
- Database: `ShopGiay`.
- Xác thực: Windows Authentication.
- Kết nối đã đặt trong `shopgiay/Web.config` và `tools/DatabaseSetup/App.config`.
- Database đã tạo với 8 sản phẩm mẫu, 72 bản ghi tồn kho theo size, 1 admin.

### Script chạy trực tiếp trong SSMS

Mở **database/01-create-shopgiay.sql**, chọn kết nối `WINDOWS-PC\SQLEXPRESS` và nhấn **F5**. Sau đó Refresh mục Databases trong Object Explorer.

Script tạo database nếu chưa có, tạo các bảng sản phẩm, ảnh, danh mục, thương hiệu, đơn hàng, admin, khách hàng, voucher, hàng đợi email, banner cùng khóa ngoại và chỉ mục. Script thêm sản phẩm mẫu và những size còn thiếu; không xóa hoặc ghi đè dữ liệu đã có. Đã chạy kiểm tra hai lần thành công. Không dùng script này để sửa schema của một database ShopGiay khác có cấu trúc không tương thích.

Mật khẩu admin được hash PBKDF2-SHA256, không có mật khẩu mặc định trong SQL. Tài khoản local đã tạo được lưu trong `.local/admin-credentials.txt` (được gitignore). Trên máy mới có thể build và chạy công cụ `tools/DatabaseSetup` để tạo admin nếu database chưa có admin. Công cụ không ghi đè mật khẩu admin đang có.

## Chạy web

### Truy cập từ các thiết bị cùng mạng

Đã cấu hình IP máy chủ hiện tại **192.168.41.103**, cổng **5188**:

- Cửa hàng: `http://192.168.41.103:5188/`.
- Admin: `http://192.168.41.103:5188/Admin`.
- Máy chủ vẫn truy cập được `http://localhost:5188/`.

IIS Express có binding IP riêng, HTTP URL reservation cho tài khoản Windows chạy web và firewall `ShopGiay-LAN-5188`, chỉ nhận TCP 5188 đến IP trên từ mạng **192.168.41.0/24**. Không tắt firewall hoặc mở cổng SQL Server.

Các thiết bị khác phải dùng cùng mạng nội bộ; máy chủ phải đang bật và web phải đang chạy. Lần sau vẫn Start/F5 bằng Visual Studio. IP máy chủ được kiểm tra trả HTTP 200; cần thử thêm trên thiết bị khác để xác nhận đường đi qua Wi-Fi/router. Nếu router bật cách ly thiết bị/mạng khách, các máy có thể không liên lạc được dù cùng Wi-Fi.

Nếu IP thay đổi hoặc xóa thư mục .vs làm mất binding, dùng script cấu hình `scripts/Enable-Lan.ps1` với quyền Administrator để cập nhật IP/cổng một lần, sau đó khởi động lại IIS Express. Đây là script thiết lập mạng, không phải cách chạy web hàng ngày.

### Đăng nhập admin

Khách hàng và admin đăng nhập độc lập. Cookie `ShopGiay.CustomerAuth` dùng cho cửa hàng, cookie `ShopGiay.AdminAuth` dùng cho `/Admin`; server chỉ nhận cookie đúng phạm vi chức năng và vai trò. Có thể đăng nhập hai tài khoản cùng trình duyệt. Đăng nhập/đăng xuất admin không xóa phiên khách hay giỏ hàng; đăng xuất khách không thoát admin. Cookie chung cũ không được dùng để xác thực nữa, nên cần đăng nhập lại từng bên một lần sau khi cập nhật.

Nếu chưa đăng nhập admin, mở trang quản trị sẽ chuyển đến màn hình đăng nhập admin. Sau khi đăng nhập đúng, web quay lại trang đã yêu cầu. Giao diện cửa hàng không hiển thị hàng Quản trị/Sản phẩm/Đơn hàng/Đăng xuất của admin. Kiểm tra bằng `scripts/Separate-Auth-Smoke.ps1` gồm đăng nhập đồng thời, đăng xuất độc lập, giữ giỏ hàng và chặn tráo cookie giữa hai vai trò.

Chạy trực tiếp bằng nút Start/F5:

1. Đóng Visual Studio đang giữ project cũ, rồi mở lại `shopgiay.sln`.
2. Nhấp phải project **shopgiay** → **Set as Startup Project** (nếu chưa tự được chọn).
3. Chọn **IIS Express**, cấu hình **Debug / Any CPU** trên thanh công cụ.
4. Nhấn **Start/F5**. Visual Studio khởi động IIS Express và mở trang chủ **http://localhost:5188/**.

Không cần chạy PowerShell trước. Attach to Process chỉ để gắn debugger vào tiến trình đã chạy. Project đã có cấu hình Web Application MVC 5, trang bắt đầu `/`, định danh riêng với bản ASP.NET Core cũ và IIS Express. Đã kiểm tra build bằng MSBuild và Visual Studio command-line; không tự điều khiển giao diện để bấm F5.

- Khách hàng: http://localhost:5188/
- Admin: http://localhost:5188/Admin
- Đăng nhập: http://localhost:5188/Admin/Account/Login

Có thể build bằng Developer PowerShell:

```powershell
msbuild shopgiay/shopgiay.csproj /restore /t:Build
```

Chạy IIS Express (thay đường dẫn theo máy của bạn nếu cần):

```powershell
& 'C:/Program Files/IIS Express/iisexpress.exe' /path:'D:\do an Cao Quy Cuong\shop giay\shopgiay\shopgiay' /port:5188 /systray:false
```

## Ảnh và giao diện

### Thương hiệu do admin quản lý

Vào **Admin → Thương hiệu** (`/Admin/Brands`) để thêm/sửa/xóa, đặt thứ tự và ẩn/hiện trong bộ lọc cửa hàng. Ô thương hiệu của sản phẩm đã đổi thành danh sách chọn bắt buộc; có liên kết thêm nhanh thương hiệu. Đổi tên thương hiệu cập nhật nhãn trên các sản phẩm đã liên kết. Thương hiệu còn sản phẩm không được xóa; chuyển sản phẩm hoặc dùng Ẩn. Ẩn chỉ bỏ khỏi bộ lọc, giữ nguyên sản phẩm đang bán.

Database đã được cập nhật bằng `database/03-admin-brands.sql`: tạo bảng Brands, khóa ngoại và chuyển các tên thương hiệu đang dùng sang bảng mới, không mất dữ liệu. Script chạy lại được, không tạo thương hiệu mặc định ngoài những tên có sẵn trong sản phẩm. Script 01 cũng bao gồm thay đổi này. Trên máy/database cũ, chạy script 03 trước khi chạy mã nguồn mới.

### Danh mục do admin quản lý

Vào **Admin → Danh mục** (`/Admin/Categories`) để thêm/sửa/xóa danh mục, đặt thứ tự và bật/tắt hiển thị. Không tạo sẵn danh mục Nike/Adidas. Menu, các nút lọc và liên kết danh mục lấy từ database. Trang chủ và Khuyến mãi là các liên kết chức năng cố định.

Khi thêm/sửa sản phẩm, chọn **Danh mục** tương ứng. Sản phẩm cũ giữ nguyên, mặc định chưa phân loại. Danh mục đang có sản phẩm không được xóa; chuyển sản phẩm sang danh mục khác hoặc ẩn danh mục. Thương hiệu chọn từ mục quản lý Thương hiệu, không nhập tay.

Database local đã được cập nhật bằng `database/02-admin-categories.sql` (không xóa dữ liệu, không thêm danh mục mẫu). Script tạo database `01-create-shopgiay.sql` cũng bao gồm cấu trúc mới. Trên database đã triển khai trước đó, chạy script 02 trước khi chạy mã nguồn mới.

Các file giao diện đã chuẩn hóa UTF-8 BOM và Web.config quy định file/request/response UTF-8 để tránh lỗi chữ tiếng Việt trên .NET Framework. Đã kiểm tra 16 trường hợp danh mục và mã hóa qua HTTP trên IIS Express do Visual Studio chạy, bằng script `scripts/Categories-Smoke.ps1`.

Trong Admin → Thêm/Sửa sản phẩm, ảnh được chia thành hai phần:

- **Ảnh đại diện:** một ô chọn file riêng, tối đa 1 ảnh. Dùng trên danh sách sản phẩm và giỏ hàng. Chọn file mới để thay ảnh, hoặc đánh dấu xóa ảnh đại diện khi lưu.
- **Ảnh thông tin sản phẩm:** một ô chọn nhiều file riêng, tối đa 8 ảnh thông tin sau khi trừ ảnh cũ được đánh dấu xóa. Không tính ảnh đại diện; tổng cộng có thể lưu 9 ảnh (1 + 8).

Chấp nhận PNG/JPG/JPEG, mỗi file tối đa 5 MB. Có xem trước và đếm số ảnh thông tin. Chọn thêm nhiều lần sẽ cộng dồn các ảnh mới; bấm dấu × ở góc từng ảnh để loại bỏ (áp dụng cả ảnh đã lưu và ảnh mới). Bấm **Lưu sản phẩm** để tải ảnh lên. Nếu biểu mẫu báo lỗi, chọn lại các file mới. Trang chi tiết có ảnh thu nhỏ để khách xem từng ảnh. Ảnh cũ và dữ liệu sản phẩm được giữ lại.

File được lưu trong `Images/Products/` với tên ngẫu nhiên, thông tin trong bảng `ProductImages`; `Product.ImageUrl` đồng bộ với ảnh đại diện. Server kiểm tra nội dung ảnh thật, giới hạn dung lượng và số ảnh; khi xóa/thay ảnh sẽ dọn file upload sau khi lưu database thành công. Thư mục upload cần quyền ghi của IIS Express/IIS và cần sao lưu cùng database. Thư mục này được gitignore.

Database local đã cập nhật bằng `database/04-product-images.sql`. Trên database khác đã có dữ liệu, chạy script này trước khi chạy mã nguồn mới. Script 01 bao gồm cấu trúc mới. Kiểm tra upload qua HTTP: `scripts/Images-Smoke.ps1` (22 trường hợp, dùng database phát triển).

- CSS cửa hàng: Content/site.css.
- CSS admin: Content/admin.css.
- Layout cửa hàng: Views/Shared/_Layout.cshtml.
- Layout admin: Areas/Admin/Views/Shared/_AdminLayout.cshtml.
- Banner: admin quản lý tại `/Admin/Banners`, hiển thị bằng `Views/Shared/_Banners.cshtml`.

## Chức năng và kiểm tra

### Màu sắc và mã nội bộ

Ô nhập SKU đã được bỏ khỏi biểu mẫu. Hệ thống tự tạo mã nội bộ khi thêm sản phẩm và giữ mã cũ khi sửa, admin không cần nhập mã. Màu sắc là danh sách chọn khi thêm/sửa giày: Đen, Trắng, Đỏ, Xanh dương, Xanh lá, Vàng, Cam, Hồng, Tím, Nâu, Xám, Be, Phối màu. Mỗi sản phẩm hiện chọn một màu; trang chi tiết hiển thị màu này. Sản phẩm cũ chưa có màu vẫn giữ nguyên, admin chọn màu khi lưu lại.

Database local đã cập nhật bằng `database/05-product-colors.sql`; script tạo database 01 cũng bao gồm cột mới. Kiểm tra tạo/sửa không nhập SKU và lưu màu: `scripts/Colors-Smoke.ps1` (11 trường hợp).

Khách hàng: tìm kiếm, lọc thương hiệu, sắp xếp giá, chọn size, giỏ hàng, đặt COD. Admin: quản lý sản phẩm, ảnh, giá, tồn kho theo size, ẩn/hiện, đơn hàng và trạng thái. Kho được trừ khi đặt hàng và hoàn khi hủy đơn; hủy lặp không hoàn kho hai lần.

Đã có tài khoản khách, ưu đãi khách quen và thông báo email. Thanh toán hiện dùng COD; chưa tích hợp thanh toán online hoặc SMS. Các script kiểm tra chỉ dùng trên database phát triển.

## Tài khoản khách hàng và quản lý người dùng

- Đăng ký: `/Account/Register`. Đăng nhập: `/Account/Login`. Tài khoản và lịch sử đơn: `/Account`.
- Khách phải đăng nhập tài khoản khách hàng trước khi đặt COD. Giỏ hàng được giữ khi đăng nhập. Khách chỉ xem được đơn của chính mình.
- Admin → Người dùng (`/Admin/Users`): tìm tên/email, xem lịch sử mua, số đơn hoàn thành, hạng khách, khóa/mở khóa tài khoản. Khóa thu hồi các phiên khách hiện có, không xóa đơn hàng.
- Khách quen được tính khi tài khoản có **ít nhất 3 đơn đã hoàn thành**, không tính số đôi trong một đơn, đơn hủy hoặc đơn đang giao. Đơn cũ chưa có tài khoản không tự động gán cho khách mới.
- Mật khẩu được hash PBKDF2-SHA256. Mật khẩu admin local đã đổi theo yêu cầu; thông tin nằm trong `.local/admin-credentials.txt`. Các phiên admin cũ bị thu hồi khi đổi mật khẩu.

## Voucher khách quen

Admin → Voucher khách quen (`/Admin/Vouchers`) tạo mã code, tỷ lệ giảm 1–100%, giá trị đơn tối thiểu, thời gian bắt đầu/kết thúc (giờ Việt Nam), bật/ngừng voucher.

Chỉ tài khoản đủ 3 đơn hoàn thành được áp dụng. Mỗi voucher dùng tối đa một lần cho một khách; giảm trên giá trị sản phẩm, không giảm phí ship. Khách nhập mã và bấm Áp dụng ở bước thanh toán. Server kiểm tra điều kiện, thời hạn, lượt dùng và tính lại tổng tiền khi đặt hàng. Hủy đơn sẽ hoàn lượt dùng voucher. Lịch sử đơn lưu mã và số tiền giảm tại thời điểm mua.

Khi có voucher còn hiệu lực hoặc một khách vừa đạt hạng khách quen, hệ thống xếp email cho những khách đã đăng ký nhận tin. Trong Tài khoản, khách có thể bật/tắt nhận email; không nhận email vẫn được dùng voucher đủ điều kiện.

## Cấu hình Gmail trên giao diện admin

1. Vào **Admin → Cấu hình email** (`/Admin/EmailSettings`).
2. Nhập Gmail gửi thư, App Password và tên người gửi. Để trống Email hiển thị nếu dùng chính Gmail đó.
3. Với Gmail, giữ máy chủ `smtp.gmail.com`, cổng `587` (STARTTLS). Xem [hướng dẫn App Password của Google](https://support.google.com/mail/answer/185833?hl=vi) và [thông số SMTP Gmail](https://support.google.com/mail/answer/7104828?hl=vi).
4. Lưu cấu hình. Nhập email của bạn ở mục Gửi email kiểm tra và bấm Gửi thử. Có thể gửi thử khi chưa bật gửi tự động.
5. Bật gửi email tự động và lưu để xử lý thông báo voucher đang chờ.

App Password được mã hóa bằng Windows DPAPI, lưu riêng ở `App_Data/smtp.local.config`, không đưa vào Git/publish và không hiển thị lại trên giao diện. Để trống App Password khi sửa sẽ giữ mật khẩu đã lưu. Khi chuyển máy hoặc đổi tài khoản Windows chạy IIS, nhập lại App Password qua màn hình cấu hình.

Admin → Voucher → Hàng đợi email (`/Admin/Vouchers/Emails`) xem Pending/Sending/Sent/Failed/Cancelled và yêu cầu thử lại. Chỉ đánh dấu Sent sau khi SMTP nhận thư. Khi chưa có cấu hình, thư nằm trong hàng đợi, không giả lập gửi thành công. Mỗi khách/voucher được xếp một thông báo. Worker chạy khi web/IIS đang hoạt động; dừng Visual Studio thì hàng đợi giữ trong database và được xử lý khi web chạy lại. Chưa xác minh gửi Gmail thật tại môi trường xây dựng vì chưa có Gmail/App Password thực.

## Banner và Dashboard

- **Admin → Banner**: thêm/sửa/xóa banner, tải PNG/JPG, chỉnh tiêu đề, nội dung, nút bấm, liên kết nội bộ, thứ tự và bật/ẩn. Trang chủ lấy từ database, không còn banner quảng cáo cố định. Không có banner đang bật thì không hiển thị vùng banner.
- **Dashboard** là trang đầu tại `/Admin`, gồm doanh thu, số đơn hoàn thành, số đôi, số khách, biểu đồ giày bán chạy, biểu đồ tỷ trọng thương hiệu và top khách mua nhiều đôi nhất.
- Lọc 7/30/90 ngày hoặc tất cả thời gian, theo ngày đặt hàng. Chỉ tính đơn đã hoàn thành. Doanh thu/tổng chi đã trừ voucher và gồm phí giao hàng; thứ hạng xếp theo số đôi. Thông tin sản phẩm/thương hiệu được lưu theo dòng đơn để đổi tên/xóa sản phẩm không làm mất thống kê. Dòng đơn cũ không còn đủ dữ liệu sẽ có thương hiệu Chưa xác định.

## Migration và kiểm tra tính năng mới

- Database local đã áp dụng `database/06-customers-vouchers-banners.sql` và `database/07-sales-dashboard.sql`.
- Trên database đã có dữ liệu, chạy các migration còn thiếu theo thứ tự trước khi dùng mã nguồn mới. `01-create-shopgiay.sql` bao gồm toàn bộ cấu trúc mới cho database rỗng.
- `scripts/Accounts-Vouchers-Smoke.ps1`: kiểm tra luồng tài khoản, phân quyền, đơn hàng, khách quen, voucher, hàng đợi, banner và thống kê. Script in đường dẫn SQL dọn dữ liệu giả do chính lượt kiểm tra tạo.
- `scripts/Email-Settings-Smoke.ps1`: kiểm tra phân quyền trang cấu hình, lưu/mã hóa/ẩn mật khẩu, giữ mật khẩu cũ khi để trống và kiểm tra dữ liệu gửi thử. Không gửi email thật; khôi phục cấu hình gốc sau kiểm tra và bỏ qua kiểm tra ghi nếu đã có cấu hình người dùng.

Lượt xác minh gần nhất: 40 kiểm tra luồng tài khoản/voucher/banner/Dashboard và 12 kiểm tra cấu hình email đã qua; build thành công. Script tạo database đã được chạy trên database QA riêng và database QA đã được xóa sau kiểm tra. Dữ liệu khách/đơn/voucher giả được dọn; dữ liệu thật được giữ nguyên. Chưa thử gửi Gmail thật vì chưa có thông tin đăng nhập Gmail của cửa hàng.




## Email báo đơn mới và thanh toán VNPay

- Vào `/Admin/EmailSettings`: dùng Gmail/App Password hiện có; nhập **Email cá nhân nhận thông báo**, bật **Gửi email cho chủ shop khi khách đặt đơn mới** rồi lưu. Công tắc email đơn hàng độc lập với email voucher. Email gồm mã đơn, thông tin giao hàng, sản phẩm, giảm giá, phí giao hàng, tổng tiền và trạng thái thanh toán tại thời điểm gửi. Xem trạng thái gửi trên trang quản lý đơn hàng.
- Đơn mới được đưa vào hàng đợi cùng lúc lưu đơn; lỗi SMTP được thử lại sau 15 phút, khóa xử lý quá 10 phút sẽ được nhận lại. Worker chạy khi website/IIS hoạt động. SMTP có thể nhận thư nhưng kết nối bị ngắt trước khi trả kết quả: khi thử lại có khả năng trùng email; mã đơn trong tiêu đề giúp nhận biết. Đơn có sẵn trước migration 08 được đánh dấu Skipped, không gửi lại hàng loạt.
- Vào `/Admin/PaymentSettings`: nhập TmnCode, HashSecret, URL website HTTPS công khai; dùng đúng bộ khóa Sandbox/thật. HashSecret lưu mã hóa DPAPI trong `App_Data/vnpay.local.config`, không đưa vào Git/publish. Để trống giữ khóa cũ; không đổi bộ khóa khi còn giao dịch đang chờ.
- Đăng ký với VNPay **IPN** `https://tenmiencuaban/Payment/Ipn`; Return URL là `https://tenmiencuaban/Payment/Return`. LAN `192.168.41.103` và localhost không nhận được IPN từ VNPay; cần hosting hoặc địa chỉ HTTPS công khai chuyển tiếp tới website để thử tích hợp thực tế. Không tự công khai website hay mở thêm firewall từ tính năng này.
- Checkout hỗ trợ COD/VNPAY, mặc định COD. Nếu VNPay chưa được bật/cấu hình, việc đặt qua VNPay bị chặn, khách vẫn dùng COD. Tổng tiền, mã đơn và chữ ký đều do server tạo; thời hạn đường dẫn thanh toán 15 phút; yêu cầu tối thiểu 5.000đ.
- IPN xác minh HMAC-SHA512, mã merchant, số tiền, trạng thái giao dịch; khóa bản ghi và chống xử lý lặp. Return URL chỉ hiển thị, không sửa trạng thái thanh toán. Đơn chưa được IPN xác nhận trả tiền không thể chuyển sang giao hàng/hoàn thành. Kết quả nghi ngờ/đảo giao dịch cần đối soát thủ công.
- Website giữ tồn kho/voucher cho đơn VNPay đang chờ hoặc thất bại; chưa tự hủy khi hết giờ để tránh nhầm giao dịch đã trừ tiền nhưng IPN đến muộn. Admin kiểm tra VNPay rồi hủy đơn thất bại; đơn đang chờ chỉ được hủy sau ít nhất 20 phút. Hủy trả tồn kho và lượt voucher theo luồng hiện có. Đơn đã thanh toán không hỗ trợ hủy/hoàn tiền tự động. IPN thành công đến sau khi đơn đã hủy vẫn ghi nhận tiền nhận được và hiển thị cảnh báo cần hoàn tiền, không tự giao lại.
- Áp dụng `database/08-vnpay-order-emails.sql` cho database cũ. Script tổng `database/01-create-shopgiay.sql` đã kèm migration này.
- Kiểm thử: `scripts/Payments-Smoke.ps1` dùng tài khoản/sản phẩm giả và khóa VNPay giả, không truy cập cổng thanh toán hoặc gửi email thật; tạm khóa email tự động rồi khôi phục nguyên cấu hình sau kiểm thử. File dọn dữ liệu giả được tạo tại `.local/payment-smoke-cleanup.sql` và phải chạy bằng DatabaseSetup sau kiểm thử. Không chạy đồng thời với kiểm thử khác hoặc khách thật đang thanh toán vì script tạm thay cấu hình VNPay.
- Tài liệu giao thức: https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html

## Thanh toán hiện tại: COD và chuyển khoản QR

Cập nhật: giao diện đặt hàng đã bỏ VNPay, chỉ nhận `COD` và `TRANSFER`. Không cần hosting, tên miền, tunnel hoặc tài khoản VNPay để dùng chuyển khoản QR; hoạt động trên localhost/LAN.

- Admin mở `/Admin/PaymentSettings` (menu **Cấu hình thanh toán**), tải một ảnh QR PNG/JPG/JPEG tối đa 5 MB, nhập tùy chọn ngân hàng/số tài khoản/chủ tài khoản và bật chuyển khoản. Có thể thay ảnh hoặc tắt chuyển khoản và xóa ảnh. File được kiểm tra nội dung ảnh thật, lưu tên ngẫu nhiên trong `/Images/Payments/`. Cấu hình nằm trong `App_Data/bank-transfer.local.config`, loại khỏi Git/publish; cần sao lưu cùng thư mục ảnh khi chuyển máy.
- Checkout có COD và Chuyển khoản ngân hàng. Chọn chuyển khoản sẽ hiện QR và hướng dẫn. Sau khi đặt đơn, khách thấy số tiền và nội dung cụ thể **Tên khách hàng Mã đơn hàng**. Mã đơn chưa tồn tại trước bước đặt hàng nên khách được hướng dẫn đặt đơn trước khi chuyển tiền. Đây là ảnh QR tĩnh do admin cung cấp, không tự nhúng số tiền/nội dung vào QR.
- Đơn chuyển khoản mặc định chưa thanh toán. Admin kiểm tra ngân hàng rồi bấm **Xác nhận đã nhận tiền** trong danh sách đơn. Chỉ sau đó mới được xác nhận/giao/hoàn thành đơn. Khách không có quyền tự xác nhận tiền. Không có kết nối ngân hàng tự kiểm tra tiền vào. Đơn đã trả tiền không hỗ trợ tự động hoàn tiền; xử lý với khách ngoài hệ thống.
- Không chuyển đổi phương thức hoặc trạng thái của đơn VNPay cũ. Endpoint xác minh VNPay cũ được giữ để tiếp nhận kết quả giao dịch lịch sử; không tạo giao dịch VNPay mới. Phần hướng dẫn VNPay và script `Payments-Smoke.ps1` ở trên chỉ thuộc phiên bản trước, không áp dụng cho giao diện hiện tại.
- Kiểm thử hiện tại: `scripts/Bank-Transfer-Smoke.ps1`, 25 kiểm tra gồm tải/thay/xóa QR, chặn ảnh giả, đặt COD/chuyển khoản, nội dung và số tiền, xác nhận thủ công, chống khách truy cập admin. Dữ liệu giả được dọn bằng `.local/bank-smoke-cleanup.sql` qua DatabaseSetup. Không gửi mail thật hoặc giao dịch ngân hàng thật trong bài thử.
