# ============================================================
#  OVERSEASON - AI-powered Windows assistant
# ============================================================

# -- Load API key from .env ----------------------------------
$envFile = Join-Path $PSScriptRoot ".env"
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
    Write-Host "  Edit the .env file here: $PSScriptRoot" -ForegroundColor Yellow
    Write-Host "  Get a free key at: https://console.groq.com/keys" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# -- Banner --------------------------------------------------
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "   ___  _   _ ___ ___ ___ ___ _   ___ ___  _  _ " -ForegroundColor Cyan
    Write-Host "  / _ \| | | | __| _ \ __/ __| | | __/ _ \| \| |" -ForegroundColor Cyan
    Write-Host " | (_) | |_| | _||   / _|\__ \ |_| _| (_) | .' |" -ForegroundColor Cyan
    Write-Host "  \___/ \___/|___|_|_\___|___/\___|\___\___/|_|\_|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  AI-powered Windows assistant" -ForegroundColor DarkCyan
    Write-Host "  Chat naturally, or ask it to do anything on your PC." -ForegroundColor DarkGray
    Write-Host "  'exit' to quit   |   'clear' to reset conversation" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
    Write-Host ""
}

# -- Call Groq API (raw, no JSON mode) -----------------------
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
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) { throw "Invalid API key. Check your .env file." }
        if ($statusCode -eq 429) { throw "Rate limit hit. Wait a moment and try again." }
        throw "API error: $_"
    }
}

# -- Two-step AI: think, then produce final JSON -------------
function Invoke-AIResponse {
    param([array]$ChatHistory)

    # Step 1: Reasoning pass - think through what to do
    $thinkingPrompt = @"
You are Overseason, an AI assistant for Windows PowerShell.

A user sent you this message. Think carefully:
- Is this a task to perform on the computer, or just conversation?
- If it is a task, what is the exact correct PowerShell to accomplish it?
- Think about what could go wrong and how to avoid it.

CRITICAL POWERSHELL RULES YOU MUST FOLLOW:
1. ALWAYS use double quotes for strings containing variables.
   WRONG: '$env:USERPROFILE\Downloads'
   RIGHT:  "$env:USERPROFILE\Downloads"

2. Common correct paths (double quotes required):
   Desktop:   "$env:USERPROFILE\Desktop"
   Downloads: "$env:USERPROFILE\Downloads"
   Documents: "$env:USERPROFILE\Documents"
   Music:     "$env:USERPROFILE\Music"
   Pictures:  "$env:USERPROFILE\Pictures"

3. Correct ways to open Windows built-in apps:
   Calculator:    Start-Process "calc.exe"
   Notepad:       Start-Process "notepad.exe"
   Clock/Alarms:  Start-Process "ms-clock:"
   Settings:      Start-Process "ms-settings:"
   Store:         Start-Process "ms-windows-store:"
   Calendar:      Start-Process "outlookcal:"
   Mail:          Start-Process "outlookmail:"
   Maps:          Start-Process "bingmaps:"
   Weather:       Start-Process "bingweather:"
   Paint:         Start-Process "mspaint.exe"
   Snipping Tool: Start-Process "SnippingTool.exe"
   Task Manager:  Start-Process "taskmgr.exe"
   File Explorer: Start-Process "explorer.exe"
   Command Prompt:Start-Process "cmd.exe"
   WordPad:       Start-Process "wordpad.exe"
   Spotify:       Start-Process "spotify:"
   Browser (Edge):Start-Process "msedge.exe"

4. For creating files with content, always use Out-File or Set-Content with double-quoted paths.
5. For creating folders, use New-Item with -ItemType Directory and double-quoted paths.
6. For code files, write the full correct code content into the file.
7. Multi-line scripts should use here-strings with proper syntax.

Think step by step about the correct approach.
"@

    $thinkMessages = @(
        @{ role = "system"; content = $thinkingPrompt }
    )
    # Add the last few messages for context
    $contextMessages = $ChatHistory | Where-Object { $_.role -ne "system" } | Select-Object -Last 6
    foreach ($msg in $contextMessages) {
        $thinkMessages += $msg
    }

    $reasoning = Invoke-GroqRaw -Messages $thinkMessages -JsonMode $false

    # Step 2: Final JSON output using the reasoning as context
    $outputPrompt = @"
You are Overseason, an AI assistant for Windows PowerShell.

You have already reasoned through the user's request. Now produce the final response as a JSON object.

Your reasoning was:
$reasoning

Based on that reasoning, respond with ONLY a valid JSON object in one of these two formats:

For conversation (greetings, questions, explanations):
{"type":"chat","reply":"your short casual reply, 1-2 sentences max"}

For computer tasks:
{"type":"task","reply":"one short sentence saying what you are doing","script":"the exact powershell script","requiresAdmin":false}

FINAL RULES:
- The script must use double quotes around any path with a variable in it.
- requiresAdmin is true only for system-level changes (install software, edit registry, system settings).
- Return ONLY the raw JSON. No markdown. No code fences. No explanation. Just the JSON object.
"@

    $outputMessages = @(
        @{ role = "system"; content = $outputPrompt }
    )
    foreach ($msg in $contextMessages) {
        $outputMessages += $msg
    }

    return Invoke-GroqRaw -Messages $outputMessages -JsonMode $true
}

# -- Run a generated task script -----------------------------
function Invoke-Task {
    param(
        [string]$Script,
        [bool]$RequiresAdmin
    )

    $tmpFile = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        "overseason_task_$([System.Guid]::NewGuid().ToString('N')).ps1"
    )

    # Write with UTF8 encoding so code files come out correct
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

# -- Conversation system prompt ------------------------------
$systemPrompt = @"
You are Overseason, a casual AI assistant that helps users with their Windows PC.
Keep all chat replies short - 1 to 2 sentences, casual and friendly.
"@

# -- Main loop -----------------------------------------------
Show-Banner

$history = [System.Collections.Generic.List[hashtable]]::new()
$history.Add(@{ role = "system"; content = $systemPrompt })

while ($true) {

    Write-Host "  You: " -ForegroundColor White -NoNewline
    $userInput = Read-Host

    if ([string]::IsNullOrWhiteSpace($userInput)) { continue }

    switch ($userInput.Trim().ToLower()) {
        "exit" {
            Write-Host ""
            Write-Host "  Goodbye." -ForegroundColor DarkGray
            Write-Host ""
            exit
        }
        "clear" {
            $history = [System.Collections.Generic.List[hashtable]]::new()
            $history.Add(@{ role = "system"; content = $systemPrompt })
            Show-Banner
            continue
        }
    }

    $history.Add(@{ role = "user"; content = $userInput })

    Write-Host ""
    Write-Host "  Thinking..." -ForegroundColor DarkYellow -NoNewline

    $raw = $null
    $parsed = $null

    try {
        $raw = Invoke-AIResponse -ChatHistory $history
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

    if ($parsed.type -eq "task") {
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
    else {
        Write-Host "  Overseason: $($parsed.reply)" -ForegroundColor Cyan
    }

    Write-Host ""
}
