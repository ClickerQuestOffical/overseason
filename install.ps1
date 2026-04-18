# ============================================================
#  OVERSEASON - Installer
#  Run with:
#  irm https://raw.githubusercontent.com/ClickerQuestOffical/overseason/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

$GH_USER    = "ClickerQuestOffical"
$GH_REPO    = "overseason"
$repoBase   = "https://raw.githubusercontent.com/$GH_USER/$GH_REPO/main"
$installDir = "$env:USERPROFILE\overseason"

# -- Banner --------------------------------------------------
Write-Host ""
Write-Host "   ___  _   _ ___ ___ ___ ___ _   ___ ___  _  _ " -ForegroundColor Cyan
Write-Host "  / _ \| | | | __| _ \ __/ __| | | __/ _ \| \| |" -ForegroundColor Cyan
Write-Host " | (_) | |_| | _||   / _|\__ \ |_| _| (_) | .' |" -ForegroundColor Cyan
Write-Host "  \___/ \___/|___|_|_\___|___/\___|\___\___/|_|\_|" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installer" -ForegroundColor DarkCyan
Write-Host ""
Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
Write-Host ""

# -- Create folders ------------------------------------------
Write-Host "  [1/4] Creating folders..." -ForegroundColor DarkGray
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\sessions" -Force | Out-Null

# -- Download files ------------------------------------------
Write-Host "  [2/4] Downloading Overseason..." -ForegroundColor DarkGray
try {
    Invoke-WebRequest "$repoBase/overseason.ps1?t=$(Get-Date -UFormat %s)" -OutFile "$installDir\overseason.ps1" -UseBasicParsing
    Write-Host "  Downloaded successfully." -ForegroundColor DarkGray
}
catch {
    Write-Host ""
    Write-Host "  ERROR: Could not download overseason.ps1" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host "  Check your internet and try again." -ForegroundColor Yellow
    exit 1
}

# -- API key -------------------------------------------------
Write-Host "  [3/4] Setting up API key..." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Overseason uses Groq - free AI, no credit card needed." -ForegroundColor White
Write-Host "  Get your key at: " -ForegroundColor White -NoNewline
Write-Host "https://console.groq.com/keys" -ForegroundColor Cyan
Write-Host ""

$apiKey = ""
while ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = Read-Host "  Paste your Groq API key (starts with gsk_)"
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Host "  Key cannot be empty." -ForegroundColor Red
    }
}
"GROQ_API_KEY=$($apiKey.Trim())" | Out-File "$installDir\.env" -Encoding utf8
Write-Host "  Key saved." -ForegroundColor DarkGray
Write-Host ""

# -- Register 'overseason' command ---------------------------
Write-Host "  [4/4] Registering 'overseason' command..." -ForegroundColor DarkGray

$batContent  = "@echo off`r`npowershell -ExecutionPolicy Bypass -NoProfile -File `"%USERPROFILE%\overseason\overseason.ps1`" %*"
$registered  = $false
$registeredBy = ""

# Method 1: WindowsApps - already permanently on PATH in Win10/11
$windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
if (-not $registered -and (Test-Path $windowsApps)) {
    try {
        $batContent | Out-File "$windowsApps\overseason.bat" -Encoding ascii -Force
        if (Test-Path "$windowsApps\overseason.bat") {
            $registered   = $true
            $registeredBy = "WindowsApps"
        }
    } catch { }
}

# Method 2: Registry user PATH
if (-not $registered) {
    try {
        $batContent | Out-File "$installDir\overseason.bat" -Encoding ascii -Force
        $regPath     = "HKCU:\Environment"
        $currentPath = (Get-ItemProperty -Path $regPath -Name PATH -ErrorAction SilentlyContinue).PATH
        if ($currentPath -notlike "*$installDir*") {
            $newPath = if ($currentPath) { "$currentPath;$installDir" } else { $installDir }
            Set-ItemProperty -Path $regPath -Name PATH -Value $newPath
        }
        $registered   = $true
        $registeredBy = "user PATH"
    } catch { }
}

# Method 3: System32 - works on every Windows, no PATH needed
if (-not $registered) {
    try {
        $batContent | Out-File "C:\Windows\System32\overseason.bat" -Encoding ascii -Force
        $registered   = $true
        $registeredBy = "System32"
    } catch { }
}

Write-Host "  Registered via $registeredBy." -ForegroundColor DarkGray

# -- Done ----------------------------------------------------
Write-Host ""
Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""

if ($registered) {
    Write-Host "  Open a brand new CMD window and type:" -ForegroundColor White
    Write-Host ""
    Write-Host "      overseason" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Works every time, including after restart." -ForegroundColor DarkGray
} else {
    Write-Host "  Auto-registration failed. Run this one line to fix it:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  `$b = '@echo off' + [char]13 + [char]10 + 'powershell -ExecutionPolicy Bypass -NoProfile -File ""%USERPROFILE%\overseason\overseason.ps1"" %*'; `$b | Out-File `"$env:LOCALAPPDATA\Microsoft\WindowsApps\overseason.bat`" -Encoding ascii" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or run directly: powershell -ExecutionPolicy Bypass -File $installDir\overseason.ps1" -ForegroundColor DarkGray
}

Write-Host ""
