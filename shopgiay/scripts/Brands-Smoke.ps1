param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$credentialPath=Join-Path (Split-Path $PSScriptRoot -Parent) '.local/admin-credentials.txt'
$credentials=Get-Content -LiteralPath $credentialPath -Encoding utf8
$email=($credentials|Where-Object {$_ -like 'Email:*'}).Substring(7)
$password=($credentials|Where-Object {$_ -like 'Password:*'}).Substring(10)
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Normalize($r){[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);BaseResponse=$r.BaseResponse}}
function Fetch([string]$path){Normalize (Invoke-WebRequest ($BaseUrl+$path) -WebSession $session)}
function Send([string]$path,[hashtable]$body,$page){$token=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;if(!$token){throw 'Missing CSRF token'};$body['__RequestVerificationToken']=$token;Normalize (Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $body -WebSession $session)}
function Check([bool]$ok,[string]$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
$page=Fetch '/'
Check ($page.Content.Contains('id="brandId"')) 'Store has dynamic brand filter'
$protected=Fetch '/Admin/Brands'
Check ($protected.BaseResponse.RequestMessage.RequestUri.AbsolutePath -eq '/Admin/Account/Login') 'Brand management requires admin'
$login=Fetch '/Admin/Account/Login'
$page=Send '/Admin/Account/Login' @{Email=$email;Password=$password} $login
Check ($page.Content.Contains('Không gian quản trị') -and $page.Content.Contains('Quản lý sản phẩm')) 'Vietnamese admin layout is correctly encoded'
$edit=Fetch '/Admin/Brands/Edit'
$suffix=[guid]::NewGuid().ToString('N').Substring(0,8)
$name='Giày kiểm thử '+$suffix
$created=Send '/Admin/Brands/Edit/0' @{Name=$name;SortOrder='17';Active='true'} $edit
Check ($created.Content.Contains($name)) 'Create brand with Vietnamese name'
$id=[regex]::Match($created.Content,'(?s)'+[regex]::Escape($name)+'.*?href="/Admin/Brands/Edit/(\d+)"').Groups[1].Value
Check (![string]::IsNullOrEmpty($id)) 'Brand has persisted identifier'
$store=Fetch '/'
Check ($store.Content.Contains($name)) 'Brand appears in store navigation'
$empty=Fetch "/?brandId=$id"
Check ($empty.Content.Contains('Chưa tìm thấy sản phẩm')) 'New brand starts without products'
$edit=Fetch '/Admin/Products/Edit'
Check ($edit.Content.Contains($name) -and $edit.Content.Contains('BrandId')) 'Product form loads brands from database'
$sku='TEST-CAT-'+$suffix
$body=@{Name='Brand Test Product '+$suffix;Brand='Test';Sku=$sku;Color='Đen';Price='1200000';Active='true';Featured='false';BrandId=$id;'Variants[0].Size'='40';'Variants[0].Stock'='2'}
if(!$body.Name.Contains($sku)){$body.Name += ' '+$sku}
$missingBrand=$body.Clone();$missingBrand.Remove('BrandId')
$invalid=Send '/Admin/Products/Edit/0' $missingBrand $edit
Check ($invalid.Content.Contains('Vui lòng chọn thương hiệu hợp lệ')) 'Product requires a managed brand'
$products=Send '/Admin/Products/Edit/0' $body $edit
Check ($products.Content.Contains($sku)) 'Product saves brand assignment'
$productId=[regex]::Match($products.Content,'(?s)'+[regex]::Escape($sku)+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
$filtered=Fetch "/?brandId=$id&sort=price-asc"
Check ($filtered.Content.Contains($body.Name) -and !$filtered.Content.Contains("Giày Nike Air Force")) 'Store filters and sorts by brand'
$brands=Fetch '/Admin/Brands'
$blocked=Send '/Admin/Brands/Delete' @{id=$id} $brands
Check ($blocked.Content.Contains('Thương hiệu đang có sản phẩm')) 'Brand with products cannot be deleted'
$edit=Fetch "/Admin/Brands/Edit/$id"
$hidden=Send "/Admin/Brands/Edit/$id" @{Name=$name;SortOrder='17';Active='false'} $edit
$store=Fetch '/'
Check (!$store.Content.Contains($name)) 'Hidden brand disappears from store menu'
$edit=Fetch "/Admin/Brands/Edit/$id"
$renamed=$name+' mới'
$updated=Send "/Admin/Brands/Edit/$id" @{Name=$renamed;SortOrder='1';Active='true'} $edit
$store=Fetch '/'
Check ($store.Content.Contains($renamed)) 'Rename and show brand updates store menu'
Check ($store.Content.Contains($renamed.ToUpper())) 'Brand rename updates existing product labels'
$products=Fetch '/Admin/Products'
$deleted=Send '/Admin/Products/Delete' @{id=$productId} $products
Check (!$deleted.Content.Contains($sku)) 'Remove test product'
$brands=Fetch '/Admin/Brands'
$deleted=Send '/Admin/Brands/Delete' @{id=$id} $brands
Check (!$deleted.Content.Contains($renamed)) 'Delete empty brand'
$store=Fetch '/'
Check (!$store.Content.Contains($renamed)) 'Deleted brand no longer appears in menu'
Write-Host 'All brand checks passed. Test brand and product have been removed.'


