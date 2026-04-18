# ============================================================
#  OVERSEASON — Installer
#  Run this with:
#  irm https://raw.githubusercontent.com/YOUR_USERNAME/overseason/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

$repoBase   = "https://raw.githubusercontent.com/ClickerQuestOffical/overseason/main"
$installDir = "$env:USERPROFILE\overseason"

# ── Banner ───────────────────────────────────────────────────
Write-Host ""
Write-Host "   ___  _   _ ___ ___ ___ ___ _   ___ ___  _  _ " -ForegroundColor Cyan
Write-Host "  / _ \| | | | __| _ \ __/ __| | | __/ _ \| \| |" -ForegroundColor Cyan
Write-Host " | (_) | |_| | _||   / _|\__ \ |_| _| (_) | .' |" -ForegroundColor Cyan
Write-Host "  \___/ \___/|___|_|_\___|___/\___|\___\___/|_|\_|" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installer" -ForegroundColor DarkCyan
Write-Host ""
Write-Host ("  " + ("─" * 50)) -ForegroundColor DarkGray
Write-Host ""

# ── Create install directory ─────────────────────────────────
Write-Host "  [1/4] Creating folder: $installDir" -ForegroundColor DarkGray
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

# ── Download main script ─────────────────────────────────────
Write-Host "  [2/4] Downloading Overseason..." -ForegroundColor DarkGray
Invoke-WebRequest "$repoBase/overseason.ps1" -OutFile "$installDir\overseason.ps1"

# ── API key setup ────────────────────────────────────────────
Write-Host "  [3/4] Setting up API key..." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Overseason uses Groq's free AI API (no credit card needed)." -ForegroundColor White
Write-Host "  Get your free key at: " -ForegroundColor White -NoNewline
Write-Host "https://console.groq.com/keys" -ForegroundColor Cyan
Write-Host ""

$apiKey = ""
while ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = Read-Host "  Paste your Groq API key (starts with gsk_)"
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Host "  Key cannot be empty. Try again." -ForegroundColor Red
    }
}

"GROQ_API_KEY=$($apiKey.Trim())" | Out-File "$installDir\.env" -Encoding utf8
Write-Host "  API key saved." -ForegroundColor DarkGray

# ── Create launcher and add to PATH ─────────────────────────
Write-Host "  [4/4] Registering 'overseason' command..." -ForegroundColor DarkGray

# Create the .bat launcher
$batContent = "@echo off`r`npowershell -ExecutionPolicy Bypass -NoProfile -File `"%USERPROFILE%\overseason\overseason.ps1`" %*"
$batContent | Out-File "$installDir\overseason.bat" -Encoding ascii

# Add to user PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$installDir*") {
    $newPath = if ($currentPath) { "$currentPath;$installDir" } else { $installDir }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    $pathUpdated = $true
} else {
    $pathUpdated = $false
}

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host ("  " + ("─" * 50)) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed to: $installDir" -ForegroundColor DarkGray
Write-Host ""

if ($pathUpdated) {
    Write-Host "  PATH updated." -ForegroundColor DarkGray
    Write-Host "  IMPORTANT: Close and reopen CMD, then type:" -ForegroundColor Yellow
} else {
    Write-Host "  Type this to start:" -ForegroundColor White
}

Write-Host ""
Write-Host "      overseason" -ForegroundColor Cyan
Write-Host ""
