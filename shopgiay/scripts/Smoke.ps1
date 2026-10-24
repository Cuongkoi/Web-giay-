param([string]$BaseUrl='http://localhost:5188',[Parameter(Mandatory=$true)][string]$Email,[Parameter(Mandatory=$true)][string]$Password)
$ErrorActionPreference='Stop'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Normalize($r){[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);BaseResponse=$r.BaseResponse}}
function Fetch([string]$path){ Normalize (Invoke-WebRequest ($BaseUrl+$path) -WebSession $session) }
function Token($page){$m=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"');if(!$m.Success){throw 'Missing CSRF token'};[System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)}
function Send([string]$path,[hashtable]$data,$page){$data['__RequestVerificationToken']=Token $page;Normalize (Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $data -WebSession $session)}
function Check([bool]$ok,[string]$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
$catalogPage=Fetch '/'
Check ($catalogPage.Content.Contains('product-card')) 'Catalog renders'
$filtered=Fetch '/?brand=Nike&sort=price-asc'
Check (!$filtered.Content.Contains('Giày Adidas Samba')) 'Brand filter and price sort'
$protected=Fetch '/Admin'
Check ($protected.BaseResponse.RequestMessage.RequestUri.AbsolutePath -eq '/Admin/Account/Login') 'Admin requires authentication'
try {Invoke-WebRequest ($BaseUrl+'/Cart/Add') -Method Post -Body @{variantId=1;quantity=1} -WebSession $session | Out-Null;throw 'CSRF accepted'}catch {Check ($_.Exception.Response.StatusCode.value__ -eq 400) 'POST rejects missing CSRF token'}
$product=Fetch '/Home/Product/1'
$variant=[regex]::Match($product.Content,'name="variantId" value="(\d+)"').Groups[1].Value
Check (![string]::IsNullOrEmpty($variant)) 'Product sizes render'
$cart=Send '/Cart/Add' @{variantId=$variant;quantity=1} $product
Check ($cart.Content.Contains('SG-001') -or $cart.Content.Contains('Air Force')) 'Add to cart'
$rejected=Send '/Cart/Update' @{variantId=$variant;quantity=9999} $cart
Check ($rejected.Content.Contains('vượt quá')) 'Stock limit validation'
$registration=Fetch '/Account/Register'
$registered=Send '/Account/Register' @{Name='Smoke Test Customer';Email=('smoke-'+[guid]::NewGuid().ToString('N')+'@example.invalid');Password='SmokeCustomer!2026';ConfirmPassword='SmokeCustomer!2026';ReceiveVoucherEmails='false'} $registration
$checkout=Fetch '/Cart/Checkout'
$invalid=Send '/Cart/Checkout' @{CustomerName='';Phone='bad';Address='x'} $checkout
Check ($invalid.Content.Contains('validation-summary-errors')) 'Checkout validates input'
$complete=Send '/Cart/Checkout' @{CustomerName='Smoke Test';Phone='0900000000';Address='123 Test Street, Test City';Note='Automated local test'} $checkout
Check ($complete.Content.Contains('Đặt hàng thành công')) 'COD checkout succeeds'
$code=[regex]::Match($complete.Content,'<strong>([A-F0-9]{10})</strong>').Groups[1].Value
$empty=Fetch '/Cart'
Check ($empty.Content.Contains('Giỏ hàng đang trống')) 'Cart clears after checkout'
$login=Fetch '/Admin/Account/Login'
$admin=Send '/Admin/Account/Login' @{Email=$Email;Password=$Password} $login
Check ($admin.Content.Contains('Quản lý sản phẩm')) 'Admin login and dashboard'
$edit=Fetch '/Admin/Products/Edit'
$managedBrandId=[regex]::Match($edit.Content,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
$sku='TEST-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$body=@{Name='Smoke Test Sneaker';Brand='Nike';BrandId=$managedBrandId;Sku=$sku;Color='Đen';Price='1500000';OriginalColor='Đen';Price='2000000';Description='Local test';Active='true';Featured='false'}
if(!$body.Name.Contains($sku)){$body.Name += ' '+$sku}
for($i=0;$i -lt 9;$i++){$body["Variants[$i].Size"]=(36+$i).ToString();$body["Variants[$i].Stock"]='3'}
$created=Send '/Admin/Products/Edit/0' $body $edit
Check ($created.Content.Contains($sku)) 'Create product with size inventory'
$match=[regex]::Match($created.Content,'(?s)'+[regex]::Escape($sku)+'.*?href="/Admin/Products/Edit/(\d+)"')
$id=$match.Groups[1].Value
Check (![string]::IsNullOrEmpty($id)) 'Find created product'
$edit=Fetch "/Admin/Products/Edit/$id"
$body.Name='Smoke Updated Sneaker'
$updated=Send "/Admin/Products/Edit/$id" $body $edit
Check ($updated.Content.Contains('Smoke Updated Sneaker')) 'Edit product'
$deleted=Send '/Admin/Products/Delete' @{id=$id} $updated
Check (!$deleted.Content.Contains($sku)) 'Delete product'
$orders=Fetch '/Admin/Products/Orders'
Check ($orders.Content.Contains($code)) 'Order persisted for admin'
$orderMatch=[regex]::Match($orders.Content,'(?s)#'+$code+'.*?name="id" value="(\d+)"')
$orderId=$orderMatch.Groups[1].Value
Check (![string]::IsNullOrEmpty($orderId)) 'Find order for status update'
$cancelled=Send '/Admin/Products/Status' @{id=$orderId;status='Đã hủy'} $orders
Check ($cancelled.Content.Contains('Đã hủy')) 'Cancel order and restore stock'
$productStock=Fetch '/Admin/Products/Edit/1'
$stock=[regex]::Match($productStock.Content,'name="Variants\[0\].Stock"[^>]*value="(\d+)"').Groups[1].Value
Check ($stock -eq '5') 'Cancelled order restores original size stock'
$cancelledAgain=Send '/Admin/Products/Status' @{id=$orderId;status='Đã hủy'} $cancelled
$productStock=Fetch '/Admin/Products/Edit/1'
$stock=[regex]::Match($productStock.Content,'name="Variants\[0\].Stock"[^>]*value="(\d+)"').Groups[1].Value
Check ($stock -eq '5') 'Duplicate cancellation does not add stock twice'
$logout=Send '/Admin/Account/Logout' @{} $cancelled
$protected=Fetch '/Admin'
Check ($protected.BaseResponse.RequestMessage.RequestUri.AbsolutePath -eq '/Admin/Account/Login') 'Logout revokes access'
Write-Host 'All smoke checks passed. The test order remains in test database as cancelled.'






