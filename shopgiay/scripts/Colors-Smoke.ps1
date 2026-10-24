param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$credentials=Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) '.local/admin-credentials.txt') -Encoding utf8
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Page($path){$r=Invoke-WebRequest ($BaseUrl+$path) -WebSession $session;[System.Net.WebUtility]::HtmlDecode($r.Content)}
function Send($path,$body,$page){$body['__RequestVerificationToken']=[regex]::Match($page,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;$r=Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $body -WebSession $session;[System.Net.WebUtility]::HtmlDecode($r.Content)}
function Check($ok,$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
$login=Page '/Admin/Account/Login'
$page=Send '/Admin/Account/Login' @{Email=($credentials|Where-Object {$_ -like 'Email:*'}).Substring(7);Password=($credentials|Where-Object {$_ -like 'Password:*'}).Substring(10)} $login
$previous=Page '/Admin/Products?q=COLOR-TEST-'
foreach($row in [regex]::Matches($previous,'(?s)<tr>.*?</tr>')){if($row.Value.Contains('COLOR-TEST-')){$staleId=[regex]::Match($row.Value,'name="id" value="(\d+)"').Groups[1].Value;if($staleId){$previous=Send '/Admin/Products/Delete' @{id=$staleId} $previous}}}
$edit=Page '/Admin/Products/Edit'
Check (!$edit.Contains('name="Sku"') -and !$edit.Contains('Mã SKU')) 'SKU input removed'
Check ($edit.Contains('name="Color"') -and $edit.Contains('Phối màu')) 'Product form provides color selection'
$brandId=[regex]::Match($edit,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
$name='COLOR-TEST-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$body=@{Name=$name;BrandId=$brandId;Price='1000000';Active='true';'Variants[0].Size'='40';'Variants[0].Stock'='1'}
$invalid=Send '/Admin/Products/Edit/0' $body $edit
Check ($invalid.Contains('Vui lòng chọn màu sắc')) 'Validate missing color'
$body.Color='Invalid Color'
$invalid=Send '/Admin/Products/Edit/0' $body $edit
Check ($invalid.Contains('Vui lòng chọn màu sắc')) 'Reject unsupported color'
$body.Color='Đỏ'
$created=Send '/Admin/Products/Edit/0' $body $edit
Check ($created.Contains($name)) 'Create product without entering SKU'
$id=[regex]::Match($created,'(?s)'+$name+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
Check (!!$id) 'Created product persisted'
$detail=Page "/Home/Product/$id"
Check ($detail.Contains('Màu sắc:') -and $detail.Contains('Đỏ')) 'Customer detail displays selected color'
$edit=Page "/Admin/Products/Edit/$id"
Check ($edit.Contains('<option selected="selected">Đỏ</option>') -or $edit -match 'selected="selected" value="Đỏ"|value="Đỏ" selected="selected"') 'Saved color selected on edit'
$body.Color='Trắng'
$updated=Send "/Admin/Products/Edit/$id" $body $edit
Check ($updated.Contains($name)) 'Save existing product without SKU'
$detail=Page "/Home/Product/$id"
Check ($detail.Contains('Trắng')) 'Color update persists'
$deleted=Send '/Admin/Products/Delete' @{id=$id} $updated
Check (!$deleted.Contains($name)) 'Clean up test product'

