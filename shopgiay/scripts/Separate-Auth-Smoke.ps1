param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Page($path){$r=Invoke-WebRequest ($BaseUrl+$path) -WebSession $session -SkipHttpErrorCheck;if($r.StatusCode -ge 500){$r.Content|Set-Content (Join-Path $workspace '.local/separate-auth-error.html');throw "Server error: $path"};[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);Path=$r.BaseResponse.RequestMessage.RequestUri.AbsolutePath;Status=[int]$r.StatusCode}}
function Send($path,$body,$page){$body=$body.Clone();$body['__RequestVerificationToken']=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;$r=Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $body -WebSession $session -SkipHttpErrorCheck;if($r.StatusCode -ge 500){$r.Content|Set-Content (Join-Path $workspace '.local/separate-auth-error.html');throw "Server error: $path"};[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);Path=$r.BaseResponse.RequestMessage.RequestUri.AbsolutePath;Status=[int]$r.StatusCode}}
function Check($ok,$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
function AdminLogin{$page=Page '/Admin/Account/Login';Send '/Admin/Account/Login' @{Email='admin@shopgiay.vn';Password='admin@123'} $page}
$admin=AdminLogin
Check ($admin.Content.Contains('Dashboard thống kê')) 'Admin login works with its own cookie'
$account=Page '/Account'
Check ($account.Path -eq '/Account/Login') 'Admin cookie does not log into customer area'
$suffix=[guid]::NewGuid().ToString('N').Substring(0,10)
$email="auth-test-$suffix@example.invalid";$name="AUTH-TEST-$suffix";$password='AuthCustomer!2026'
"USE ShopGiay; DELETE FROM Customers WHERE Email=N'$email'; DELETE FROM Products WHERE Name=N'$name';"|Set-Content (Join-Path $workspace '.local/separate-auth-cleanup.sql') -Encoding utf8BOM
$edit=Page '/Admin/Products/Edit'
$brandId=[regex]::Match($edit.Content,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
$products=Send '/Admin/Products/Edit/0' @{Name=$name;BrandId=$brandId;Color='Đen';Price='100000';Active='true';'Variants[0].Size'='40';'Variants[0].Stock'='2'} $edit
$productId=[regex]::Match($products.Content,'(?s)'+$name+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
$register=Page '/Account/Register'
$account=Send '/Account/Register' @{Name=$name;Email=$email;Password=$password;ConfirmPassword=$password;ReceiveVoucherEmails='false'} $register
Check ($account.Path -eq '/Account' -and $account.Content.Contains($email)) 'Customer registers without replacing admin cookie'
$admin=Page '/Admin'
Check ($admin.Content.Contains('admin@shopgiay.vn') -and !$admin.Content.Contains($email)) 'Admin identity remains admin after customer login'
$account=Page '/Account'
Check ($account.Content.Contains($email)) 'Storefront keeps the customer identity'
$cookies=$session.Cookies.GetCookies([uri]$BaseUrl)
Check (!!$cookies['ShopGiay.AdminAuth'] -and !!$cookies['ShopGiay.CustomerAuth']) 'Two independent auth cookies exist in the same browser'
$detail=Page "/Home/Product/$productId"
$variant=[regex]::Match($detail.Content,'name="variantId" value="(\d+)"').Groups[1].Value
$cart=Send '/Cart/Add' @{variantId=$variant;quantity=1} $detail
Check ($cart.Content.Contains($name)) 'Customer cart is populated'
$admin=Page '/Admin';$logout=Send '/Admin/Account/Logout' @{} $admin
$account=Page '/Account'
Check ($account.Path -eq '/Account' -and $account.Content.Contains($email)) 'Admin logout does not log out customer'
$admin=Page '/Admin'
Check ($admin.Path -eq '/Admin/Account/Login') 'Customer session alone cannot enter admin'
$cart=Page '/Cart'
Check ($cart.Content.Contains($name)) 'Admin logout preserves customer cart'
$admin=AdminLogin
$account=Page '/Account';$cart=Page '/Cart'
Check ($account.Content.Contains($email) -and $cart.Content.Contains($name)) 'Admin login preserves customer session and cart'
$logout=Send '/Account/Logout' @{} $account
$account=Page '/Account';$admin=Page '/Admin'
Check ($account.Path -eq '/Account/Login') 'Customer logout removes only customer login'
Check ($admin.Content.Contains('Dashboard thống kê')) 'Customer logout preserves admin login'
$login=Page '/Account/Login'
$account=Send '/Account/Login' @{Email=$email;Password=$password} $login
$admin=Page '/Admin'
Check ($account.Content.Contains($email) -and $admin.Content.Contains('admin@shopgiay.vn')) 'Both accounts can log in again independently'
$store=Page '/'
Check (!$store.Content.Contains('class="admin-nav"')) 'Admin shortcut row removed from customer layout'
$cookies=$session.Cookies.GetCookies([uri]$BaseUrl);$customerTicket=$cookies['ShopGiay.CustomerAuth'].Value
$session.Cookies.Add([uri]$BaseUrl,[Net.Cookie]::new('ShopGiay.AdminAuth',$customerTicket,'/'))
$admin=Page '/Admin';$account=Page '/Account'
Check ($admin.Path -eq '/Admin/Account/Login' -and $account.Content.Contains($email)) 'Customer ticket cannot impersonate admin cookie'
$admin=AdminLogin
$adminTicket=$session.Cookies.GetCookies([uri]$BaseUrl)['ShopGiay.AdminAuth'].Value
$session.Cookies.Add([uri]$BaseUrl,[Net.Cookie]::new('ShopGiay.CustomerAuth',$adminTicket,'/'))
$account=Page '/Account';$admin=Page '/Admin'
Check ($account.Path -eq '/Account/Login' -and $admin.Content.Contains('Dashboard thống kê')) 'Admin ticket cannot impersonate customer cookie'
$session.Cookies.Add([uri]$BaseUrl,[Net.Cookie]::new('.ASPXAUTH',$adminTicket,'/'))
$account=Page '/Account'
Check ($account.Path -eq '/Account/Login') 'Legacy shared auth cookie is ignored'
$products=Page '/Admin/Products';$deleted=Send '/Admin/Products/Delete' @{id=$productId} $products
Check (!$deleted.Content.Contains($name)) 'Temporary product removed'
Write-Host 'All separate-login checks passed. Cleanup customer using .local/separate-auth-cleanup.sql.'
