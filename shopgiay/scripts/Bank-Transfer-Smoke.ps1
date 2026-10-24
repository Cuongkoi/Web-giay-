param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$handler=[Net.Http.HttpClientHandler]::new();$handler.AllowAutoRedirect=$false;$handler.UseProxy=$false;$handler.CookieContainer=[Net.CookieContainer]::new();$http=[Net.Http.HttpClient]::new($handler)
function Req($path,$body=$null,$follow=$true){
 $url=if($path.StartsWith('http')){$path}else{$BaseUrl+$path}
 if($body){$pairs=[Collections.Generic.Dictionary[string,string]]::new();foreach($k in $body.Keys){$pairs[$k]=[string]$body[$k]};$content=[Net.Http.FormUrlEncodedContent]::new($pairs);$res=$http.PostAsync($url,$content).GetAwaiter().GetResult()}else{$res=$http.GetAsync($url).GetAwaiter().GetResult()}
 $text=[Net.WebUtility]::HtmlDecode($res.Content.ReadAsStringAsync().GetAwaiter().GetResult());$loc=[string]$res.Headers.Location
 if([int]$res.StatusCode -ge 500){$text|Set-Content (Join-Path $root '.local/payment-error.html');throw "HTTP 500 $path"}
 if($follow -and $loc){if($loc.StartsWith('http') -and !($loc.StartsWith($BaseUrl))){throw 'Unexpected external request blocked by test'};return Req $loc}
 [pscustomobject]@{Text=$text;Location=$loc;Status=[int]$res.StatusCode;Path=([uri]$url).AbsolutePath}
}
function Post($path,$body,$page,$follow=$true){$body=$body.Clone();$body.__RequestVerificationToken=[regex]::Match($page.Text,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;Req $path $body $follow}
$count=0
function Check($ok,$label){if(!$ok){throw "FAIL: $label"};$script:count++;Write-Host "PASS: $label"}

$bankPath=Join-Path $root 'shopgiay/App_Data/bank-transfer.local.config';$smtpPath=Join-Path $root 'shopgiay/App_Data/smtp.local.config'
$bankOriginal=if(Test-Path $bankPath){[IO.File]::ReadAllBytes($bankPath)}else{$null};$smtpOriginal=if(Test-Path $smtpPath){[IO.File]::ReadAllBytes($smtpPath)}else{$null}
$imagesBefore=@(Get-ChildItem (Join-Path $root 'shopgiay/Images/Payments') -ErrorAction SilentlyContinue|ForEach-Object Name)
$testQr=[Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6V7sAAAAASUVORK5CYII=')
function Upload($page,$bytes,$filename,$enabled='true'){
 $form=[Net.Http.MultipartFormDataContent]::new()
 foreach($entry in @{Enabled=$enabled;BankName='TEST BANK';AccountNumber='123456789';AccountHolder='TEST OWNER';__RequestVerificationToken=[regex]::Match($page.Text,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value}.GetEnumerator()){$form.Add([Net.Http.StringContent]::new([string]$entry.Value),$entry.Key)}
 $image=[Net.Http.ByteArrayContent]::new($bytes);$image.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::new('image/png');$form.Add($image,'qrFile',$filename)
 $response=$http.PostAsync($BaseUrl+'/Admin/PaymentSettings',$form).GetAwaiter().GetResult();$text=[Net.WebUtility]::HtmlDecode($response.Content.ReadAsStringAsync().GetAwaiter().GetResult());$location=[string]$response.Headers.Location;$form.Dispose()
 if([int]$response.StatusCode -ge 500){$text|Set-Content (Join-Path $root '.local/bank-error.html');throw 'Upload server error'}
 if($location){return Req $location};[pscustomobject]@{Text=$text;Status=[int]$response.StatusCode;Path='/Admin/PaymentSettings'}
}
try{
 if($bankOriginal){Remove-Item -LiteralPath $bankPath}
 if($smtpOriginal){$smtp=[xml]([Text.Encoding]::UTF8.GetString($smtpOriginal).TrimStart([char]0xfeff));foreach($key in @('Smtp.Enabled','Smtp.OrderNotificationsEnabled')){$entry=$smtp.appSettings.add|Where-Object key -eq $key;if($entry){$entry.value='false'}};$smtp.Save($smtpPath)}
 $login=Req '/Admin/Account/Login';$admin=Post '/Admin/Account/Login' @{Email='admin@shopgiay.vn';Password='admin@123'} $login
 $settings=Req '/Admin/PaymentSettings';Check ($settings.Text.Contains('Ảnh QR thanh toán') -and !$settings.Text.Contains('HashSecret')) 'Bank QR settings replace VNPay settings'
 $bad=Post '/Admin/PaymentSettings' @{Enabled='true'} $settings;Check ($bad.Text.Contains('tải ảnh QR trước')) 'Cannot enable bank transfer without QR'
 $settings=Upload $settings $testQr 'qr.png';Check ($settings.Text.Contains('Đã lưu cấu hình chuyển khoản')) 'Admin uploads QR image'
 $qr=[regex]::Match($settings.Text,'src="(/Images/Payments/[a-f0-9]+\.png)"').Groups[1].Value;Check (!!$qr) 'Uploaded QR uses a safe generated URL'
 $img=Req $qr;Check ($img.Status -eq 200) 'QR image accessible locally'
 $bad=Upload $settings ([Text.Encoding]::UTF8.GetBytes('not-an-image')) 'invalid.png';Check ($bad.Text.Contains('không hợp lệ')) 'Fake image upload rejected'
 $settings=Req '/Admin/PaymentSettings';Check ($settings.Text.Contains($qr)) 'Invalid upload preserves current QR'
 $suffix=[guid]::NewGuid().ToString('N').Substring(0,10);$name="BANK-TEST-$suffix";$user="bank-$suffix@example.invalid"
 @"
USE ShopGiay;
DECLARE @ids TABLE(Id int); INSERT INTO @ids SELECT Id FROM Orders WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email=N'$user');
DELETE FROM VoucherRedemptions WHERE OrderId IN(SELECT Id FROM @ids);
DELETE FROM OrderItems WHERE OrderId IN(SELECT Id FROM @ids);
DELETE FROM Orders WHERE Id IN(SELECT Id FROM @ids);
DELETE FROM VoucherEmails WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email=N'$user');
DELETE FROM Customers WHERE Email=N'$user';
DELETE FROM Products WHERE Name=N'$name';
"@|Set-Content (Join-Path $root '.local/bank-smoke-cleanup.sql') -Encoding utf8BOM
 $edit=Req '/Admin/Products/Edit';$brand=[regex]::Match($edit.Text,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
 $products=Post '/Admin/Products/Edit/0' @{Name=$name;BrandId=$brand;Color='Đen';Price='100000';Active='true';'Variants[0].Size'='40';'Variants[0].Stock'='20'} $edit
 $id=[regex]::Match($products.Text,'(?s)'+$name+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value;Check (!!$id) 'Isolated test product created'
 $register=Req '/Account/Register';$account=Post '/Account/Register' @{Name=$name;Email=$user;Password='TestCustomer!2026';ConfirmPassword='TestCustomer!2026';ReceiveVoucherEmails='false'} $register
 $detail=Req "/Home/Product/$id";$variant=[regex]::Match($detail.Text,'name="variantId" value="(\d+)"').Groups[1].Value
 function AddCart{$detail=Req "/Home/Product/$id";$null=Post '/Cart/Add' @{variantId=$variant;quantity=1} $detail;Req '/Cart/Checkout'}
 $checkout=AddCart;Check ($checkout.Text.Contains('value="TRANSFER"') -and $checkout.Text.Contains('value="COD"') -and !$checkout.Text.Contains('VNPAY')) 'Checkout only offers transfer and COD'
 Check ($checkout.Text.Contains($qr) -and $checkout.Text.Contains('tên khách hàng và mã đơn hàng')) 'Checkout contains QR preview and transfer instructions'
 $bad=Post '/Cart/Checkout' @{PaymentMethod='VNPAY';CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout
 Check ($bad.Text.Contains('Phương thức thanh toán không hợp lệ')) 'Old VNPay requests rejected'
 $order=Post '/Cart/Checkout' @{PaymentMethod='TRANSFER';CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout
 $code=[regex]::Match($order.Text,'Mã đơn hàng của bạn: <strong>([A-Z0-9]+)').Groups[1].Value
 Check (!!$code -and $order.Text.Contains('Chuyển khoản ngân hàng')) 'Transfer order saved locally without external redirect'
 Check ($order.Text.Contains($name+' '+$code) -and $order.Text.Contains($qr) -and $order.Text.Contains('135.000')) 'Order displays QR, amount and exact customer/order transfer memo'
 Check ($order.Text.Contains('Chưa thanh toán')) 'Transfer is not automatically marked paid'
 $orders=Req '/Admin/Products/Orders';$pattern='(?s)<article class="order-panel">(?:(?!</article>).)*#'+$code+'(?:(?!</article>).)*</article>';$panel=[regex]::Match($orders.Text,$pattern).Value;$orderId=[regex]::Match($panel,'name="id" value="(\d+)"').Groups[1].Value
 Check ($panel.Contains('Xác nhận đã nhận tiền')) 'Admin has manual receipt confirmation'
 $blocked=Post '/Admin/Products/Status' @{id=$orderId;status='Đã xác nhận'} $orders;Check ($blocked.Text.Contains('Chưa xác nhận nhận tiền')) 'Cannot dispatch unpaid transfer order'
 $paid=Post '/Admin/Products/ConfirmTransfer' @{id=$orderId} $orders;Check ($paid.Text.Contains('Đã xác nhận nhận tiền chuyển khoản')) 'Admin confirms received transfer'
 $order=Req ('/Cart/Complete?code='+$code);Check ($order.Text.Contains('Đã thanh toán') -and !$order.Text.Contains('class="transfer-instructions"')) 'Paid order hides payment request'
 $repeat=Post '/Admin/Products/ConfirmTransfer' @{id=$orderId} $paid;Check ($repeat.Text.Contains('trước đó')) 'Repeated receipt confirmation is safe'
 $settings=Upload (Req '/Admin/PaymentSettings') $testQr 'replacement.png';$newQr=[regex]::Match($settings.Text,'src="(/Images/Payments/[a-f0-9]+\.png)"').Groups[1].Value
 Check (!!$newQr -and $newQr -ne $qr) 'Admin can replace QR'
 $checkout=AddCart;$cod=Post '/Cart/Checkout' @{PaymentMethod='COD';CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout
 Check ($cod.Text.Contains('Thanh toán khi nhận hàng (COD)') -and !$cod.Text.Contains('class="transfer-instructions"')) 'COD continues without QR instructions'
 $disabled=Post '/Admin/PaymentSettings' @{Enabled='false';removeQr='true'} $settings
 Check (!$disabled.Text.Contains('QR chuyển khoản hiện tại')) 'Admin can disable and remove QR'
 $checkout=AddCart;$bad=Post '/Cart/Checkout' @{PaymentMethod='TRANSFER';CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout
 Check ($bad.Text.Contains('Chuyển khoản chưa sẵn sàng')) 'Server rejects transfer when no QR configured'
 $admin=Req '/Admin';$null=Post '/Admin/Account/Logout' @{} $admin
 $customer=Req '/Admin/PaymentSettings';Check ($customer.Path -eq '/Admin/Account/Login') 'Customer cannot configure bank account'
 $blocked=Post '/Admin/Products/ConfirmTransfer' @{id=$orderId} $checkout;Check ($blocked.Path -eq '/Admin/Account/Login') 'Customer cannot confirm their own transfer'
 Write-Host "$count bank transfer checks passed. No real email or bank transaction."
}finally{
 if($null -ne $bankOriginal){[IO.File]::WriteAllBytes($bankPath,$bankOriginal)}elseif(Test-Path $bankPath){Remove-Item -LiteralPath $bankPath}
 if($null -ne $smtpOriginal){[IO.File]::WriteAllBytes($smtpPath,$smtpOriginal)}elseif(Test-Path $smtpPath){Remove-Item -LiteralPath $smtpPath}
 Get-ChildItem (Join-Path $root 'shopgiay/Images/Payments') -ErrorAction SilentlyContinue|Where-Object {$_.Name -notin $imagesBefore}|ForEach-Object {Remove-Item -LiteralPath $_.FullName}
 $http.Dispose();$handler.Dispose()
}
