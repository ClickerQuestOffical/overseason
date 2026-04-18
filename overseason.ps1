# ============================================================
#  OVERSEASON - AI-powered Windows assistant
#  Version: 1.2.0
# ============================================================

$VERSION    = "1.2.0"
$GH_USER    = "YOUR_USERNAME"
$GH_REPO    = "overseason"
$INSTALL_DIR = $PSScriptRoot

# -- Load API key from .env ----------------------------------
$envFile = Join-Path $INSTALL_DIR ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^GROQ_API_KEY=(.+)$") {
            $env:GROQ_API_KEY = $Matches[1].Trim()
        }
    }
}

if (-not $env:GROQ_API_KEY) {
    Write-Host ""
    Write-Host "  ERROR: GROQ_API_KEY not set." -ForegroundColor Red
    Write-Host "  Edit the .env file in: $INSTALL_DIR" -ForegroundColor Yellow
    Write-Host "  Get a free key at: https://console.groq.com/keys" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# -- Banner --------------------------------------------------
function Show-Banner {
    param([bool]$VoiceOn = $false)
    Clear-Host
    Write-Host ""
    Write-Host "   ___  _   _ ___ ___ ___ ___ _   ___ ___  _  _ " -ForegroundColor Cyan
    Write-Host "  / _ \| | | | __| _ \ __/ __| | | __/ _ \| \| |" -ForegroundColor Cyan
    Write-Host " | (_) | |_| | _||   / _|\__ \ |_| _| (_) | .' |" -ForegroundColor Cyan
    Write-Host "  \___/ \___/|___|_|_\___|___/\___|\___\___/|_|\_|" -ForegroundColor Cyan
    Write-Host ""
    $voiceStatus = if ($VoiceOn) { "  [VOICE ON]" } else { "" }
    Write-Host "  AI-powered Windows assistant  v$VERSION$voiceStatus" -ForegroundColor DarkCyan
    Write-Host "  exit  |  clear  |  /voice  |  /sessions  |  /memory" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
    Write-Host ""
}

# -- Auto-update ---------------------------------------------
function Check-ForUpdates {
    try {
        Write-Host "  Checking for updates..." -ForegroundColor DarkGray -NoNewline
        $url = "https://raw.githubusercontent.com/$GH_USER/$GH_REPO/main/version.txt"
        $latest = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content.Trim()

        if ($latest -and $latest -ne $VERSION) {
            Write-Host "`r                          `r" -NoNewline
            Write-Host "  New version available: v$latest  (you have v$VERSION)" -ForegroundColor Yellow
            Write-Host "  Updating now..." -ForegroundColor DarkYellow

            $scriptUrl = "https://raw.githubusercontent.com/$GH_USER/$GH_REPO/main/overseason.ps1"
            Invoke-WebRequest -Uri $scriptUrl -OutFile "$INSTALL_DIR\overseason.ps1" -UseBasicParsing

            Write-Host "  Updated to v$latest! Restarting..." -ForegroundColor Green
            Start-Sleep -Seconds 1
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$INSTALL_DIR\overseason.ps1`""
            exit
        }
        else {
            Write-Host "`r                          `r" -NoNewline
        }
    }
    catch {
        # No internet or GitHub down - just continue silently
        Write-Host "`r                          `r" -NoNewline
    }
}

# -- Memory --------------------------------------------------
$memoryFile = Join-Path $INSTALL_DIR "memory.json"

function Load-Memory {
    if (Test-Path $memoryFile) {
        try {
            $raw = Get-Content $memoryFile -Raw
            $obj = $raw | ConvertFrom-Json
            $ht  = @{}
            $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            return $ht
        }
        catch { return @{} }
    }
    return @{}
}

function Save-Memory {
    param([hashtable]$Memory)
    $Memory | ConvertTo-Json | Out-File $memoryFile -Encoding utf8
}

function Memory-ToContext {
    param([hashtable]$Memory)
    if ($Memory.Count -eq 0) { return "" }
    $lines = @("Things you know about this user (use this context naturally):")
    foreach ($key in $Memory.Keys) {
        $lines += "  - $key`: $($Memory[$key])"
    }
    return ($lines -join "`n")
}

# -- Sessions ------------------------------------------------
$sessionsDir = Join-Path $INSTALL_DIR "sessions"
if (-not (Test-Path $sessionsDir)) {
    New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
}

function Save-Session {
    param([System.Collections.Generic.List[hashtable]]$History)
    $messages = @($History | Where-Object { $_.role -ne "system" })
    if ($messages.Count -eq 0) { return }
    $timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $sessionFile = Join-Path $sessionsDir "session_$timestamp.json"
    $messages | ConvertTo-Json -Depth 5 | Out-File $sessionFile -Encoding utf8
}

function Show-Sessions {
    $files = Get-ChildItem $sessionsDir -Filter "*.json" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 15

    if (-not $files -or $files.Count -eq 0) {
        Write-Host ""
        Write-Host "  No saved sessions yet." -ForegroundColor DarkGray
        Write-Host ""
        return $null
    }

    Write-Host ""
    Write-Host "  Saved Sessions:" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * 40)) -ForegroundColor DarkGray

    for ($i = 0; $i -lt $files.Count; $i++) {
        $date    = $files[$i].LastWriteTime.ToString("MMM dd yyyy  hh:mm tt")
        $size    = [math]::Round((Get-Item $files[$i].FullName).Length / 1KB, 1)
        Write-Host "  [$($i + 1)] $date  (${size}KB)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  Enter number to load, or press Enter to cancel: " -ForegroundColor DarkGray -NoNewline
    $choice = Read-Host

    if ([string]::IsNullOrWhiteSpace($choice)) { return $null }

    $idx = 0
    if ([int]::TryParse($choice, [ref]$idx)) {
        $idx -= 1
        if ($idx -ge 0 -and $idx -lt $files.Count) {
            return $files[$idx].FullName
        }
    }
    return $null
}

function Load-Session {
    param([string]$FilePath)
    try {
        $messages = Get-Content $FilePath -Raw | ConvertFrom-Json
        $list = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($msg in $messages) {
            $list.Add(@{ role = $msg.role; content = $msg.content })
        }
        return $list
    }
    catch {
        Write-Host "  Failed to load session." -ForegroundColor Red
        return $null
    }
}

# -- Voice ---------------------------------------------------
$script:voiceMode  = $false
$script:recognizer = $null

function Init-Voice {
    try {
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $r = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $grammar = New-Object System.Speech.Recognition.DictationGrammar
        $r.LoadGrammar($grammar)
        $r.SetInputToDefaultAudioDevice()
        return $r
    }
    catch {
        Write-Host ""
        Write-Host "  Voice not available: $_" -ForegroundColor Red
        Write-Host "  Make sure a microphone is connected and Windows Speech Recognition is enabled." -ForegroundColor DarkGray
        Write-Host ""
        return $null
    }
}

function Get-VoiceInput {
    param($Recognizer)
    Write-Host "  Listening... (up to 10 seconds)" -ForegroundColor Magenta -NoNewline
    try {
        $result = $Recognizer.Recognize([TimeSpan]::FromSeconds(10))
        Write-Host "`r                                   `r" -NoNewline
        if ($result -and $result.Text) {
            Write-Host "  You (voice): " -ForegroundColor DarkGray -NoNewline
            Write-Host $result.Text -ForegroundColor White
            return $result.Text
        }
        else {
            Write-Host "  (nothing heard - try again)" -ForegroundColor DarkGray
            return $null
        }
    }
    catch {
        Write-Host "`r                                   `r" -NoNewline
        Write-Host "  Voice error: $_" -ForegroundColor Red
        return $null
    }
}

# -- Groq API ------------------------------------------------
function Invoke-GroqRaw {
    param(
        [array]$Messages,
        [bool]$JsonMode = $false
    )

    $requestBody = @{
        model       = "llama-3.3-70b-versatile"
        messages    = $Messages
        temperature = 0.2
    }
    if ($JsonMode) {
        $requestBody["response_format"] = @{ type = "json_object" }
    }

    $body = $requestBody | ConvertTo-Json -Depth 10 -Compress

    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.groq.com/openai/v1/chat/completions" `
            -Method POST `
            -Headers @{
                "Authorization" = "Bearer $env:GROQ_API_KEY"
                "Content-Type"  = "application/json"
            } `
            -Body $body `
            -ErrorAction Stop

        return $response.choices[0].message.content
    }
    catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -eq 401) { throw "Invalid API key. Check your .env file." }
        if ($code -eq 429) { throw "Rate limit hit. Wait a moment." }
        throw "API error: $_"
    }
}

# -- Two-step AI (think then output) -------------------------
function Invoke-AIResponse {
    param(
        [array]$ChatHistory,
        [hashtable]$Memory
    )

    $memContext = Memory-ToContext -Memory $Memory

    # Step 1: Reason through the request
    $thinkPrompt = @"
You are Overseason, an AI assistant for Windows PowerShell.

$memContext

The user sent you a message. Think carefully about what they want:

DECISION: Is this...
A) Just conversation or a question (chat)
B) Something to do on the computer (task)
C) Asking you to remember something (remember)

If it is a task, think about the exact correct PowerShell script.

STRICT POWERSHELL RULES:
1. Variable paths MUST use double quotes, NEVER single quotes:
   CORRECT: New-Item -Path "$env:USERPROFILE\Downloads\MyFolder" -ItemType Directory -Force
   WRONG:   New-Item -Path '$env:USERPROFILE\Downloads\MyFolder' -ItemType Directory -Force

2. Correct built-in Windows app commands:
   Calculator:    Start-Process "calc.exe"
   Notepad:       Start-Process "notepad.exe"
   Clock/Alarms:  Start-Process "ms-clock:"
   Settings:      Start-Process "ms-settings:"
   Microsoft Store: Start-Process "ms-windows-store:"
   Paint:         Start-Process "mspaint.exe"
   File Explorer: Start-Process "explorer.exe"
   Task Manager:  Start-Process "taskmgr.exe"
   Edge browser:  Start-Process "msedge.exe"
   Spotify:       Start-Process "spotify:"
   Camera:        Start-Process "microsoft.windows.camera:"
   Photos:        Start-Process "ms-photos:"
   Maps:          Start-Process "bingmaps:"

3. Common path patterns (always double-quoted):
   Desktop:   "$env:USERPROFILE\Desktop"
   Downloads: "$env:USERPROFILE\Downloads"
   Documents: "$env:USERPROFILE\Documents"
   Music:     "$env:USERPROFILE\Music"
   Pictures:  "$env:USERPROFILE\Pictures"

4. Creating a folder:
   New-Item -ItemType Directory -Path "$env:USERPROFILE\Desktop\FolderName" -Force

5. Creating a file with content:
   Set-Content -Path "$env:USERPROFILE\Desktop\file.txt" -Value "content here"

6. For multi-line code files, use a here-string assigned to a variable, then Out-File:
   `$code = @'
   your code here
   '@
   `$code | Out-File -FilePath "$env:USERPROFILE\Desktop\script.py" -Encoding utf8

7. requiresAdmin should be true ONLY for: installing software, editing registry,
   changing system settings, modifying system folders.

Think through the exact correct approach now.
"@

    $thinkMessages = @(@{ role = "system"; content = $thinkPrompt })
    $recent = @($ChatHistory | Where-Object { $_.role -ne "system" } | Select-Object -Last 6)
    foreach ($m in $recent) { $thinkMessages += $m }

    $reasoning = Invoke-GroqRaw -Messages $thinkMessages -JsonMode $false

    # Step 2: Produce the final JSON
    $outputPrompt = @"
You are Overseason. Based on your reasoning below, produce the final JSON response.

Your reasoning:
$reasoning

Respond with ONLY a valid JSON object. Choose the correct format:

For conversation or questions:
{"type":"chat","reply":"short casual answer, 1-2 sentences max"}

For computer tasks:
{"type":"task","reply":"one sentence saying what you are doing","script":"the exact powershell","requiresAdmin":false}

For remembering something:
{"type":"remember","key":"short_key_name","value":"the value to store","reply":"short confirmation like got it or noted"}

FINAL RULES:
- Scripts must use double quotes for any path containing a variable.
- Do not wrap scripts in code fences or markdown.
- Return ONLY the raw JSON object. Nothing else.
"@

    $outputMessages = @(@{ role = "system"; content = $outputPrompt })
    foreach ($m in $recent) { $outputMessages += $m }

    return Invoke-GroqRaw -Messages $outputMessages -JsonMode $true
}

# -- Run task script -----------------------------------------
function Invoke-Task {
    param([string]$Script, [bool]$RequiresAdmin)

    $tmpFile = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        "overseason_task_$([System.Guid]::NewGuid().ToString('N')).ps1"
    )
    [System.IO.File]::WriteAllText($tmpFile, $Script, [System.Text.Encoding]::UTF8)

    try {
        if ($RequiresAdmin) {
            Write-Host ""
            Write-Host "  [!] Admin required - requesting elevation..." -ForegroundColor Yellow
            Write-Host ""
            Start-Process powershell `
                -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$tmpFile`"" `
                -Verb RunAs `
                -Wait
        }
        else {
            powershell -ExecutionPolicy Bypass -NoProfile -File $tmpFile
        }
    }
    finally {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
#  MAIN
# ============================================================

$memory = Load-Memory
$systemPrompt = "You are Overseason, a casual and helpful AI Windows assistant. Keep replies short and friendly."

Show-Banner
Check-ForUpdates

$history = [System.Collections.Generic.List[hashtable]]::new()
$history.Add(@{ role = "system"; content = $systemPrompt })

# Try/finally catches normal exit AND Ctrl+C - auto-saves session
try {
    while ($true) {

        # Voice or keyboard input
        if ($script:voiceMode -and $script:recognizer) {
            $userInput = Get-VoiceInput -Recognizer $script:recognizer
            if (-not $userInput) { continue }
        }
        else {
            Write-Host "  You: " -ForegroundColor White -NoNewline
            $userInput = Read-Host
        }

        if ([string]::IsNullOrWhiteSpace($userInput)) { continue }

        # -- Built-in commands ---------------------------------
        switch ($userInput.Trim().ToLower()) {

            "exit" {
                Save-Session -History $history
                Write-Host ""
                Write-Host "  Session saved. Goodbye." -ForegroundColor DarkGray
                Write-Host ""
                if ($script:recognizer) { $script:recognizer.Dispose() }
                exit
            }

            "clear" {
                Save-Session -History $history
                $history = [System.Collections.Generic.List[hashtable]]::new()
                $history.Add(@{ role = "system"; content = $systemPrompt })
                Show-Banner -VoiceOn $script:voiceMode
                continue
            }

            "/voice" {
                if (-not $script:voiceMode) {
                    $script:recognizer = Init-Voice
                    if ($script:recognizer) {
                        $script:voiceMode = $true
                        Write-Host ""
                        Write-Host "  Voice mode ON - speak after you see 'Listening...'" -ForegroundColor Magenta
                        Write-Host ""
                    }
                }
                else {
                    $script:voiceMode = $false
                    if ($script:recognizer) {
                        $script:recognizer.Dispose()
                        $script:recognizer = $null
                    }
                    Write-Host ""
                    Write-Host "  Voice mode OFF" -ForegroundColor DarkGray
                    Write-Host ""
                }
                continue
            }

            "/sessions" {
                $sessionFile = Show-Sessions
                if ($sessionFile) {
                    $loaded = Load-Session -FilePath $sessionFile
                    if ($loaded) {
                        Save-Session -History $history
                        $history = [System.Collections.Generic.List[hashtable]]::new()
                        $history.Add(@{ role = "system"; content = $systemPrompt })
                        foreach ($msg in $loaded) { $history.Add($msg) }
                        Write-Host ""
                        Write-Host "  Session loaded - continuing where you left off." -ForegroundColor Green
                        Write-Host ""
                    }
                }
                continue
            }

            "/memory" {
                Write-Host ""
                if ($memory.Count -eq 0) {
                    Write-Host "  No memories saved yet. Just tell me things like 'my name is Luke'." -ForegroundColor DarkGray
                }
                else {
                    Write-Host "  What I remember about you:" -ForegroundColor Cyan
                    Write-Host ("  " + ("-" * 40)) -ForegroundColor DarkGray
                    foreach ($key in $memory.Keys) {
                        Write-Host "  $key`: $($memory[$key])" -ForegroundColor White
                    }
                }
                Write-Host ""
                continue
            }
        }

        # -- Send to AI ----------------------------------------
        $history.Add(@{ role = "user"; content = $userInput })

        Write-Host ""
        Write-Host "  Thinking..." -ForegroundColor DarkYellow -NoNewline

        $raw    = $null
        $parsed = $null

        try {
            $raw    = Invoke-AIResponse -ChatHistory $history -Memory $memory
            $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Host "`r                      `r" -NoNewline
            Write-Host "  Overseason: Something went wrong - $_" -ForegroundColor Red
            Write-Host ""
            $history.RemoveAt($history.Count - 1)
            continue
        }

        Write-Host "`r                      `r" -NoNewline
        $history.Add(@{ role = "assistant"; content = $raw })

        switch ($parsed.type) {
            "task" {
                Write-Host "  Overseason: $($parsed.reply)" -ForegroundColor Cyan
                Write-Host ""
                Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
                Write-Host ""
                try {
                    Invoke-Task -Script $parsed.script -RequiresAdmin ([bool]$parsed.requiresAdmin)
                }
                catch {
                    Write-Host "  [Task failed: $_]" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
                Write-Host "  Done." -ForegroundColor Green
            }
            "remember" {
                $memory[$parsed.key] = $parsed.value
                Save-Memory -Memory $memory
                Write-Host "  Overseason: $($parsed.reply)" -ForegroundColor Cyan
            }
            default {
                Write-Host "  Overseason: $($parsed.reply)" -ForegroundColor Cyan
            }
        }

        Write-Host ""
    }
}
finally {
    # Auto-save runs on exit, Ctrl+C, or any crash
    Save-Session -History $history
    if ($script:recognizer) { $script:recognizer.Dispose() }
}
