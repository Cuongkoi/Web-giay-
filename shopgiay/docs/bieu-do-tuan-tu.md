# Biểu đồ tuần tự — CUONGKOI Sneaker

Tài liệu mô tả mã nguồn hiện tại ngày 27/10/2026: ASP.NET MVC 5, Entity Framework 6 và SQL Server. Gồm 18 biểu đồ, tách theo nghiệp vụ để dùng trong báo cáo và thuyết trình.

## Quy ước và phạm vi

- Đọc từ trên xuống: đường liền là yêu cầu, đường đứt là phản hồi; `alt` là rẽ nhánh, `opt` là bước tùy chọn, `loop` là lặp, `critical` biểu diễn phạm vi transaction trong các biểu đồ bên dưới.
- UI là trình duyệt và Razor View; controller điều phối nghiệp vụ; `ShopDb / SQL Server` gộp Entity Framework và database để biểu đồ dễ đọc. Session, file cấu hình, thư mục ảnh và SMTP được thể hiện riêng khi có liên quan.
- Các action POST thay đổi dữ liệu kiểm tra anti-forgery token. Các action quản trị còn yêu cầu `AdminAuthorize`; đặt hàng và tài khoản cá nhân yêu cầu `CustomerAuthorize`. Hai lớp kiểm tra này áp dụng trước action, kể cả khi không được lặp lại trong từng biểu đồ.
- Cookie khách hàng và admin độc lập. Giỏ hàng lưu ở `Session["cart"]`, không có bảng giỏ hàng trong database. Thêm giỏ chưa giữ hàng; tồn kho được trừ khi lưu đơn thành công.
- Thanh toán mới chỉ có COD và TRANSFER. QR chuyển khoản là ảnh tĩnh; admin tự đối soát ngân hàng. Không mô tả VNPay là phương thức đặt đơn mới; endpoint lịch sử vẫn còn trong mã nguồn.
- Các thao tác ngân hàng/giao nhận ngoài website được ghi rõ là thủ công. Các biểu đồ không giả định có API ngân hàng hoặc đơn vị vận chuyển.

## 01. Tìm kiếm, lọc và xem chi tiết sản phẩm

Mã nguồn: `Controllers/HomeController.cs`, `Controllers/ShopController.cs`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt
    participant C as HomeController
    participant DB as ShopDb / SQL Server
    participant S as Session
    K->>UI: Mở cửa hàng hoặc nhập điều kiện lọc
    UI->>C: GET /?q, brandId, categoryId, sort, sale
    C->>DB: Đọc thương hiệu và danh mục đang hiển thị
    opt Có brandId hoặc categoryId
        C->>DB: Kiểm tra tồn tại và Active
        DB-->>C: Kết quả kiểm tra
    end
    alt Bộ lọc theo ID không hợp lệ
        C-->>UI: HTTP 404
    else Điều kiện hợp lệ
        C->>DB: Lọc Products.Active và nạp Variants
        Note over C,DB: Tìm Name/Sku; lọc giảm giá; sắp giá hoặc Featured
        C->>DB: Đọc banner Active theo SortOrder
        DB-->>C: Sản phẩm, size, tồn kho và banner
        C-->>UI: Render Views/Home/Index
        UI-->>K: Danh sách sản phẩm
    end
    K->>UI: Chọn một sản phẩm
    UI->>C: GET /Home/Product/id
    C->>DB: Nạp sản phẩm Active, Images, Variants, Category
    alt Không có sản phẩm đang bán
        C-->>UI: HTTP 404
    else Tìm thấy
        C->>S: Đọc số lượng từng variant đã có trong giỏ
        S-->>C: CartLine theo VariantId
        C->>C: Tính số lượng còn có thể thêm theo size
        C-->>UI: Render Product và AvailableQuantities
        UI-->>K: Chi tiết, ảnh, size và giới hạn số lượng
    end
```

## 02. Đăng ký tài khoản khách hàng

Mã nguồn: `Controllers/AccountController.cs`, `Services/PasswordService.cs`, `Services/SeparateAuthService.cs`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt
    participant C as AccountController
    participant P as PasswordService
    participant DB as ShopDb / SQL Server
    participant A as SeparateAuthService
    K->>UI: Mở form đăng ký
    UI->>C: GET /Account/Register
    C-->>UI: Form và anti-forgery token
    K->>UI: Nhập tên, email, mật khẩu và xác nhận
    UI->>C: POST /Account/Register
    Note over UI,C: Sai token bị chặn trước khi xử lý action
    C->>C: Chuẩn hóa email và tên; kiểm tra ModelState
    C->>DB: Kiểm tra email đã tồn tại
    alt Dữ liệu sai hoặc email đã được dùng
        C-->>UI: Form kèm lỗi
    else Hợp lệ
        C->>P: Hash mật khẩu
        P-->>C: PBKDF2-SHA256, salt và hash
        C->>DB: INSERT Customers và SaveChanges
        alt Xung đột dữ liệu khi lưu
            C-->>UI: Báo email đã được đăng ký
        else Lưu thành công
            C->>A: SignInCustomer(customer)
            A-->>UI: Set-Cookie ShopGiay.CustomerAuth
            C-->>UI: Redirect /Account
            UI-->>K: Tài khoản cá nhân
        end
    end
```

## 03. Đăng nhập và hiển thị tên khách hàng

Mã nguồn: `Controllers/AccountController.cs`, `Services/SeparateAuthService.cs`, `Views/Shared/_Layout.cshtml`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt
    participant C as AccountController
    participant M as MemoryCache
    participant DB as ShopDb / SQL Server
    participant P as PasswordService
    participant A as SeparateAuthService
    K->>UI: Nhập email và mật khẩu
    UI->>C: POST /Account/Login và returnUrl
    C->>M: Đọc số lần đăng nhập sai theo IP
    alt Đã sai ít nhất 8 lần
        C-->>UI: Yêu cầu đợi 15 phút
    else Chưa bị giới hạn
        C->>C: Kiểm tra form, chuẩn hóa email
        C->>DB: Tìm Customers theo email
        DB-->>C: Customer hoặc không có
        opt Tài khoản tồn tại và đang hoạt động
            C->>P: Verify mật khẩu với PasswordHash
            P-->>C: Đúng hoặc sai
        end
        alt Sai mật khẩu, không có tài khoản hoặc bị khóa
            C->>M: Tăng số lần sai, thời hạn 15 phút
            C-->>UI: Thông báo đăng nhập thất bại
        else Đăng nhập hợp lệ
            C->>M: Xóa bộ đếm sai
            C->>A: SignInCustomer
            A-->>UI: Cookie CustomerAuth, ticket 7 ngày
            Note over A,UI: Ticket chứa CustomerId và SecurityStamp; cookie không persistent
            C-->>UI: Redirect returnUrl nội bộ hoặc /Account
            UI->>A: Request tiếp theo kèm cookie
            A->>DB: Kiểm tra CustomerId, IsActive, SecurityStamp
            DB-->>A: Khách hàng hợp lệ
            A->>A: Gán Context.Items.Customer và vai trò Customer
            Note over A,UI: Layout lấy Customer.Name từ Context.Items
            UI-->>K: Hiển thị tên khách hàng trên đầu trang
        end
    end
```

## 04. Xác thực theo request, đăng nhập admin và đăng xuất

Mã nguồn: `Global.asax.cs`, `Services/SeparateAuthService.cs`, hai bộ lọc Authorize và `Areas/Admin/Controllers/AccountController.cs`.

```mermaid
sequenceDiagram
    autonumber
    actor U as Người dùng
    participant UI as Trình duyệt
    participant A as SeparateAuthService
    participant DB as ShopDb / SQL Server
    participant F as Bộ lọc quyền
    participant C as Controller
    UI->>A: Request tới một URL
    alt URL thuộc /Admin
        A->>A: Chỉ đọc ShopGiay.AdminAuth
        A->>DB: Tìm AdminUsers, so SecurityStamp
    else URL cửa hàng
        A->>A: Chỉ đọc ShopGiay.CustomerAuth
        A->>DB: Kiểm tra Customers và trạng thái hoạt động
    end
    DB-->>A: Dữ liệu tài khoản
    A->>F: Principal đúng vai trò hoặc anonymous
    alt Action bảo vệ nhưng chưa đủ quyền
        F-->>UI: Redirect trang login đúng vai trò và returnUrl
        opt Người dùng đăng nhập admin
            U->>UI: Nhập tài khoản quản trị
            UI->>C: POST /Admin/Account/Login
            C->>C: Kiểm tra token, form, giới hạn 8 lần sai theo IP
            C->>DB: Tìm admin theo email
            DB-->>C: AdminUser và PasswordHash
            C->>C: PasswordService.Verify
            alt Đúng thông tin
                C->>A: SignInAdmin
                A-->>UI: Cookie AdminAuth, ticket 4 giờ
                C-->>UI: Redirect URL admin hợp lệ hoặc /Admin
            else Sai thông tin
                C-->>UI: Form kèm lỗi; tăng bộ đếm sai
            end
        end
    else Đủ quyền hoặc action công khai
        F->>C: Thực thi action
        C-->>UI: Kết quả
    end
    opt Đăng xuất một vai trò
        U->>UI: Bấm đăng xuất
        UI->>C: POST Logout tương ứng kèm token
        C->>A: SignOutCustomer hoặc SignOutAdmin
        A-->>UI: Cho cookie của vai trò đó hết hạn
        Note over A,UI: Giữ cookie vai trò còn lại và Session giỏ hàng
    end
```

## 05. Chọn size và giới hạn số lượng theo tồn kho

Mã nguồn: `Views/Home/Product.cshtml`, `Scripts/stock-quantity.js`, `CartController.Availability`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Giao diện sản phẩm
    participant JS as stock-quantity.js
    participant C as CartController
    participant DB as ShopDb / SQL Server
    participant S as Session giỏ hàng
    K->>UI: Chọn một size
    UI->>JS: Sự kiện change
    JS->>JS: Áp dụng giới hạn có sẵn trên trang
    JS->>C: GET /Cart/Availability?productId
    C->>DB: Đọc Variants thuộc sản phẩm đang bán
    DB-->>C: Stock theo size
    C->>S: Đọc số lượng đã thêm theo VariantId
    S-->>C: Số lượng trong giỏ
    C->>C: limit = min(Stock, 20)
    C->>C: remaining = max(0, limit - số lượng trong giỏ)
    C-->>JS: JSON id, limit, remaining; không cache
    alt remaining bằng 0
        JS->>UI: Làm mờ và vô hiệu hóa size; khóa thêm giỏ
    else remaining lớn hơn 0
        JS->>UI: Đặt max số lượng bằng remaining
        loop Khách tăng, giảm hoặc nhập số lượng
            K->>UI: Thay đổi số lượng
            UI->>JS: click hoặc input
            JS->>JS: Giới hạn số nguyên trong khoảng cho phép
            alt Đã đạt số lượng tối đa
                JS->>UI: Khóa nút cộng, làm mờ size đang chọn
            else Chưa đạt tối đa
                JS->>UI: Cho tăng tiếp; khóa nút trừ khi ở mức tối thiểu
            end
        end
    end
    Note over UI,JS: Size đang chọn đạt max vẫn được gửi khi thêm giỏ
    Note over UI,JS: Quay lại tab cũng gọi lại Availability
```

Ví dụ: kho size 40 còn 3 đôi, giỏ đã có 1 đôi thì chỉ thêm tối đa 2. Khi giỏ đã có đủ 3 đôi, size 40 bị vô hiệu hóa. Giới hạn 20 đôi/size vẫn được giữ theo quy tắc hiện có.

## 06. Thêm, cập nhật và xóa giỏ hàng

Mã nguồn: `CartController.Add`, `Update`, `Index` và `Scripts/stock-quantity.js`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt và JavaScript
    participant C as CartController
    participant DB as ShopDb / SQL Server
    participant S as Session
    K->>UI: Bấm thêm vào giỏ
    UI->>C: GET Availability để kiểm tra lại
    C->>DB: Đọc tồn kho hiện tại
    C->>S: Đọc giỏ hiện tại
    C-->>UI: Số lượng còn có thể thêm
    alt Không gọi được API kiểm tra
        UI-->>K: Báo không kiểm tra được; cho thử lại
    else Số lượng đã vượt giới hạn mới
        UI->>UI: Giảm số lượng và yêu cầu khách kiểm tra lại
    else Số lượng vẫn hợp lệ
        UI->>C: POST /Cart/Add variantId, quantity, token
        C->>DB: Nạp Variant và Product
        C->>S: Đọc dòng giỏ hàng cũ
        alt Variant không tồn tại
            C-->>UI: HTTP 404
        else Không còn bán hoặc số lượng không hợp lệ
            C-->>UI: Redirect trang sản phẩm và thông báo chọn lại
        else Hợp lệ
            C->>S: Ghi tổng số lượng vào Session.cart
            C-->>UI: Redirect /Cart và thông báo thành công
        end
    end
    opt Cập nhật hoặc xóa tại giỏ hàng
        K->>UI: Chỉnh số lượng hoặc chọn Xóa
        opt Số lượng cập nhật lớn hơn 0
            UI->>C: GET Availability
            C-->>UI: Giới hạn tổng của size
        end
        UI->>C: POST /Cart/Update
        alt quantity bằng 0
            C->>S: Xóa CartLine tương ứng
        else Số lượng hợp lệ so với tồn kho và mức 20
            C->>S: Thay số lượng CartLine
        else Số lượng không hợp lệ
            C->>C: Ghi thông báo lỗi, giữ giỏ cũ
        end
        C-->>UI: Redirect /Cart
    end
    UI->>C: GET /Cart
    C->>S: Đọc VariantId và Quantity
    C->>DB: Đọc sản phẩm, giá và tồn kho hiện tại
    C-->>UI: Render giỏ hàng và tổng tiền
    Note over C,DB: Thêm/cập nhật giỏ không trừ tồn kho
```

## 07. Mở checkout và áp dụng voucher xem trước

Mã nguồn: `CartController.Checkout`, `VoucherService.Evaluate`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt
    participant F as CustomerAuthorize
    participant C as CartController
    participant V as VoucherService
    participant DB as ShopDb / SQL Server
    UI->>F: GET /Cart/Checkout
    alt Chưa đăng nhập khách hàng
        F-->>UI: Redirect /Account/Login kèm returnUrl
    else Đã đăng nhập
        F->>C: Thực thi Checkout
        C->>DB: Nạp sản phẩm và biến thể từ giỏ
        alt Giỏ hàng trống
            C-->>UI: Redirect /Cart
        else Có hàng
            C-->>UI: Form điền sẵn tên, điện thoại và địa chỉ
        end
    end
    K->>UI: Nhập voucher và bấm Áp dụng
    UI->>C: POST Checkout với applyVoucher=true
    C->>C: Kiểm tra lại hàng; bỏ yêu cầu tên, điện thoại, địa chỉ cho bước xem trước
    C->>V: Evaluate(customerId, code, subtotal)
    alt Không nhập mã
        V-->>C: Discount bằng 0
    else Có nhập mã
        V->>DB: Đếm đơn Hoàn thành của khách
        alt Ít hơn 3 đơn
            V-->>C: Chưa đủ điều kiện khách quen
        else Đủ điều kiện
            V->>DB: Đọc voucher và lượt dùng của khách
            V->>V: Kiểm tra Active, thời hạn, đơn tối thiểu, chưa dùng
            alt Điều kiện không đạt
                V-->>C: Thông báo lỗi cụ thể
            else Hợp lệ
                V->>V: Làm tròn subtotal nhân tỷ lệ giảm
                V-->>C: Mã voucher và Discount
            end
        end
    end
    C-->>UI: Render lại checkout với số tiền giảm hoặc lỗi
    Note over C,DB: Chưa tạo đơn hoặc ghi nhận lượt dùng ở bước xem trước
```

## 08. Đặt đơn COD hoặc chuyển khoản — transaction chính

Mã nguồn: `CartController.Checkout` POST, `Models/Shop.cs`, `VoucherService`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt
    participant C as CartController
    participant V as VoucherService
    participant DB as ShopDb / SQL Server
    participant S as Session
    participant E as EmailOutboxService
    K->>UI: Xác nhận đặt hàng
    UI->>C: POST /Cart/Checkout kèm dữ liệu và token
    Note over UI,C: CustomerAuthorize kiểm tra trước action
    C->>S: Đọc giỏ hàng
    C->>DB: Nạp lại sản phẩm, giá và tồn kho
    alt Giỏ trống
        C-->>UI: Redirect /Cart
    else Có hàng
        C->>C: Kiểm tra form, Active và Quantity so với Stock
        opt Chọn TRANSFER
            C->>C: Đọc BankTransferSettings và kiểm tra Ready
        end
        alt Dữ liệu sai hoặc chuyển khoản chưa sẵn sàng
            C-->>UI: Render checkout kèm lỗi
        else Kiểm tra ban đầu hợp lệ
            critical Transaction tạo đơn
                C->>DB: BeginTransaction
                C->>C: Tính subtotal và shipping
                Note over C: Ship 35.000đ; miễn khi subtotal từ 2.000.000đ
                C->>V: Evaluate với lockVoucher=true
                opt Có voucher
                    V->>DB: Kiểm tra điều kiện; đọc voucher với UPDLOCK,HOLDLOCK
                end
                V-->>C: Kết quả tính giảm giá
                alt Voucher không hợp lệ
                    C-->>UI: Hiện lỗi; transaction chưa commit được giải phóng
                else Voucher hợp lệ hoặc không dùng
                    C->>DB: Đọc lại Customer và kiểm tra IsActive
                    alt Customer không còn hợp lệ
                        C-->>UI: HTTP 403; không commit
                    else Customer hợp lệ
                        C->>C: Tạo Order, Code, OrderItems và tổng thanh toán
                        Note over C: Status = Chờ xác nhận; PaymentStatus = Unpaid
                        C->>DB: Cập nhật điện thoại, địa chỉ khách
                        C->>DB: Trừ Stock từng Variant và tăng Revision
                        C->>DB: INSERT Orders và OrderItems
                        opt Dùng voucher
                            C->>DB: INSERT VoucherRedemptions
                        end
                        C->>DB: SaveChanges
                        alt Xung đột tồn kho hoặc lượt dùng voucher
                            C->>DB: Rollback
                            C-->>UI: Redirect /Cart kèm lỗi để thử lại
                        else Lưu thành công
                            C->>DB: Commit
                            C->>S: Xóa giỏ; lưu lastOrder
                            C->>E: Kick xử lý email nền
                            C-->>UI: Redirect /Cart/Complete?code
                        end
                    end
                end
            end
        end
    end
    Note over C,DB: Total = subtotal - discount + shipping; giá lấy từ server
    Note over C,DB: Revision của Variant hỗ trợ phát hiện cập nhật đồng thời
```

## 09. Chuyển khoản QR và xác nhận đã nhận tiền

Mã nguồn: `Views/Cart/_TransferInstructions.cshtml`, `CartController.Complete`, `ProductsController.ConfirmTransfer`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Website
    participant C as CartController
    participant DB as ShopDb / SQL Server
    actor N as Ngân hàng bên ngoài
    actor A as Quản trị viên
    participant P as Admin ProductsController
    K->>UI: Chọn chuyển khoản và đặt đơn
    Note over UI,DB: Tạo đơn theo biểu đồ 08, PaymentMethod = TRANSFER
    UI->>C: GET /Cart/Complete?code
    C->>DB: Tìm đơn theo Code và CustomerId hiện tại
    alt Không phải đơn của khách hoặc không tồn tại
        C-->>UI: HTTP 404
    else Có quyền xem
        C-->>UI: Đơn, ảnh QR, số tiền và nội dung chuyển khoản
        UI-->>K: Nội dung gồm tên khách và mã đơn
    end
    K->>N: Chuyển khoản bằng ứng dụng ngân hàng
    Note over UI,N: QR tĩnh; website không nhận API xác nhận tiền từ ngân hàng
    A->>N: Kiểm tra giao dịch thực tế
    N-->>A: Thông tin tiền đã nhận
    A->>UI: Bấm Xác nhận đã nhận tiền
    UI->>P: POST ConfirmTransfer(id), cookie admin và token
    P->>DB: Đọc Order
    alt Không có đơn
        P-->>UI: HTTP 404
    else Không phải TRANSFER hoặc đơn Đã hủy
        P-->>UI: Từ chối xác nhận
    else Đã Paid
        P-->>UI: Thông báo đã xác nhận trước đó
    else Đơn chuyển khoản hợp lệ
        P->>DB: PaymentStatus = Paid; PaidAt = UTC now
        alt Xung đột cập nhật
            P-->>UI: Yêu cầu tải lại
        else Lưu thành công
            P-->>UI: Thông báo xác nhận nhận tiền
        end
    end
```

## 10. Xác nhận, giao hàng và hoàn thành đơn

Mã nguồn: `Areas/Admin/Controllers/ProductsController.cs`, action `Status`.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant UI as Trang quản lý đơn
    participant C as ProductsController
    participant DB as ShopDb / SQL Server
    participant E as EmailOutboxService
    A->>UI: Chọn trạng thái tiếp theo
    UI->>C: POST /Admin/Products/Status(id, status)
    C->>DB: Đọc Order
    DB-->>C: Status, PaymentMethod, PaymentStatus
    C->>C: Kiểm tra chuyển trạng thái hợp lệ
    Note over C: Chờ xác nhận → Đã xác nhận → Đang giao → Hoàn thành
    alt Không tìm thấy đơn
        C-->>UI: HTTP 404
    else Bước chuyển trạng thái không hợp lệ
        C-->>UI: Từ chối; giữ nguyên trạng thái
    else TRANSFER hoặc VNPAY cũ nhưng chưa Paid
        C-->>UI: Chặn xác nhận, giao và hoàn thành
    else Cho phép chuyển trạng thái
        critical Transaction cập nhật trạng thái
            C->>DB: BeginTransaction
            C->>C: Gán trạng thái mới
            opt Hoàn thành đơn COD
                C->>C: PaymentStatus = Paid; PaidAt = UTC now
            end
            C->>DB: SaveChanges
            alt Xung đột cập nhật
                C->>DB: Rollback
                C-->>UI: Yêu cầu tải lại và thử lại
            else Lưu thành công
                C->>DB: Commit
                opt Trạng thái mới là Hoàn thành
                    C->>E: Kick kiểm tra khách quen và email voucher
                end
                C-->>UI: Redirect danh sách đơn
            end
        end
    end
    Note over UI,DB: Giao hàng vật lý do cửa hàng thực hiện ngoài website
```

## 11. Hủy đơn, trả tồn kho và hoàn lượt voucher

Mã nguồn: `ProductsController.Status`; khách hàng chưa có action tự hủy đơn.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant UI as Trang quản lý đơn
    participant C as ProductsController
    participant DB as ShopDb / SQL Server
    A->>UI: Chọn hủy đơn
    UI->>C: POST Status(id, Đã hủy)
    C->>DB: Đọc Order
    alt Trạng thái không phải Chờ xác nhận hoặc Đã xác nhận
        C-->>UI: Không được hủy; chống hủy lặp
    else TRANSFER hoặc VNPAY có PaymentStatus Paid hoặc Review
        C-->>UI: Yêu cầu xử lý với khách; chưa hỗ trợ hoàn tiền tự động
    else Đơn VNPAY cũ còn Unpaid và chưa đủ 20 phút
        C-->>UI: Yêu cầu chờ hết thời gian thanh toán
    else Đủ điều kiện hủy
        critical Transaction hủy đơn
            C->>DB: BeginTransaction và nạp OrderItems
            loop Từng dòng sản phẩm trong đơn
                C->>DB: Tìm Variant theo VariantId
                opt Variant vẫn tồn tại
                    C->>DB: Cộng lại Stock; tăng Revision
                end
            end
            C->>DB: Xóa VoucherRedemptions của đơn
            C->>DB: Cập nhật Status = Đã hủy; SaveChanges
            alt Có xung đột cập nhật
                C->>DB: Rollback toàn bộ
                C-->>UI: Thông báo tải lại
            else Thành công
                C->>DB: Commit
                C-->>UI: Danh sách đơn với trạng thái Đã hủy
            end
        end
    end
```

## 12. Xem tài khoản, lịch sử mua và khóa người dùng

Mã nguồn: `Controllers/AccountController.cs`, `Areas/Admin/Controllers/UsersController.cs`, `SeparateAuthService.cs`.

```mermaid
sequenceDiagram
    autonumber
    actor K as Khách hàng
    participant UI as Trình duyệt
    participant C as AccountController
    participant DB as ShopDb / SQL Server
    actor A as Quản trị viên
    participant U as UsersController
    participant Auth as SeparateAuthService
    K->>UI: Mở tài khoản cá nhân
    UI->>C: GET /Account với cookie CustomerAuth
    C->>DB: Nạp Orders và Items theo CustomerId
    C->>C: Đếm đơn Hoàn thành
    opt Có ít nhất 3 đơn hoàn thành
        C->>DB: Đọc voucher đang hiệu lực và khách chưa dùng
    end
    C-->>UI: Hồ sơ, lịch sử đơn và voucher đủ điều kiện
    opt Đổi lựa chọn nhận email voucher
        UI->>C: POST /Account/EmailPreference
        C->>DB: Cập nhật ReceiveVoucherEmails
        C->>C: Kick email worker
        C-->>UI: Thông báo lưu thành công
    end
    A->>U: GET /Admin/Users?q
    U->>DB: Tìm tên/email và đếm đơn hoàn thành theo khách
    U-->>A: Danh sách người dùng và hạng khách
    A->>U: POST SetActive(id, active=false), token
    U->>DB: IsActive = false; tạo SecurityStamp mới
    U-->>A: Đã khóa và thu hồi phiên
    K->>Auth: Request tiếp theo với cookie cũ
    Auth->>DB: Kiểm tra IsActive và SecurityStamp
    DB-->>Auth: Tài khoản không hợp lệ
    Auth-->>UI: Hết hạn cookie, principal anonymous
    Note over Auth,UI: Action cần quyền chuyển khách về đăng nhập
    Note over U,DB: Mở khóa cũng đổi SecurityStamp; đơn hàng được giữ lại
```

## 13. Admin thêm/sửa/xóa sản phẩm và ảnh

Mã nguồn: `ProductsController.Edit`, `Delete`, `ProductImageService`.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant UI as Form sản phẩm
    participant C as ProductsController
    participant I as ProductImageService
    participant F as Images/Products
    participant DB as ShopDb / SQL Server
    A->>UI: Mở form thêm hoặc sửa
    UI->>C: GET /Admin/Products/Edit/id
    C->>DB: Đọc thương hiệu, danh mục và sản phẩm nếu sửa
    C-->>UI: Form và danh sách size/tồn kho
    A->>UI: Nhập dữ liệu; chọn ảnh đại diện và ảnh thông tin
    UI->>C: POST Edit kèm file và token
    C->>DB: Kiểm tra thương hiệu, danh mục và dữ liệu hiện có
    C->>C: Kiểm tra size, màu, giá; tự tạo hoặc giữ SKU
    C->>C: Kiểm tra ảnh thuộc sản phẩm; tối đa 8 ảnh thông tin
    C->>I: Prepare các ảnh mới
    I-->>C: Bytes và định dạng đã kiểm tra, hoặc lỗi
    alt Form hoặc ảnh không hợp lệ
        C-->>UI: Form kèm lỗi; chọn lại file mới nếu cần
    else Hợp lệ
        C->>I: Save ảnh bằng tên ngẫu nhiên
        I->>F: Ghi file ảnh
        alt Lỗi ghi file
            C->>I: Dọn các file vừa ghi
            C-->>UI: Thông báo lỗi lưu ảnh
        else Ghi file thành công
            critical Transaction lưu sản phẩm
                C->>DB: BeginTransaction
                C->>DB: Lưu Product, Variants và ProductImages
                Note over C,DB: Tăng Revision tồn kho và ImagesRevision khi cập nhật
                opt Có ảnh đại diện
                    C->>DB: Đặt IsPrimary sau lần lưu đầu và lưu tiếp
                end
                alt Lỗi database hoặc xung đột
                    C->>DB: Rollback
                    C->>I: Xóa các file mới đã ghi
                    C-->>UI: Báo lỗi dữ liệu thay đổi
                else Thành công
                    C->>DB: Commit
                    C->>I: Xóa file cũ không còn được tham chiếu
                    I->>F: Dọn ảnh thay hoặc xóa
                    C-->>UI: Redirect danh sách sản phẩm
                end
            end
        end
    end
    opt Admin xóa sản phẩm
        UI->>C: POST Delete(id), token
        C->>DB: Xóa sản phẩm và dữ liệu phụ thuộc; SaveChanges
        C->>I: Dọn ảnh sau khi lưu thành công
        Note over C,DB: Lịch sử OrderItems giữ tên, giá và size đã mua
        C-->>UI: Danh sách sản phẩm
    end
```

## 14. Quản lý danh mục, thương hiệu và banner

Mã nguồn: `CategoriesController`, `BrandsController`, `BannersController`.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant UI as Giao diện admin
    participant C as Controller tương ứng
    participant DB as ShopDb / SQL Server
    participant I as ProductImageService
    participant F as Images/Banners
    A->>UI: Thêm hoặc sửa danh mục, thương hiệu, banner
    UI->>C: POST Edit kèm token
    alt Danh mục hoặc thương hiệu
        C->>DB: Kiểm tra tên trùng và bản ghi hiện có
        C->>C: Chuẩn hóa tên, kiểm tra ModelState
        opt Đổi tên thương hiệu
            C->>DB: Đồng bộ Product.Brand của sản phẩm liên kết
        end
    else Banner
        C->>C: Kiểm tra tiêu đề, liên kết nội bộ và form
        opt Có ảnh mới
            C->>I: Prepare và Save ảnh
            I->>F: Ghi file tên ngẫu nhiên
        end
    end
    alt Dữ liệu không hợp lệ
        C-->>UI: Form kèm lỗi
    else Hợp lệ
        C->>DB: INSERT hoặc UPDATE rồi SaveChanges
        alt Lưu thất bại
            opt Banner có file vừa ghi
                C->>I: Xóa file mới
            end
            C-->>UI: Thông báo lỗi
        else Thành công
            opt Banner đã thay ảnh
                C->>I: Dọn ảnh cũ không còn tham chiếu
            end
            C-->>UI: Redirect danh sách
        end
    end
    opt Xóa danh mục hoặc thương hiệu
        UI->>C: POST Delete(id)
        C->>DB: Kiểm tra Products đang liên kết
        alt Còn sản phẩm
            C-->>UI: Chặn xóa; đề nghị chuyển sản phẩm hoặc ẩn
        else Không còn sản phẩm
            C->>DB: DELETE và SaveChanges
            C-->>UI: Kết quả xóa
        end
    end
    opt Xóa banner
        UI->>C: POST Delete(id)
        C->>DB: DELETE Banner và SaveChanges
        C->>I: Dọn ảnh không còn tham chiếu
    end
    Note over C,DB: Active=false ẩn mục tương ứng khỏi giao diện cửa hàng
```

## 15. Quản lý voucher và email cho khách quen

Mã nguồn: `VouchersController`, `EmailOutboxService`, `EmailTransport`.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant C as VouchersController
    participant DB as ShopDb / SQL Server
    participant W as EmailOutboxService
    participant T as EmailTransport / SMTP
    actor K as Khách hàng nhận email
    A->>C: POST Edit voucher, thời gian Việt Nam, token
    C->>C: Chuẩn hóa mã; kiểm tra form và thời gian
    C->>DB: Kiểm tra mã trùng
    alt Dữ liệu không hợp lệ
        C-->>A: Form kèm lỗi
    else Hợp lệ
        C->>C: Đổi thời gian Việt Nam sang UTC
        C->>DB: Lưu Vouchers
        C->>W: Kick
        C-->>A: Đã lưu voucher
    end
    Note over W: Worker còn được kích hoạt khi hoàn thành đơn hoặc đổi lựa chọn nhận tin
    W->>DB: Tìm voucher hiệu lực và khách đủ điều kiện
    Note over W,DB: Khách Active, nhận tin, có ít nhất 3 đơn hoàn thành, chưa dùng voucher
    W->>DB: INSERT VoucherEmails.Pending nếu chưa có cặp khách-voucher
    alt Chưa bật hoặc chưa cấu hình SMTP cho voucher
        Note over W,DB: Giữ thư chờ, chưa đánh dấu Sent
    else Đã sẵn sàng gửi
        W->>DB: Thu hồi khóa Sending quá 10 phút về Pending
        W->>DB: Lấy tối đa 20 thư Pending/Failed đến hạn
        loop Từng thư
            W->>DB: Chiếm thư bằng UPDATE có điều kiện sang Sending
            W->>DB: Kiểm tra lại khách, voucher, nhận tin và lượt dùng
            alt Không còn đủ điều kiện
                W->>DB: Status = Cancelled
            else Còn đủ điều kiện
                W->>T: Gửi email mã giảm giá
                alt SMTP chấp nhận
                    T-->>K: Email ưu đãi
                    W->>DB: Status = Sent; ghi SentAt
                else Gửi lỗi
                    W->>DB: Status = Failed; RetryAfter sau 15 phút
                end
            end
        end
    end
    opt Admin yêu cầu gửi lại thư Failed
        A->>C: POST RetryEmails
        C->>DB: Đưa Failed về Pending; xóa RetryAfter
        C->>W: Kick
    end
    opt Admin ngừng voucher
        A->>C: POST Delete(id)
        C->>DB: Active = false; giữ lịch sử sử dụng
    end
```

## 16. Gửi email thông báo đơn mới cho chủ shop

Mã nguồn: `Global.asax.cs`, `EmailOutboxService`, `OwnerOrderEmailService`.

```mermaid
sequenceDiagram
    autonumber
    participant App as Ứng dụng MVC
    participant W as EmailOutboxService
    participant O as OwnerOrderEmailService
    participant F as Cấu hình SMTP
    participant DB as ShopDb / SQL Server
    participant T as EmailTransport / SMTP
    actor A as Chủ shop
    App->>W: Application_Start gọi Start
    Note over App,W: Timer chạy sau 10 giây và mỗi phút; cũng Kick sau tạo đơn
    W->>W: Chặn hai lượt worker chạy đồng thời trong cùng tiến trình
    W->>O: Process
    O->>F: Đọc bật thông báo đơn, SMTP và email chủ shop
    alt Chưa đủ cấu hình hoặc chưa bật
        O-->>W: Kết thúc; giữ trạng thái thư chờ
    else Cấu hình hợp lệ
        O->>DB: Thu hồi đơn Sending đã hết thời hạn khóa
        O->>DB: Lấy tối đa 20 đơn Pending/Failed đến hạn
        loop Từng đơn
            O->>DB: UPDATE có điều kiện sang Sending, khóa 10 phút
            O->>DB: Đọc Items, Customer và trạng thái mới nhất
            O->>T: Gửi email chi tiết đơn
            alt SMTP chấp nhận thư
                T-->>A: Email đơn hàng mới
                O->>DB: OwnerEmailStatus = Sent; ghi thời gian gửi
            else Gửi lỗi
                O->>DB: OwnerEmailStatus = Failed; thử lại sau 15 phút
            end
            Note over O,DB: Chỉ cập nhật cột email, tránh ghi đè trạng thái đơn và thanh toán
        end
    end
    Note over W,DB: Khi web dừng, dữ liệu hàng đợi vẫn còn trong database
    Note over T,A: SMTP nhận thư chưa đồng nghĩa người nhận đã đọc; retry có thể trùng thư
```

## 17. Cấu hình chuyển khoản QR và SMTP

Mã nguồn: `PaymentSettingsController`, `BankTransferSettingsService`, `EmailSettingsController`, `EmailSettingsService`.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant UI as Trang cấu hình
    participant C as Controller cấu hình
    participant S as Service cấu hình
    participant F as App_Data và thư mục ảnh
    participant T as EmailTransport / SMTP
    A->>UI: Nhập và lưu cấu hình
    UI->>C: POST kèm token và cookie admin
    alt Cấu hình chuyển khoản
        C->>C: Kiểm tra ảnh QR thật, định dạng và dung lượng
        C->>C: Nếu bật phải có ảnh QR
        alt Hợp lệ
            C->>F: Lưu ảnh mới trong Images/Payments
            C->>S: Save bank transfer settings
            S->>F: Ghi bank-transfer.local.config qua file tạm
            C->>F: Xóa ảnh QR cũ nếu đã thay hoặc xóa
            C-->>UI: Đã lưu cấu hình
        else Không hợp lệ hoặc lỗi lưu
            C->>F: Dọn ảnh mới nếu đã ghi mà lưu cấu hình thất bại
            C-->>UI: Form kèm lỗi
        end
    else Cấu hình email
        C->>C: Kiểm tra SMTP, thông tin gửi và email chủ shop
        Note over C,S: Để trống mật khẩu giữ khóa cũ khi thông số SMTP không đổi
        alt Hợp lệ
            C->>S: Save email settings
            S->>S: Mã hóa App Password bằng Windows DPAPI
            S->>F: Lưu smtp.local.config
            opt Bật email voucher hoặc thông báo đơn
                C->>C: Kick email worker
            end
            C-->>UI: Thông báo cấu hình có hiệu lực
        else Sai dữ liệu hoặc lỗi lưu
            C-->>UI: Form kèm lỗi; không hiển thị lại App Password
        end
    end
    opt Admin gửi email kiểm tra
        A->>C: POST EmailSettings/Test với email nhận
        C->>C: Kiểm tra form và thông tin SMTP đã lưu
        C->>T: Gửi thử
        alt SMTP nhận thư
            C-->>UI: Báo đã gửi tới SMTP
        else Gửi lỗi
            C-->>UI: Báo kiểm tra tài khoản và cấu hình
        end
    end
    Note over S,F: Các cấu hình này lưu trong file, không phải bảng SQL
```

## 18. Xem thống kê doanh thu và sản phẩm bán chạy

Mã nguồn: `DashboardController`, `Areas/Admin/Data/DashboardRepository.cs`.

```mermaid
sequenceDiagram
    autonumber
    actor A as Quản trị viên
    participant UI as Dashboard
    participant C as DashboardController
    participant R as DashboardRepository
    participant DB as ShopDb / SQL Server
    A->>UI: Chọn 7, 30, 90 ngày hoặc tất cả
    UI->>C: GET /Admin với range
    C->>R: Load(range)
    R->>R: Chuẩn hóa range; mặc định 30
    R->>R: Tính mốc ngày Việt Nam rồi quy đổi UTC
    R->>DB: Đọc Orders có Status = Hoàn thành theo ngày đặt
    DB-->>R: Tổng tiền và thông tin khách của các đơn
    R->>DB: JOIN OrderItems với các đơn đã lọc
    DB-->>R: Sản phẩm, thương hiệu và số lượng bán
    R->>R: Tính doanh thu, số đơn, số đôi, số khách
    R->>R: Nhóm top 8 sản phẩm theo số đôi
    R->>R: Nhóm thương hiệu, lấy top 6 và nhóm khác
    R->>R: Nhóm khách theo số đôi rồi tổng chi; lấy top 8
    R-->>C: DashboardViewModel
    C-->>UI: Render số liệu, biểu đồ và bảng xếp hạng
    UI-->>A: Kết quả theo khoảng thời gian
    Note over R,DB: Doanh thu là Total đã trừ voucher và gồm phí giao hàng
    Note over R,DB: Tên sản phẩm/thương hiệu lấy từ snapshot OrderItems
```

## Bảng đối chiếu dữ liệu

| Nghiệp vụ | Nơi lưu chính | Ghi chú |
|---|---|---|
| Tài khoản khách | `dbo.Customers` | Mật khẩu hash, trạng thái hoạt động, SecurityStamp |
| Tài khoản quản trị | `dbo.AdminUsers` | DbSet trong C# có tên `Admins` |
| Danh mục / thương hiệu | `dbo.Categories`, `dbo.Brands` | Có trạng thái hiển thị và thứ tự |
| Sản phẩm | `dbo.Products` | Liên kết danh mục, thương hiệu |
| Size và tồn kho | `dbo.Variants` | Mỗi sản phẩm/size là một biến thể; có Revision |
| Ảnh sản phẩm | `dbo.ProductImages` và `Images/Products` | Database lưu đường dẫn, file lưu trên đĩa |
| Giỏ hàng | `Session["cart"]` | Chỉ có VariantId và Quantity; không có bảng giỏ |
| Đơn và dòng đơn | `dbo.Orders`, `dbo.OrderItems` | Lưu thông tin tại thời điểm đặt |
| Voucher và lượt dùng | `dbo.Vouchers`, `dbo.VoucherRedemptions` | Lượt dùng được ghi cùng transaction tạo đơn |
| Email voucher | `dbo.VoucherEmails` | Hàng đợi và trạng thái gửi |
| Email đơn hàng | Các cột `OwnerEmail...` trong `dbo.Orders` | Không phải bảng hàng đợi riêng |
| Banner | `dbo.Banners` và `Images/Banners` | Hiển thị khi Active |
| Cấu hình QR | `App_Data/bank-transfer.local.config`, `Images/Payments` | Xác nhận tiền thủ công |
| Cấu hình SMTP | `App_Data/smtp.local.config` | App Password mã hóa DPAPI |

## Các điểm cần giải thích khi bảo vệ báo cáo

1. **Giỏ hàng và tồn kho khác nhau:** thêm giỏ chỉ ghi Session. Khi đặt đơn mới trừ kho bằng transaction, có Revision để phát hiện thay đổi đồng thời. Kiểm tra trên giao diện giúp khách chọn đúng nhưng server vẫn kiểm tra lại.
2. **Đơn hàng và thanh toán có trạng thái riêng:** ví dụ đơn TRANSFER có thể Chờ xác nhận nhưng Paid sau khi admin đối soát. COD được gán Paid khi hoàn thành.
3. **Áp dụng voucher là hai bước:** xem trước chưa dùng voucher; lúc đặt đơn kiểm tra lại, khóa voucher và ghi lượt dùng cùng đơn. Hủy hợp lệ sẽ xóa lượt dùng.
4. **Khách quen tính theo đơn hoàn thành:** ít nhất 3 đơn, không phải 3 đôi; số đơn được tính từ dữ liệu, không phải một hạng khách nhập tay.
5. **Email chạy nền:** đặt đơn không cần chờ SMTP hoàn tất; hàng đợi vẫn lưu khi web dừng. Bật email cho chủ shop và bật email voucher là hai lựa chọn độc lập.
6. **Tách vai trò:** request /Admin chỉ dùng cookie admin; cửa hàng dùng cookie khách. Khóa tài khoản làm phiên cũ mất hiệu lực ở request kế tiếp.
7. **Những luồng chưa có:** khách tự hủy đơn, API xác nhận chuyển khoản, tự động hoàn tiền và API giao vận. Không nên thêm các bước đó vào biểu đồ mô tả phiên bản hiện tại.

## Cách sử dụng tài liệu

Các khối `mermaid` có thể hiển thị trong trình xem Markdown hỗ trợ Mermaid. Thư mục `sequence-diagrams` chứa từng sơ đồ `.mmd` riêng để chỉnh sửa, render hoặc xuất SVG/PNG bằng công cụ Mermaid. Đặt mỗi biểu đồ ở một mục hoặc một trang riêng trong báo cáo; không ghép 18 luồng vào một hình vì sẽ khó đọc.
