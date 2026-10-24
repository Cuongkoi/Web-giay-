param([ValidateRange(1024,65535)][int]$Port=5188,[switch]$NoBuild)
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$webRoot=Join-Path $workspace 'shopgiay'
$iisExecutable=Join-Path $env:ProgramFiles 'IIS Express/iisexpress.exe'
if(!(Test-Path -LiteralPath $iisExecutable)){throw 'Không tìm thấy IIS Express. Cài workload ASP.NET and web development trong Visual Studio.'}
if(!$NoBuild){
 $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
 if(!(Test-Path -LiteralPath $vswhere)){throw 'Không tìm thấy vswhere.exe của Visual Studio.'}
 $msbuildPath=& $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
 if(!$msbuildPath){throw 'Không tìm thấy MSBuild.'}
 & $msbuildPath (Join-Path $workspace 'shopgiay.sln') /restore /t:Build /p:Configuration=Debug '/p:Platform=Any CPU' /v:minimal /nologo
 if($LASTEXITCODE -ne 0){throw 'Build thất bại. Xem thông báo phía trên.'}
}
$url="http://localhost:$Port/"
$running=$false
try{$response=Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 3;$running=$response.StatusCode -eq 200 -and $response.Content.Contains('STEP STORE')}catch{}
if(!$running){
 $server=Start-Process -FilePath $iisExecutable -ArgumentList @('/path:"'+$webRoot+'"',"/port:$Port",'/systray:false') -WindowStyle Hidden -PassThru
 $ready=$false
 for($attempt=0;$attempt -lt 20;$attempt++){
  if($server.HasExited){throw 'IIS Express đã dừng. Có thể cổng đang được ứng dụng khác sử dụng.'}
  try{$response=Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 3;if($response.StatusCode -eq 200 -and $response.Content.Contains('STEP STORE')){$ready=$true;break}}catch{}
  Start-Sleep -Milliseconds 500
 }
 if(!$ready){throw "Web chưa phản hồi. Kiểm tra kết nối SQL Server và cấu hình tại $webRoot\Web.config."}
}
Write-Host "Cửa hàng: $url"
Write-Host "Quản trị: ${url}Admin"
Write-Host 'Web đã sẵn sàng. Mở địa chỉ trên bằng trình duyệt; không cần Attach to Process.'
