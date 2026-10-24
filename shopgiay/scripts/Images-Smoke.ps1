param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$fixtureFolder=Join-Path $workspace '.local/upload-tests'
New-Item -ItemType Directory -Force $fixtureFolder | Out-Null
Add-Type -AssemblyName System.Drawing
$bitmap=New-Object System.Drawing.Bitmap 16,16
try{$bitmap.SetPixel(0,0,[System.Drawing.Color]::Blue);$bitmap.Save((Join-Path $fixtureFolder 'sample.png'),[System.Drawing.Imaging.ImageFormat]::Png);$bitmap.Save((Join-Path $fixtureFolder 'sample.jpg'),[System.Drawing.Imaging.ImageFormat]::Jpeg)}finally{$bitmap.Dispose()}
[IO.File]::WriteAllText((Join-Path $fixtureFolder 'invalid.png'),'This is not a PNG')
Copy-Item (Join-Path $fixtureFolder 'sample.png') (Join-Path $fixtureFolder 'wrong.jpg') -Force
[IO.File]::WriteAllText((Join-Path $fixtureFolder 'invalid.txt'),'Invalid upload')
$large=[IO.File]::Create((Join-Path $fixtureFolder 'large.png'));$large.SetLength(5*1024*1024+1);$large.Dispose()
$png=Get-Item (Join-Path $fixtureFolder 'sample.png');$jpg=Get-Item (Join-Path $fixtureFolder 'sample.jpg')
$credentials=Get-Content (Join-Path $workspace '.local/admin-credentials.txt') -Encoding utf8
$email=($credentials|Where-Object {$_ -like 'Email:*'}).Substring(7);$password=($credentials|Where-Object {$_ -like 'Password:*'}).Substring(10)
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Normalize($r){[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);BaseResponse=$r.BaseResponse}}
function Fetch([string]$path){Normalize (Invoke-WebRequest ($BaseUrl+$path) -WebSession $session)}
function Send([string]$path,[hashtable]$body,$page){$body=$body.Clone();foreach($key in @($body.Keys)){if($body[$key] -is [IO.FileInfo] -or ($body[$key] -is [array] -and $body[$key].Count -gt 0 -and $body[$key][0] -is [IO.FileInfo])){$body[$key]=@($body[$key]|ForEach-Object {$copyPath=Join-Path $fixtureFolder ([guid]::NewGuid().ToString('N')+$_.Extension);Copy-Item -LiteralPath $_.FullName -Destination $copyPath;Get-Item $copyPath})}};$body['__RequestVerificationToken']=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;Normalize (Invoke-WebRequest ($BaseUrl+$path) -Method Post -Form $body -WebSession $session)}
function Check([bool]$ok,[string]$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
$login=Fetch '/Admin/Account/Login'
$admin=Send '/Admin/Account/Login' @{Email=$email;Password=$password} $login
$previous=Fetch '/Admin/Products?q=TEST-IMG-'
foreach($row in [regex]::Matches($previous.Content,'(?s)<tr>.*?</tr>')){if($row.Value.Contains('Image upload test') -and $row.Value.Contains('TEST-IMG-')){$staleId=[regex]::Match($row.Value,'name="id" value="(\d+)"').Groups[1].Value;if($staleId){$previous=Send '/Admin/Products/Delete' @{id=$staleId} $previous}}}
$edit=Fetch '/Admin/Products/Edit'
Check ($edit.Content.Contains('multipart/form-data') -and $edit.Content.Contains('name="avatarFile"')) 'Product form supports file uploads'
$brandId=[regex]::Match($edit.Content,'(?s)<select[^>]*name="BrandId".*?<option value="(\d+)"').Groups[1].Value
$sku='TEST-IMG-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$body=@{Name='Image upload test';BrandId=$brandId;Sku=$sku;Color='Đen';Price='1000000';Active='true';Featured='false';'Variants[0].Size'='40';'Variants[0].Stock'='1'}
if(!$body.Name.Contains($sku)){$body.Name += ' '+$sku}
1..9 | ForEach-Object { Copy-Item $png.FullName (Join-Path $fixtureFolder "sample-$_.png") -Force;Copy-Item $jpg.FullName (Join-Path $fixtureFolder "sample-$_.jpg") -Force }
$over=$body.Clone();$over.imageFiles=@(1..9|ForEach-Object {Get-Item (Join-Path $fixtureFolder "sample-$_.png")})
$invalid=Send '/Admin/Products/Edit/0' $over $edit
Check ($invalid.Content.Contains('tối đa 8 ảnh')) 'Reject more than eight images'
$bad=$body.Clone();$bad.imageFiles=Get-Item (Join-Path $fixtureFolder 'invalid.txt')
$invalid=Send '/Admin/Products/Edit/0' $bad $edit
Check ($invalid.Content.Contains('Chỉ chấp nhận ảnh PNG')) 'Reject unsupported file extension'
$bad.imageFiles=Get-Item (Join-Path $fixtureFolder 'invalid.png')
$invalid=Send '/Admin/Products/Edit/0' $bad $edit
Check ($invalid.Content.Contains('validation-summary-errors')) 'Reject fake PNG content'
$bad.imageFiles=Get-Item (Join-Path $fixtureFolder 'wrong.jpg')
$invalid=Send '/Admin/Products/Edit/0' $bad $edit
Check ($invalid.Content.Contains('không khớp định dạng')) 'Validate actual PNG/JPEG format'
$bad.imageFiles=Get-Item (Join-Path $fixtureFolder 'large.png')
$invalid=Send '/Admin/Products/Edit/0' $bad $edit
Check ($invalid.Content.Contains('tối đa 5 MB')) 'Enforce per-image size limit'
$body.imageFiles=@(1..8|ForEach-Object {$extension=if($_%2){"png"}else{"jpg"};Get-Item (Join-Path $fixtureFolder "sample-$_.$extension")});$body.avatarFile=$jpg
$created=Send '/Admin/Products/Edit/0' $body $edit
Check ($created.Content.Contains($sku)) 'Create product with one avatar and eight information images'
$id=[regex]::Match($created.Content,'(?s)'+[regex]::Escape($sku)+'.*?href="/Admin/Products/Edit/(\d+)"').Groups[1].Value
$edit=Fetch "/Admin/Products/Edit/$id"
$images=[regex]::Matches($edit.Content,'name="removeImageIds" value="(\d+)"')
Check ($images.Count -eq 8) 'All eight images persisted'
$detail=Fetch "/Home/Product/$id"
$urls=@([regex]::Matches($detail.Content,'data-gallery-image="([^"]+)"') | ForEach-Object {$_.Groups[1].Value})
Check ($urls.Count -eq 9) 'Customer detail displays all images'
$primary=[regex]::Match($detail.Content,'id="product-main-image" src="([^"]+)"').Groups[1].Value
Check ($primary -eq $urls[0]) 'Avatar is independent of eight gallery images'
$file=Invoke-WebRequest ($BaseUrl+$urls[0])
Check ($file.StatusCode -eq 200 -and $file.Headers.'Content-Type' -like 'image/jpeg*') 'Uploaded JPEG is served correctly'
$next=$body.Clone();$next.Remove('imageFiles');$next.avatarFile=$png
$updated=Send "/Admin/Products/Edit/$id" $next $edit
Check ($updated.Content.Contains($sku)) 'Replace avatar while keeping the full gallery'
$detail=Fetch "/Home/Product/$id"
$primary=[regex]::Match($detail.Content,'id="product-main-image" src="([^"]+)"').Groups[1].Value
Check ($primary -ne $urls[0] -and $primary.EndsWith('.png')) 'New avatar is saved independently'
$replacedAvatar=$primary
$edit=Fetch "/Admin/Products/Edit/$id"
$overflow=$next.Clone();$overflow.imageFiles=Get-Item (Join-Path $fixtureFolder 'sample-9.png')
$invalid=Send "/Admin/Products/Edit/$id" $overflow $edit
Check ($invalid.Content.Contains('tối đa 8 ảnh')) 'Limit includes existing images'
$replacement=$next.Clone();$replacement.imageFiles=$jpg;$replacement.removeImageIds=@($images[0].Groups[1].Value,$images[1].Groups[1].Value)
$updated=Send "/Admin/Products/Edit/$id" $replacement $edit
Check ($updated.Content.Contains($sku)) 'Remove old images and upload replacement together'
$detail=Fetch "/Home/Product/$id"
$remaining=@([regex]::Matches($detail.Content,'data-gallery-image="([^"]+)"')|ForEach-Object {$_.Groups[1].Value})
Check ($remaining.Count -eq 8 -and !$remaining.Contains($urls[1]) -and !$remaining.Contains($urls[2])) 'Seven information images plus one avatar remain'
$primary=[regex]::Match($detail.Content,'id="product-main-image" src="([^"]+)"').Groups[1].Value
Check ($primary -eq $remaining[0]) 'Avatar remains separate after gallery replacement'
$replacementAvatar=$primary
$edit=Fetch "/Admin/Products/Edit/$id"
$withoutAvatar=$next.Clone();$withoutAvatar.Remove('avatarFile');$withoutAvatar.removeAvatar='true'
$updated=Send "/Admin/Products/Edit/$id" $withoutAvatar $edit
Check ($updated.Content.Contains($sku)) 'Remove avatar independently of gallery'
$detail=Fetch "/Home/Product/$id"
Check (([regex]::Matches($detail.Content,'data-gallery-image=')).Count -eq 7) 'Removing avatar preserves all information images'
$edit=Fetch "/Admin/Products/Edit/$id"
$restored=$next.Clone();$restored.avatarFile=$jpg
$updated=Send "/Admin/Products/Edit/$id" $restored $edit
Check ($updated.Content.Contains($sku)) 'Upload an avatar without changing gallery'
$detail=Fetch "/Home/Product/$id"
$restoredUrls=@([regex]::Matches($detail.Content,'data-gallery-image="([^"]+)"')|ForEach-Object {$_.Groups[1].Value})
$products=Fetch '/Admin/Products'
$deleted=Send '/Admin/Products/Delete' @{id=$id} $products
Check (!$deleted.Content.Contains($sku)) 'Delete test product and image records'
$uploadDirectory=Join-Path $workspace 'shopgiay'
Check ((@($urls+$remaining+$restoredUrls+@($replacedAvatar)|Where-Object {Test-Path -LiteralPath (Join-Path $uploadDirectory $_.TrimStart('/'))})).Count -eq 0) 'Managed image files cleaned up after deletion'
Write-Host 'All upload checks passed. Test product and uploaded files removed.'





