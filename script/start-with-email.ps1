param(
  [string]$SmtpAddress = 'smtp.gmail.com',
  [string]$MailFrom = 'universitybulletinboard@gmail.com',
  [int]$Port = 3100
)

$ErrorActionPreference = 'Stop'
$serverPidPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'tmp/pids/server.pid'
if (Test-Path -LiteralPath $serverPidPath) {
  $serverProcessId = 0
  $serverPidText = (Get-Content -LiteralPath $serverPidPath -Raw).Trim()
  if (-not [int]::TryParse($serverPidText, [ref]$serverProcessId) -or $serverProcessId -le 0) {
    throw 'Rails PID file is invalid. Check tmp/pids/server.pid before starting.'
  }
  $existingServer = Get-Process -Id $serverProcessId -ErrorAction SilentlyContinue
  if ($existingServer -and $existingServer.ProcessName -match '^ruby(w)?$') {
    throw "A Ruby process is already running with PID $serverProcessId. Stop the existing Rails server first."
  }
  Remove-Item -LiteralPath $serverPidPath
}
if (-not $SmtpAddress) { throw 'SMTP server is required.' }
if (-not $MailFrom) { throw 'Sender email address is required.' }
$smtpCredential = Get-Credential -UserName $MailFrom -Message 'Enter the Gmail app password, not your normal Google password'
if (-not $smtpCredential) { throw 'SMTP credentials are required.' }

$emailVariableNames = @('SMTP_ADDRESS', 'SMTP_PORT', 'SMTP_USERNAME', 'SMTP_PASSWORD', 'MAIL_FROM', 'APP_HOST', 'APP_PORT')
$previousEmailValues = @{}
foreach ($variableName in $emailVariableNames) {
  $previousEmailValues[$variableName] = [Environment]::GetEnvironmentVariable($variableName, 'Process')
}

try {
  $env:SMTP_ADDRESS = $SmtpAddress
  $env:SMTP_PORT = '587'
  $env:SMTP_USERNAME = $smtpCredential.UserName.Trim()
  $env:SMTP_PASSWORD = $smtpCredential.GetNetworkCredential().Password
  if ($SmtpAddress -eq 'smtp.gmail.com') {
    $env:SMTP_PASSWORD = $env:SMTP_PASSWORD -replace '\s', ''
    if ($env:SMTP_USERNAME -ine $MailFrom) {
      throw 'The Gmail username must match the sender email address.'
    }
    if ($env:SMTP_PASSWORD.Length -ne 16) {
      throw 'Enter the 16-character Google app password, not your Google login password.'
    }
  }
  $env:MAIL_FROM = $MailFrom
  $env:APP_HOST = 'localhost'
  $env:APP_PORT = [string]$Port
  Push-Location (Split-Path $PSScriptRoot -Parent)
  try {
    & bundle exec rails server -b 127.0.0.1 -p $Port
    if ($LASTEXITCODE -ne 0) { throw "Rails exited with code $LASTEXITCODE" }
  } finally {
    Pop-Location
  }
} finally {
  foreach ($variableName in $emailVariableNames) {
    [Environment]::SetEnvironmentVariable($variableName, $previousEmailValues[$variableName], 'Process')
  }
}
