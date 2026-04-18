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

Open **PowerShell** and run:

```powershell
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/ClickerQuestOffical/overseason/main/install.ps1" -Headers @{"Cache-Control"="no-cache"} | iex
```

After install, open a new CMD window and type:

```
overseason
```

Works every time, even after restart.

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

## Features

**Tasks** - Just ask it to do something:
- "create a folder on my desktop called projects"
- "make a python script that prints hello world"
- "open settings"
- "delete all .tmp files in downloads"

**Memory** - It remembers things you tell it:
- "my name is Luke" - saved forever
- "my projects are in C:\dev" - uses this in future tasks

**Sessions** - Auto-saves every conversation. Use `/sessions` to reload any past chat.

**Voice** - Type `/voice` to switch to speaking instead of typing. Uses Windows Speech Recognition built into Windows.

**Auto-update** - Checks GitHub for a newer version on every launch and updates itself automatically.

---

## Notes

- API key stored in `.env` locally, never committed to git
- Task scripts are temp files, deleted immediately after running
- Pure PowerShell - no Node, Python, or installs required
