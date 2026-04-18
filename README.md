# OVERSEASON

```
   ___  _   _ ___ ___ ___ ___ _   ___ ___  _  _ 
  / _ \| | | | __| _ \ __/ __| | | __/ _ \| \| |
 | (_) | |_| | _||   / _|\__ \ |_| _| (_) | .' |
  \___/ \___/|___|_|_\___|___/\___|\___\___/|_|\_|
```

**AI-powered Windows assistant that runs in your terminal.**

Chat with it, ask it to do things on your PC, and it writes and runs PowerShell scripts in the background.

---

## Install

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/ClickerQuestOffical/overseason/main/install.ps1?t=1 | iex
```

After install, open a **new** CMD or PowerShell window and type:

```
overseason
```

---

## Getting a Free API Key

Overseason uses [Groq](https://console.groq.com) - free, no credit card needed.

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Sign up (free)
3. Click **Create API Key**
4. Paste it when the installer asks

---

## Commands

| Command | What it does |
|---|---|
| `exit` | Save session and quit |
| `clear` | Save session and start fresh |
| `/voice` | Toggle voice input on/off |
| `/sessions` | Browse and reload past conversations |
| `/memory` | See everything Overseason remembers about you |

---

## What it can do

Just ask it anything:

| You say | What happens |
|---|---|
| `open calculator` | Opens the calculator |
| `create a folder on my desktop called projects` | Creates the folder |
| `make a python script that prints hello world` | Writes the file |
| `show my ip address` | Runs ipconfig |
| `delete all .tmp files in downloads` | Cleans them up |
| `my name is Luke` | Remembers it forever |
| `what is 15% of 340` | Just answers in chat |

---

## Troubleshooting

**'overseason' is not recognized after install**

Run this one line in PowerShell:

```powershell
"@echo off`r`npowershell -ExecutionPolicy Bypass -NoProfile -File `"%USERPROFILE%\overseason\overseason.ps1`"" | Out-File "$env:LOCALAPPDATA\Microsoft\WindowsApps\overseason.bat" -Encoding ascii
```

Then open a new CMD window and type `overseason`.

**Installer says 404 on download**

PowerShell may have cached an old version. Run this instead:

```powershell
irm "https://raw.githubusercontent.com/ClickerQuestOffical/overseason/main/install.ps1?t=$(Get-Date -UFormat %s)" | iex
```

**Run directly without installing**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\overseason\overseason.ps1"
```

---

## Notes

- API key stored in `.env` locally, never committed to git
- Task scripts are temp files deleted immediately after running
- Conversations auto-save to the `sessions` folder on exit
- Pure PowerShell - no Node, Python, or extra installs required
