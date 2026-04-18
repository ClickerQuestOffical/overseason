# ============================================================
#  OVERSEASON - Installer
#  Run with:
#  irm https://raw.githubusercontent.com/YOUR_USERNAME/overseason/main/install.ps1 | iex
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

# -- Create folder -------------------------------------------
Write-Host "  [1/4] Creating folder..." -ForegroundColor DarkGray
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\sessions" -Force | Out-Null

# -- Download files ------------------------------------------
Write-Host "  [2/4] Downloading Overseason..." -ForegroundColor DarkGray
Invoke-WebRequest "$repoBase/overseason.ps1" -OutFile "$installDir\overseason.ps1" -UseBasicParsing

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

# -- Register command (persists after restart) ---------------
Write-Host "  [4/4] Registering 'overseason' command..." -ForegroundColor DarkGray

$batContent = "@echo off`r`npowershell -ExecutionPolicy Bypass -NoProfile -File `"%USERPROFILE%\overseason\overseason.ps1`" %*"

# Method 1: WindowsApps folder (already permanently on PATH in Windows 10/11)
$windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
$installedToWindowsApps = $false

if (Test-Path $windowsApps) {
    try {
        $batContent | Out-File "$windowsApps\overseason.bat" -Encoding ascii
        $installedToWindowsApps = $true
        Write-Host "  Registered in WindowsApps (permanent, no PATH changes needed)." -ForegroundColor DarkGray
    }
    catch {
        # Fall through to Method 2
    }
}

# Method 2: Fallback - add installDir to user PATH permanently via registry
if (-not $installedToWindowsApps) {
    $batContent | Out-File "$installDir\overseason.bat" -Encoding ascii

    # Use registry directly for reliable persistent PATH (no 1024 char setx limit)
    $regPath = "HKCU:\Environment"
    $currentPath = (Get-ItemProperty -Path $regPath -Name PATH -ErrorAction SilentlyContinue).PATH

    if ($currentPath -notlike "*$installDir*") {
        $newPath = if ($currentPath) { "$currentPath;$installDir" } else { $installDir }
        Set-ItemProperty -Path $regPath -Name PATH -Value $newPath
        # Broadcast WM_SETTINGCHANGE so open windows pick up the new PATH immediately
        $signature = '[DllImport("user32.dll")] public static extern int SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
        $type = Add-Type -MemberDefinition $signature -Name WinAPI -Namespace Win32 -PassThru
        $result = [UIntPtr]::Zero
        $type::SendMessageTimeout([IntPtr]0xFFFF, 0x001A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
        Write-Host "  Added to PATH via registry (permanent)." -ForegroundColor DarkGray
    }
}

# -- Done ----------------------------------------------------
Write-Host ""
Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Close this window and open a new CMD or PowerShell, then type:" -ForegroundColor White
Write-Host ""
Write-Host "      overseason" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This command will work every time, even after restart." -ForegroundColor DarkGray
Write-Host ""
