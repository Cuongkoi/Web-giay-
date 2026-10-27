param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Fetch($path){Invoke-WebRequest ($BaseUrl+$path) -WebSession $session -UseBasicParsing}
function Check($ok,$name){if(!$ok){throw "FAIL: $name"};Write-Output "PASS: $name"}
function Send($path,$data,$page){
 $token=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
 $data['__RequestVerificationToken']=[Net.WebUtility]::HtmlDecode($token)
 Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $data -WebSession $session -UseBasicParsing
}
$catalog=Fetch '/'
$ids=[regex]::Matches($catalog.Content,'/Home/Product/(\d+)') | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique
$chosen=$null
foreach($productId in $ids){
 $stock=(Fetch "/Cart/Availability?productId=$productId").Content | ConvertFrom-Json
 $chosen=$stock | Where-Object {$_.remaining -gt 0} | Select-Object -First 1
 if($chosen){break}
}
Check ($null -ne $chosen) 'Find an available size'
$product=Fetch "/Home/Product/$productId"
Check ($product.Content.Contains('data-stock-product=') -and $product.Content.Contains('stock-quantity.js')) 'Product renders stock controls'
Check ($product.Content -match ('value="'+$chosen.id+'" data-remaining="'+$chosen.remaining+'"')) 'Initial size limit matches inventory'
$cart=Send '/Cart/Add' @{variantId=$chosen.id;quantity=$chosen.remaining} $product
Check ($cart.Content -match ('max="'+$chosen.limit+'" value="'+$chosen.limit+'"')) 'Cart quantity is capped at available stock'
$stock=(Fetch "/Cart/Availability?productId=$productId").Content | ConvertFrom-Json
Check (($stock | Where-Object id -eq $chosen.id).remaining -eq 0) 'Existing cart quantity is deducted from availability'
$product=Fetch "/Home/Product/$productId"
Check ($product.Content -match ('value="'+$chosen.id+'" data-remaining="0" disabled="disabled"')) 'Fully allocated size is disabled'
$rejected=Send '/Cart/Add' @{variantId=$chosen.id;quantity=1} $product
Check ($rejected.Content.Contains('data-stock-product=')) 'Excess add returns to product instead of an empty cart'
$cart=Fetch '/Cart'
$empty=Send '/Cart/Update' @{variantId=$chosen.id;quantity=0} $cart
$stock=(Fetch "/Cart/Availability?productId=$productId").Content | ConvertFrom-Json
Check (($stock | Where-Object id -eq $chosen.id).remaining -eq $chosen.limit) 'Removing cart line restores selectable quantity'
Write-Output 'Stock checks passed. Only an isolated session cart was changed; no orders were placed.'
