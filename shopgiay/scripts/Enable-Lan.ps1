param([string]$IpAddress='192.168.41.103',[ValidateRange(1024,65535)][int]$Port=5188)
$ErrorActionPreference='Stop'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if(!(New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Cần chạy command với quyền Administrator để cấu hình HTTP và firewall.'}
$address=[Net.IPAddress]::Parse($IpAddress)
if($address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){throw 'Chỉ chấp nhận IPv4.'}
$bytes=$address.GetAddressBytes()
if(!($bytes[0] -eq 10 -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168))){throw 'Dùng địa chỉ IP mạng nội bộ.'}
$adapter=Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $IpAddress | Select-Object -First 1
if(!$adapter){throw "Máy không có IP $IpAddress. Kiểm tra lại địa chỉ Wi-Fi/LAN."}
$networkBytes=New-Object byte[] 4
for($i=0;$i -lt 4;$i++){$bits=[Math]::Min(8,[Math]::Max(0,$adapter.PrefixLength-$i*8));$mask=if($bits -eq 0){0}else{256-[Math]::Pow(2,8-$bits)};$networkBytes[$i]=$bytes[$i] -band [int]$mask}
$subnet=([Net.IPAddress]::new($networkBytes)).ToString()+'/'+$adapter.PrefixLength
$workspace=Split-Path $PSScriptRoot -Parent
$url="http://${IpAddress}:$Port/"
$reservation=& netsh http show urlacl "url=$url"
if(($reservation -join "`n") -notmatch [regex]::Escape($url)){& netsh http add urlacl "url=$url" "user=$($identity.Name)";if($LASTEXITCODE -ne 0){throw 'Không cấp được quyền lắng nghe HTTP cho IIS Express.'}}
$ruleName="ShopGiay-LAN-$Port"
if(Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue){Set-NetFirewallRule -Name $ruleName -Enabled True -Direction Inbound -Action Allow -Profile Any;Get-NetFirewallRule -Name $ruleName | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -Protocol TCP -LocalPort $Port;Get-NetFirewallRule -Name $ruleName | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -LocalAddress $IpAddress -RemoteAddress $subnet}else{New-NetFirewallRule -Name $ruleName -DisplayName "ShopGiay LAN TCP $Port" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -LocalAddress $IpAddress -RemoteAddress $subnet -Profile Any | Out-Null}
$configs=@('.vs/shopgiay/config/applicationhost.config','.vs/shopgiay.slnx/config/applicationhost.config')
foreach($relative in $configs){$path=Join-Path $workspace $relative;if(!(Test-Path -LiteralPath $path)){continue};$document=New-Object Xml.XmlDocument;$document.PreserveWhitespace=$true;$document.Load($path);$bindings=$document.SelectSingleNode("/configuration/system.applicationHost/sites/site[@name='shopgiay']/bindings");if(!$bindings){continue};$bindingValue="*:${Port}:$IpAddress";$exists=@($bindings.SelectNodes('binding')|Where-Object {$_.GetAttribute('protocol') -eq 'http' -and $_.GetAttribute('bindingInformation') -eq $bindingValue});if($exists.Count -eq 0){$node=$document.CreateElement('binding');$node.SetAttribute('protocol','http');$node.SetAttribute('bindingInformation',$bindingValue);[void]$bindings.AppendChild($node);$document.Save($path)};Write-Host "Đã cấu hình: $relative"}
Write-Host "Địa chỉ mạng nội bộ: $url"
Write-Host "Firewall chỉ cho phép nguồn $subnet đến ${IpAddress}:$Port."
