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
Check (!$page.Content.Contains('GIÀY NIKE') -and !$page.Content.Contains('GIÀY ADIDAS')) 'No hardcoded brand navigation'
$protected=Fetch '/Admin/Categories'
Check ($protected.BaseResponse.RequestMessage.RequestUri.AbsolutePath -eq '/Admin/Account/Login') 'Category management requires admin'
$login=Fetch '/Admin/Account/Login'
$page=Send '/Admin/Account/Login' @{Email=$email;Password=$password} $login
Check ($page.Content.Contains('Không gian quản trị') -and $page.Content.Contains('Quản lý sản phẩm')) 'Vietnamese admin layout is correctly encoded'
$edit=Fetch '/Admin/Categories/Edit'
$suffix=[guid]::NewGuid().ToString('N').Substring(0,8)
$name='Giày kiểm thử '+$suffix
$created=Send '/Admin/Categories/Edit/0' @{Name=$name;SortOrder='17';Active='true'} $edit
Check ($created.Content.Contains($name)) 'Create category with Vietnamese name'
$id=[regex]::Match($created.Content,'(?s)'+[regex]::Escape($name)+'.*?href="/Admin/Categories/Edit/(\d+)"').Groups[1].Value
Check (![string]::IsNullOrEmpty($id)) 'Category has persisted identifier'
$store=Fetch '/'
Check ($store.Content.Contains($name.ToUpper())) 'Category appears in store navigation'
$empty=Fetch "/?categoryId=$id"
Check ($empty.Content.Contains('Chưa tìm thấy sản phẩm')) 'New category starts without products'
$edit=Fetch '/Admin/Products/Edit'
Check ($edit.Content.Contains($name) -and $edit.Content.Contains('CategoryId')) 'Product form loads categories from database'
$managedBrandId=[regex]::Match($edit.Content,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
$sku='TEST-CAT-'+$suffix
$body=@{Name='Category Test Product '+$suffix;Brand='Test';BrandId=$managedBrandId;Sku=$sku;Color='Đen';Price='1200000';Active='true';Featured='false';CategoryId=$id;'Variants[0].Size'='40';'Variants[0].Stock'='2'}
if(!$body.Name.Contains($sku)){$body.Name += ' '+$sku}
$products=Send '/Admin/Products/Edit/0' $body $edit
Check ($products.Content.Contains($sku)) 'Product saves category assignment'
$productId=[regex]::Match($products.Content,'(?s)'+[regex]::Escape($sku)+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
$filtered=Fetch "/?categoryId=$id&sort=price-asc"
Check ($filtered.Content.Contains($body.Name) -and !$filtered.Content.Contains("Giày Nike Air Force")) 'Store filters and sorts by category'
$categories=Fetch '/Admin/Categories'
$blocked=Send '/Admin/Categories/Delete' @{id=$id} $categories
Check ($blocked.Content.Contains('Danh mục đang có sản phẩm')) 'Category with products cannot be deleted'
$edit=Fetch "/Admin/Categories/Edit/$id"
$hidden=Send "/Admin/Categories/Edit/$id" @{Name=$name;SortOrder='17';Active='false'} $edit
$store=Fetch '/'
Check (!$store.Content.Contains($name.ToUpper())) 'Hidden category disappears from store menu'
$edit=Fetch "/Admin/Categories/Edit/$id"
$renamed=$name+' mới'
$updated=Send "/Admin/Categories/Edit/$id" @{Name=$renamed;SortOrder='1';Active='true'} $edit
$store=Fetch '/'
Check ($store.Content.Contains($renamed.ToUpper())) 'Rename and show category updates store menu'
$products=Fetch '/Admin/Products'
$deleted=Send '/Admin/Products/Delete' @{id=$productId} $products
Check (!$deleted.Content.Contains($sku)) 'Remove test product'
$categories=Fetch '/Admin/Categories'
$deleted=Send '/Admin/Categories/Delete' @{id=$id} $categories
Check (!$deleted.Content.Contains($renamed)) 'Delete empty category'
$store=Fetch '/'
Check (!$store.Content.Contains($renamed.ToUpper())) 'Deleted category no longer appears in menu'
Write-Host 'All category checks passed. Test category and product have been removed.'


