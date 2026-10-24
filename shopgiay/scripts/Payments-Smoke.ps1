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
$paymentPath=Join-Path $root 'shopgiay/App_Data/vnpay.local.config';$smtpPath=Join-Path $root 'shopgiay/App_Data/smtp.local.config'
$paymentOriginal=if(Test-Path $paymentPath){[IO.File]::ReadAllBytes($paymentPath)}else{$null};$smtpOriginal=if(Test-Path $smtpPath){[IO.File]::ReadAllBytes($smtpPath)}else{$null}
# Never contact a payment gateway or send real email in this smoke test.
try{
 if($smtpOriginal){$smtp=[xml]([Text.Encoding]::UTF8.GetString($smtpOriginal).TrimStart([char]0xfeff));foreach($key in @('Smtp.Enabled','Smtp.OrderNotificationsEnabled')){$entry=$smtp.appSettings.add|Where-Object key -eq $key;if($entry){$entry.value='false'}};$smtp.Save($smtpPath)}
 $login=Req '/Admin/Account/Login';$admin=Post '/Admin/Account/Login' @{Email='admin@shopgiay.vn';Password='admin@123'} $login
 $settings=Req '/Admin/PaymentSettings';Check ($settings.Text.Contains('HashSecret')) 'Admin VNPay configuration renders'
 $email=Req '/Admin/EmailSettings';Check ($email.Text.Contains('OwnerEmail') -and $email.Text.Contains('OrderNotificationsEnabled')) 'Owner email settings render'
 $settings=Post '/Admin/PaymentSettings' @{Enabled='true';Sandbox='true';TmnCode='TEST1234';HashSecret='smoke-test-secret-not-real';PublicBaseUrl='https://shop.example.invalid'} $settings
 Check ($settings.Text.Contains('Đã lưu cấu hình VNPay')) 'VNPay test settings saved'
 Check (!(Get-Content $paymentPath -Raw).Contains('smoke-test-secret-not-real')) 'HashSecret encrypted at rest'
 Check (!$settings.Text.Contains('smoke-test-secret-not-real')) 'HashSecret never reflected in HTML'
 $bad=Post '/Admin/PaymentSettings' @{Enabled='true';Sandbox='true';TmnCode='TEST1234';PublicBaseUrl='http://192.168.41.103:5188'} $settings
 Check ($bad.Text.Contains('HTTPS công khai')) 'Invalid callback base URL rejected'
 $suffix=[guid]::NewGuid().ToString('N').Substring(0,10);$name="PAYMENT-TEST-$suffix";$user="payment-$suffix@example.invalid"
 @"
USE ShopGiay;
DECLARE @ids TABLE(Id int); INSERT INTO @ids SELECT Id FROM Orders WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email=N'$user');
DELETE FROM VoucherRedemptions WHERE OrderId IN(SELECT Id FROM @ids);
DELETE FROM OrderItems WHERE OrderId IN(SELECT Id FROM @ids);
DELETE FROM Orders WHERE Id IN(SELECT Id FROM @ids);
DELETE FROM VoucherEmails WHERE CustomerId IN(SELECT Id FROM Customers WHERE Email=N'$user');
DELETE FROM Customers WHERE Email=N'$user';
DELETE FROM Products WHERE Name=N'$name';
"@|Set-Content (Join-Path $root '.local/payment-smoke-cleanup.sql') -Encoding utf8BOM
 $edit=Req '/Admin/Products/Edit';$brand=[regex]::Match($edit.Text,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
 $products=Post '/Admin/Products/Edit/0' @{Name=$name;BrandId=$brand;Color='Đen';Price='100000';Active='true';'Variants[0].Size'='40';'Variants[0].Stock'='20'} $edit
 $id=[regex]::Match($products.Text,'(?s)'+$name+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
 Check (!!$id) 'Isolated product created'
 $register=Req '/Account/Register';$account=Post '/Account/Register' @{Name=$name;Email=$user;Password='TestCustomer!2026';ConfirmPassword='TestCustomer!2026';ReceiveVoucherEmails='false'} $register
 Check ($account.Text.Contains($user)) 'Customer account registered separately from admin'
 $detail=Req "/Home/Product/$id";$variant=[regex]::Match($detail.Text,'name="variantId" value="(\d+)"').Groups[1].Value
 function AddCart{$detail=Req "/Home/Product/$id";$null=Post '/Cart/Add' @{variantId=$variant;quantity=1} $detail;Req '/Cart/Checkout'}
 function Checkout($method){$checkout=AddCart;Post '/Cart/Checkout' @{PaymentMethod=$method;CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout $false}
 $checkout=AddCart;Check ($checkout.Text.Contains('value="COD"') -and $checkout.Text.Contains('value="VNPAY"')) 'Checkout renders both payment methods'
 $bad=Post '/Cart/Checkout' @{PaymentMethod='FAKE';CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout
 Check ($bad.Text.Contains('Phương thức thanh toán không hợp lệ')) 'Unknown payment method rejected'
 $cod=Post '/Cart/Checkout' @{PaymentMethod='COD';CustomerName=$name;Phone='0900000000';Address='123 Test Street, Test City'} $checkout
 Check ($cod.Text.Contains('Đã ghi nhận đơn hàng') -and $cod.Text.Contains('COD')) 'COD order still works'
 $orderPage=Req '/Admin/Products/Orders';Check ($orderPage.Text.Contains($name) -and $orderPage.Text.Contains('Đang chờ gửi')) 'New order has persistent pending owner notification'
 $vn=Checkout 'VNPAY';Check ($vn.Status -eq 302 -and $vn.Location.StartsWith('https://sandbox.vnpayment.vn/')) 'VNPay checkout redirects to sandbox without visiting it'
 $gateway=[uri]$vn.Location;$query=@{};foreach($part in $gateway.Query.TrimStart('?').Split('&')){$kv=$part.Split('=',2);$query[[Net.WebUtility]::UrlDecode($kv[0])]=[Net.WebUtility]::UrlDecode($kv[1])}
 Check ($query.vnp_Amount -eq '13500000') 'Amount is calculated by server and multiplied by 100'
 Check ($query.vnp_ReturnUrl -eq 'https://shop.example.invalid/Payment/Return') 'Configured return URL used, not request Host header'
 function Signed($values){$sorted=[Collections.Generic.SortedDictionary[string,string]]::new([StringComparer]::Ordinal);foreach($k in $values.Keys){$sorted[$k]=[string]$values[$k]};$raw=($sorted.GetEnumerator()|ForEach-Object{[Net.WebUtility]::UrlEncode($_.Key)+'='+[Net.WebUtility]::UrlEncode($_.Value)}) -join '&';$h=[Security.Cryptography.HMACSHA512]::new([Text.Encoding]::UTF8.GetBytes('smoke-test-secret-not-real'));$sig=[Convert]::ToHexString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($raw))).ToLowerInvariant();$h.Dispose();$raw+'&vnp_SecureHash='+$sig}
 $values=@{vnp_TxnRef=$query.vnp_TxnRef;vnp_TmnCode='TEST1234';vnp_Amount=$query.vnp_Amount;vnp_ResponseCode='00';vnp_TransactionStatus='00';vnp_TransactionNo='123456789';vnp_OrderInfo='Thanh toan don hang: kiểm tra'}
 $bad=Req '/Payment/Ipn?vnp_TxnRef=bad&vnp_SecureHash=00';Check (($bad.Text|ConvertFrom-Json).RspCode -eq '97') 'Invalid IPN signature rejected'
 $wrong=$values.Clone();$wrong.vnp_Amount='100';$result=Req ('/Payment/Ipn?'+(Signed $wrong));Check (($result.Text|ConvertFrom-Json).RspCode -eq '04') 'Signed callback with wrong amount rejected'
 $wrong=$values.Clone();$wrong.vnp_TmnCode='OTHER123';$result=Req ('/Payment/Ipn?'+(Signed $wrong));Check (($result.Text|ConvertFrom-Json).RspCode -eq '04') 'Signed callback with wrong merchant rejected'
 $wrong=$values.Clone();$wrong.vnp_TxnRef='DOESNOTEXIST';$result=Req ('/Payment/Ipn?'+(Signed $wrong));Check (($result.Text|ConvertFrom-Json).RspCode -eq '01') 'Unknown order rejected'
 $return=Req ('/Payment/Return?'+(Signed $values));Check ($return.Text.Contains('Chưa thanh toán')) 'Browser return cannot mark order paid'
 $orders=Req '/Admin/Products/Orders';$pattern='(?s)<article class="order-panel">(?:(?!</article>).)*#'+$query.vnp_TxnRef+'(?:(?!</article>).)*</article>';$panel=[regex]::Match($orders.Text,$pattern).Value;$orderId=[regex]::Match($panel,'name="id" value="(\d+)"').Groups[1].Value
 Check (!!$orderId) 'VNPay order visible in admin'
 $blocked=Post '/Admin/Products/Status' @{id=$orderId;status='Đã xác nhận'} $orders
 Check ($blocked.Text.Contains('Chưa xác nhận thanh toán VNPay')) 'Unpaid VNPay order cannot be confirmed for shipping'
 $result=Req ('/Payment/Ipn?'+(Signed $values));Check (($result.Text|ConvertFrom-Json).RspCode -eq '00') 'Valid IPN accepts payment'
 $complete=Req ('/Cart/Complete?code='+$query.vnp_TxnRef);Check ($complete.Text.Contains('Đã thanh toán')) 'Confirmed payment visible to customer'
 $result=Req ('/Payment/Ipn?'+(Signed $values));Check (($result.Text|ConvertFrom-Json).RspCode -eq '02') 'Repeated IPN is idempotent'
 $dup=Req ('/Payment/Ipn?'+(Signed $values)+'&vnp_Amount=13500000');Check (($dup.Text|ConvertFrom-Json).RspCode -eq '97') 'Duplicate query parameters rejected'
 $orders=Req '/Admin/Products/Orders';$blocked=Post '/Admin/Products/Status' @{id=$orderId;status='Đã hủy'} $orders
 Check ($blocked.Text.Contains('chưa hỗ trợ hoàn tiền tự động')) 'Paid order cancellation blocked pending refund handling'
 $failed=Checkout 'VNPAY';$failureQuery=@{};foreach($part in ([uri]$failed.Location).Query.TrimStart('?').Split('&')){$kv=$part.Split('=',2);$failureQuery[[Net.WebUtility]::UrlDecode($kv[0])]=[Net.WebUtility]::UrlDecode($kv[1])}
 $values.vnp_TxnRef=$failureQuery.vnp_TxnRef;$values.vnp_ResponseCode='24';$values.vnp_TransactionStatus='02';$values.vnp_TransactionNo='0'
 $result=Req ('/Payment/Ipn?'+(Signed $values));Check (($result.Text|ConvertFrom-Json).RspCode -eq '00') 'Signed payment cancellation accepted'
 $complete=Req ('/Cart/Complete?code='+$values.vnp_TxnRef);Check ($complete.Text.Contains('Thanh toán không thành công')) 'Failed payment remains visibly unpaid'
 Write-Host "$count payment and notification checks passed. No gateway or real email contacted."
}finally{
 if($null -ne $paymentOriginal){[IO.File]::WriteAllBytes($paymentPath,$paymentOriginal)}elseif(Test-Path $paymentPath){Remove-Item -LiteralPath $paymentPath}
 if($null -ne $smtpOriginal){[IO.File]::WriteAllBytes($smtpPath,$smtpOriginal)}elseif(Test-Path $smtpPath){Remove-Item -LiteralPath $smtpPath}
 $http.Dispose();$handler.Dispose()
}
