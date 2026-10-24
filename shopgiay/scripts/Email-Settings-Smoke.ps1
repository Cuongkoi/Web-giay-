param([string]$BaseUrl='http://localhost:5188')
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$settingsPath=Join-Path $workspace 'shopgiay/App_Data/smtp.local.config'
$original=if(Test-Path $settingsPath){[IO.File]::ReadAllBytes($settingsPath)}else{$null}
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$anonymous=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Page($path,$webSession=$session){$r=Invoke-WebRequest ($BaseUrl+$path) -WebSession $webSession -SkipHttpErrorCheck;if($r.StatusCode -ge 500){$r.Content|Set-Content (Join-Path $workspace '.local/email-settings-error.html');throw "Server error at $path"};[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);Status=[int]$r.StatusCode;Path=$r.BaseResponse.RequestMessage.RequestUri.AbsolutePath}}
function Send($path,$body,$page){$body=$body.Clone();$body['__RequestVerificationToken']=[regex]::Match($page.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value;$r=Invoke-WebRequest ($BaseUrl+$path) -Method Post -Body $body -WebSession $session -SkipHttpErrorCheck;if($r.StatusCode -ge 500){$r.Content|Set-Content (Join-Path $workspace '.local/email-settings-error.html');throw "Server error at $path"};[pscustomobject]@{Content=[System.Net.WebUtility]::HtmlDecode($r.Content);Status=[int]$r.StatusCode}}
function Check($ok,$name){if(!$ok){throw "FAIL: $name"};Write-Host "PASS: $name"}
$blocked=Page '/Admin/EmailSettings' $anonymous
Check ($blocked.Path -eq '/Admin/Account/Login') 'Email settings requires admin'
$login=Page '/Admin/Account/Login'
$page=Send '/Admin/Account/Login' @{Email='admin@shopgiay.vn';Password='admin@123'} $login
$page=Page '/Admin/EmailSettings'
Check ($page.Content.Contains('Cấu hình email gửi đi') -and $page.Content.Contains('Gửi email kiểm tra')) 'Email configuration and test form render'
Check ($page.Content.Contains('type="password"') -and $page.Content.Contains('name="AppPassword"')) 'App password uses masked input'
$private=Page '/App_Data/smtp.local.config'
Check ($private.Status -ne 200) 'SMTP settings file is not publicly served'
$config=if($original){[xml][Text.Encoding]::UTF8.GetString($original)}else{[xml]'<appSettings/>'}
$configuredUser=@($config.appSettings.add|Where-Object {$_.key -eq 'Smtp.User'})
if($configuredUser.Count -gt 0 -and ![string]::IsNullOrWhiteSpace($configuredUser[0].value)){Write-Host 'Existing email settings detected; skipping write tests to protect user configuration.';exit 0}
$testUser='settings-test-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'@example.invalid'
$testPassword='TestOnly!'+[guid]::NewGuid().ToString('N')
try{
 $test=Send '/Admin/EmailSettings/Test' @{Recipient='check@example.invalid'} $page
 Check ($test.Content.Contains('Hãy lưu Gmail và App Password')) 'Test email blocked when credentials are missing'
 $bad=Send '/Admin/EmailSettings' @{Enabled='true';Host='smtp.gmail.com';Port='587';SenderName='STEP STORE'} $page
 Check ($bad.Content.Contains('validation-summary-errors')) 'Enabled sending requires Gmail and app password'
 $body=@{Enabled='false';Host='smtp.gmail.com';Port='587';User=$testUser;AppPassword=$testPassword;SenderName='STEP STORE';FromAddress=''}
 $saved=Send '/Admin/EmailSettings' $body $page
 Check ($saved.Content.Contains('Đã lưu cấu hình email')) 'Admin saves SMTP configuration'
 $stored=[IO.File]::ReadAllText($settingsPath)
 Check ($stored.Contains('Smtp.PasswordProtected') -and !$stored.Contains($testPassword)) 'App password encrypted at rest'
 Check (!$saved.Content.Contains($testPassword) -and $saved.Content.Contains('Đã lưu mật khẩu')) 'Stored password never returned in HTML'
 $body.AppPassword=''
 $saved=Send '/Admin/EmailSettings' $body $saved
 Check ($saved.Content.Contains('Đã lưu mật khẩu')) 'Blank password preserves saved credential'
 $changed=$body.Clone();$changed.User='other-'+$testUser
 $rejected=Send '/Admin/EmailSettings' $changed $saved
 Check ($rejected.Content.Contains('Khi đổi Gmail hoặc máy chủ/cổng SMTP')) 'Changing SMTP identity requires a new app password'
 $invalid=Send '/Admin/EmailSettings/Test' @{Recipient='not-an-email'} $saved
 Check ($invalid.Content.Contains('địa chỉ email nhận thử hợp lệ')) 'Test email validates recipient without sending'
}finally{
 if(Test-Path $settingsPath){$current=[xml][IO.File]::ReadAllText($settingsPath);$currentUser=@($current.appSettings.add|Where-Object {$_.key -eq 'Smtp.User'});$enabled=@($current.appSettings.add|Where-Object {$_.key -eq 'Smtp.Enabled'});if($currentUser.Count -gt 0 -and $currentUser[0].value -eq $testUser -and $enabled[0].value -eq 'false'){if($original){$temporary=$settingsPath+'.restore.tmp';[IO.File]::WriteAllBytes($temporary,$original);[IO.File]::Move($temporary,$settingsPath,$true)}else{Remove-Item -LiteralPath $settingsPath};Write-Host 'Original SMTP configuration restored. No real emails sent.'}}
}

