param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$suffix=[guid]::NewGuid().ToString('N').Substring(0,8)
$email="e2e-$suffix@example.invalid";$otherEmail="e2e-other-$suffix@example.invalid";$password='CustomerTest!2026'
$admin=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$other=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$anonymous=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Normalize($r){[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);Status=[int]$r.StatusCode;Path=$r.BaseResponse.RequestMessage.RequestUri.AbsolutePath}}
function Fetch($path,$session){$r=Invoke-WebRequest ($BaseUrl+$path) -WebSession $session -SkipHttpErrorCheck;if($r.StatusCode -ge 500){$r.Content|Set-Content (Join-Path $workspace '.local/e2e-error.html');throw "Server error at $path; see .local/e2e-error.html"};Normalize $r}
function Send($path,$body,$page,$session,[switch]$Multipart){$body=$body.Clone();$body['__RequestVerificationToken']=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;if(!$body['__RequestVerificationToken']){throw "Missing CSRF token at $path"};if($Multipart){$r=Invoke-WebRequest ($BaseUrl+$path) -Method Post -Form $body -WebSession $session -SkipHttpErrorCheck}else{$r=Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $body -WebSession $session -SkipHttpErrorCheck};if($r.StatusCode -ge 500){$r.Content|Set-Content (Join-Path $workspace '.local/e2e-error.html');throw "Server error at $path; see .local/e2e-error.html"};Normalize $r}
function Check($ok,$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
function Status($code,$status){$page=Fetch '/Admin/Products/Orders' $admin;$id=[regex]::Match($page.Content,'(?s)#'+$code+'.*?name="id" value="(\d+)"').Groups[1].Value;if(!$id){throw "Order not found: $code"};Send '/Admin/Products/Status' @{id=$id;status=$status} $page $admin}
function FillCart($session){$detail=Fetch "/Home/Product/$script:productId" $session;$variant=[regex]::Match($detail.Content,'name="variantId" value="(\d+)"').Groups[1].Value;Send '/Cart/Add' @{variantId=$variant;quantity=1} $detail $session}
function Checkout($voucher=''){$page=Fetch '/Cart/Checkout' $customer;Send '/Cart/Checkout' @{CustomerName="E2E $suffix";Phone='0900000000';Address='123 Test Street, Test City';Note="E2E_TEST_$suffix";VoucherCode=$voucher} $page $customer}
$cleanup=@"
USE ShopGiay;
DELETE FROM VoucherEmails WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email IN(N'$email',N'$otherEmail')) OR VoucherId IN(SELECT Id FROM Vouchers WHERE Code=N'E2E$suffix');
DELETE FROM VoucherRedemptions WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email IN(N'$email',N'$otherEmail')) OR VoucherId IN(SELECT Id FROM Vouchers WHERE Code=N'E2E$suffix');
DELETE FROM OrderItems WHERE OrderId IN(SELECT Id FROM Orders WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email IN(N'$email',N'$otherEmail')));
DELETE FROM Orders WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email IN(N'$email',N'$otherEmail'));
DELETE FROM Customers WHERE Email IN(N'$email',N'$otherEmail');
DELETE FROM Vouchers WHERE Code=N'E2E$suffix';
DELETE FROM Products WHERE Name=N'E2E_PRODUCT_$suffix';
DELETE FROM Banners WHERE Title=N'E2E_BANNER_$suffix';
"@
$cleanupFile=Join-Path $workspace ".local/e2e-cleanup-$suffix.sql";$cleanup|Set-Content $cleanupFile -Encoding utf8BOM
Write-Host "Cleanup script: $cleanupFile"
$page=Fetch '/Admin/Account/Login' $admin
$page=Send '/Admin/Account/Login' @{Email='admin@shopgiay.vn';Password='admin@123'} $page $admin
Check ($page.Path -eq '/Admin') 'Admin password changed to requested password'
Check ($page.Content.Contains('Dashboard thống kê') -and $page.Content.Contains('Giày bán chạy') -and $page.Content.Contains('Thương hiệu bán chạy')) 'Admin opens dashboard by default'
$page=Fetch '/Admin/Users' $anonymous
Check ($page.Path -eq '/Admin/Account/Login') 'Users management is protected'
$edit=Fetch '/Admin/Products/Edit' $admin
$brandId=[regex]::Match($edit.Content,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
$created=Send '/Admin/Products/Edit/0' @{Name="E2E_PRODUCT_$suffix";BrandId=$brandId;Color='Đen';Price='100000';Active='true';'Variants[0].Size'='40';'Variants[0].Stock'='10'} $edit $admin
$script:productId=[regex]::Match($created.Content,'(?s)E2E_PRODUCT_'+$suffix+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
Check (!!$script:productId) 'Create isolated test product'
$cart=FillCart $anonymous
$page=Fetch '/Cart/Checkout' $anonymous
Check ($page.Path -eq '/Account/Login') 'Checkout requires customer login'
$register=Fetch '/Account/Register' $customer
$page=Send '/Account/Register' @{Name="E2E Customer $suffix";Email=$email;Password=$password;ConfirmPassword='wrong'} $register $customer
Check ($page.Content.Contains('Mật khẩu xác nhận chưa khớp')) 'Registration validates matching passwords'
$page=Send '/Account/Register' @{Name="E2E Customer $suffix";Email=$email;Password=$password;ConfirmPassword=$password;ReceiveVoucherEmails='false'} $register $customer
Check ($page.Path -eq '/Account' -and $page.Content.Contains($email)) 'Customer registration and login'
$page=Fetch '/Admin/Users' $customer
Check ($page.Path -eq '/Admin/Account/Login') 'Customer is redirected to admin login without access'
$register=Fetch '/Account/Register' $other
$page=Send '/Account/Register' @{Name="E2E Other $suffix";Email=$otherEmail;Password=$password;ConfirmPassword=$password;ReceiveVoucherEmails='false'} $register $other
Check ($page.Path -eq '/Account') 'Second customer has independent account'
$voucherEdit=Fetch '/Admin/Vouchers/Edit' $admin
$local=(Get-Date).ToUniversalTime().AddHours(7)
$voucherBody=@{Code="E2E$suffix";Percent='10';MinimumSubtotal='0';StartsLocal=$local.AddDays(-1).ToString('yyyy-MM-ddTHH:mm');EndsLocal=$local.AddDays(5).ToString('yyyy-MM-ddTHH:mm');Active='true'}
$bad=$voucherBody.Clone();$bad.Percent='101'
$page=Send '/Admin/Vouchers/Edit/0' $bad $voucherEdit $admin
Check ($page.Content.Contains('validation-summary-errors')) 'Voucher validates discount percent'
$page=Send '/Admin/Vouchers/Edit/0' $voucherBody $voucherEdit $admin
$code=$voucherBody.Code.ToUpperInvariant()
Check ($page.Content.Contains($code)) 'Admin creates voucher with percent and code'
$voucherId=[regex]::Match($page.Content,'(?s)'+$code+'.*?href="/Admin/Vouchers/Edit/(\d+)"').Groups[1].Value
for($i=1;$i -le 3;$i++){
 $cart=FillCart $customer
 if($i -eq 1){$checkout=Fetch '/Cart/Checkout' $customer;$preview=Send '/Cart/Checkout' @{VoucherCode=$code;applyVoucher='true'} $checkout $customer;Check ($preview.Content.Contains('ít nhất 3 đơn đã hoàn thành')) 'New customer cannot redeem loyal voucher'}
 $complete=Checkout
 Check ($complete.Content.Contains('Đặt hàng thành công')) "Customer order $i is created"
 $orderCode=[regex]::Match($complete.Content,'<strong>([A-F0-9]{10})</strong>').Groups[1].Value
 if($i -eq 1){$firstCode=$orderCode;$private=Fetch "/Cart/Complete?code=$orderCode" $other;Check ($private.Status -eq 404) 'Customer cannot read another customer order'}
 $page=Status $orderCode 'Đã xác nhận';$page=Status $orderCode 'Đang giao';$page=Status $orderCode 'Hoàn thành'
 $account=Fetch '/Account' $customer
 if($i -eq 2){Check (!$account.Content.Contains('class="voucher-card"')) 'Two completed orders do not yet qualify'}
}
$account=Fetch '/Account' $customer
Check ($account.Content.Contains('Khách quen') -and $account.Content.Contains($code)) 'Third completed order unlocks loyal vouchers'
$dashboard=Fetch '/Admin?range=all' $admin
Check ($dashboard.Content -match ('data-product-id="'+$script:productId+'" data-units="3"')) 'Dashboard counts three completed product sales'
$users=Fetch ('/Admin/Users?q='+$email) $admin
Check ($users.Content.Contains('Khách quen')) 'Admin user list shows loyal status'
$customerId=[regex]::Match($users.Content,'href="/Admin/Users/Details/(\d+)"').Groups[1].Value
Check ($dashboard.Content -match ('data-customer-id="'+$customerId+'" data-units="3"')) 'Dashboard ranks customer by pairs purchased'
Check ($dashboard.Content.Contains('<svg') -and $dashboard.Content.Contains('stroke-dasharray')) 'Brand chart renders from completed sales'
$preference=Send '/Account/EmailPreference' @{receiveVoucherEmails='true'} $account $customer
for($attempt=0;$attempt -lt 10;$attempt++){$emails=Fetch '/Admin/Vouchers/Emails' $admin;if($emails.Content.Contains($email)){break};Start-Sleep -Milliseconds 200}
Check ($emails.Content.Contains($email) -and $emails.Content.Contains($code)) 'Loyal customer email notification is queued'
Check ($emails.Content.Contains('Chưa có cấu hình Gmail') -and $emails.Content.Contains('Pending')) 'No email is falsely marked sent without Gmail credentials'
$emails=Send '/Admin/Vouchers/RetryEmails' @{} $emails $admin
$emails=Fetch '/Admin/Vouchers/Emails' $admin
Check ((@([regex]::Matches($emails.Content,'(?s)<tr>.*?</tr>')|Where-Object {$_.Value.Contains($email) -and $_.Value.Contains($code)})).Count -eq 1) 'Email notifications are deduplicated per customer and voucher'
$cart=FillCart $customer;$checkout=Fetch '/Cart/Checkout' $customer
$preview=Send '/Cart/Checkout' @{VoucherCode=$code;applyVoucher='true'} $checkout $customer
Check ($preview.Content.Contains('10.000') -and $preview.Content.Contains('125.000')) 'Server computes 10 percent discount and preserves shipping'
$complete=Checkout $code
Check ($complete.Content.Contains('Đặt hàng thành công') -and $complete.Content.Contains('125.000')) 'Loyal customer places discounted order'
$discountedCode=[regex]::Match($complete.Content,'<strong>([A-F0-9]{10})</strong>').Groups[1].Value
$cart=FillCart $customer;$checkout=Fetch '/Cart/Checkout' $customer
$preview=Send '/Cart/Checkout' @{VoucherCode=$code;applyVoucher='true'} $checkout $customer
Check ($preview.Content.Contains('Bạn đã sử dụng voucher này')) 'Voucher cannot be reused by same account'
$page=Status $discountedCode 'Đã hủy'
$dashboard=Fetch '/Admin?range=all' $admin
Check ($dashboard.Content -match ('data-product-id="'+$script:productId+'" data-units="3"')) 'Cancelled orders excluded from charts'
$preview=Send '/Cart/Checkout' @{VoucherCode=$code;applyVoucher='true'} $checkout $customer
Check ($preview.Content.Contains('125.000')) 'Cancelling order restores voucher use'
$page=Fetch '/Admin/Vouchers' $admin;$page=Send '/Admin/Vouchers/Delete' @{id=$voucherId} $page $admin
$preview=Send '/Cart/Checkout' @{VoucherCode=$code;applyVoucher='true'} $checkout $customer
Check ($preview.Content.Contains('đã hết hạn')) 'Deactivated voucher is rejected'
$page=Fetch '/Admin/Users' $admin;$page=Send '/Admin/Users/SetActive' @{id=$customerId;active='false'} $page $admin
$account=Fetch '/Account' $customer
Check ($account.Path -eq '/Account/Login') 'Disabling account invalidates existing customer session'
$login=Fetch '/Account/Login' $customer;$account=Send '/Account/Login' @{Email=$email;Password=$password} $login $customer
Check ($account.Content.Contains('tài khoản đã bị khóa')) 'Disabled customer cannot log in'
$page=Fetch '/Admin/Users' $admin;$page=Send '/Admin/Users/SetActive' @{id=$customerId;active='true'} $page $admin
$login=Fetch '/Account/Login' $customer;$account=Send '/Account/Login' @{Email=$email;Password=$password} $login $customer
Check ($account.Path -eq '/Account') 'Reenabled account can log in'
$bannerEdit=Fetch '/Admin/Banners/Edit' $admin
$bannerFixture=Join-Path $workspace ".local/e2e-banner-$suffix.png"
Add-Type -AssemblyName System.Drawing
$bitmap=New-Object System.Drawing.Bitmap 32,16
try{$bitmap.Save($bannerFixture,[System.Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
$bannerBody=@{Title="E2E_BANNER_$suffix";Subtitle='Nội dung do admin chỉnh sửa';ButtonText='Mua ngay';LinkUrl='/';SortOrder='0';Active='true'}
$bannerBody.imageFile=Get-Item $bannerFixture
$page=Send '/Admin/Banners/Edit/0' $bannerBody $bannerEdit $admin -Multipart
Check ($page.Content.Contains($bannerBody.Title)) 'Admin creates banner'
$bannerId=[regex]::Match($page.Content,'(?s)'+$bannerBody.Title+'.*?href="/Admin/Banners/Edit/(\d+)"').Groups[1].Value
$store=Fetch '/' $anonymous
Check ($store.Content.Contains($bannerBody.Title) -and !$store.Content.Contains('CHẤT RIÊNG.<br/>')) 'Homepage uses admin banner instead of fixed hero'
$bannerUrl=[regex]::Match($store.Content,'src="(/Images/Banners/[^"]+)"').Groups[1].Value
Check (!!$bannerUrl -and (Fetch $bannerUrl $anonymous).Status -eq 200) 'Banner image uploaded and served'
$bannerEdit=Fetch "/Admin/Banners/Edit/$bannerId" $admin;$bannerBody.Active='false'
$page=Send "/Admin/Banners/Edit/$bannerId" $bannerBody $bannerEdit $admin
$store=Fetch '/' $anonymous
Check (!$store.Content.Contains($bannerBody.Title)) 'Admin can hide banner'
$page=Fetch '/Admin/Banners' $admin;$page=Send '/Admin/Banners/Delete' @{id=$bannerId} $page $admin
Check (!$page.Content.Contains($bannerBody.Title)) 'Admin can delete banner'
Check (!(Test-Path -LiteralPath (Join-Path (Join-Path $workspace 'shopgiay') $bannerUrl.TrimStart('/')))) 'Deleted banner image file is removed'
$page=Fetch '/Admin/Products' $admin;$page=Send '/Admin/Products/Delete' @{id=$script:productId} $page $admin
Write-Host 'All account/voucher/banner checks passed.'
Write-Host "Run the isolated cleanup script with DatabaseSetup --run-sql: $cleanupFile"


