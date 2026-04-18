# OVERSEASON

```
   ___  _   _ ___ ___ ___ ___ _   ___ ___  _  _ 
  / _ \| | | | __| _ \ __/ __| | | __/ _ \| \| |
 | (_) | |_| | _||   / _|\__ \ |_| _| (_) | .' |
  \___/ \___/|___|_|_\___|___/\___|\___\___/|_|\_|
```

**AI-powered Windows assistant that runs in your terminal.**

Chat with it normally, or ask it to do anything on your PC — it writes a PowerShell script in the background and runs it for you.

---

## Install

Open **PowerShell** and run this one line:

```powershell
irm https://raw.githubusercontent.com/ClickerQuestOffical/overseason/main/install.ps1 | iex
```

The installer will:
- Download Overseason to `%USERPROFILE%\overseason`
- Ask for your free Groq API key
- Register the `overseason` command so you can launch it from anywhere

**After install, close and reopen CMD, then type:**

```
overseason
```

---

## Getting a Free API Key

Overseason uses [Groq](https://console.groq.com) for AI — it's free and requires no credit card.

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Sign up (free)
3. Click **Create API Key**
4. Paste it when the installer asks

---

## What it can do

Just talk to it. Examples:

| You say | What happens |
|---|---|
| `open spotify` | Launches Spotify |
| `create a folder called projects on my desktop` | Creates the folder |
| `show my ip address` | Runs `ipconfig` and shows it |
| `delete all .tmp files in downloads` | Writes and runs a cleanup script |
| `what's 15% of 340` | Just answers in chat |
| `install git` | Requests admin, runs the install |

When it needs to **do** something, it:
1. Shows `Thinking...` while writing the script
2. Runs it automatically (temp file, deleted after)
3. Requests admin elevation if the task requires it

---

## Manual Setup (no installer)

If you prefer to set it up manually:

```powershell
# Clone or download the repo
# Copy .env.example to .env
# Edit .env and add your Groq API key
# Run directly:
powershell -ExecutionPolicy Bypass -File overseason.ps1
```

---

## Notes

- Your API key is stored locally in a `.env` file — never committed to git
- Task scripts are written to a temp file and deleted immediately after running
- Built with PowerShell only — no Node, no Python, no installs required
