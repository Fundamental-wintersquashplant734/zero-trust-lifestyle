# 🛡️ zero-trust-lifestyle - Simple automation for a guarded workflow

[![Download](https://img.shields.io/badge/Download-Releases-blue?style=for-the-badge&logo=github)](https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases)

## 📥 Download

Visit this page to download: [GitHub Releases](https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases)

## 🧭 What this app does

zero-trust-lifestyle is a set of 33 Bash scripts that help automate parts of a cautious day-to-day workflow. It is made for people who want more control over routine tasks tied to privacy, meetings, Slack, and general work habits.

It focuses on simple scripts you can run one at a time. Each script handles a small job, so you do not need to manage a complex setup.

## 🪟 Windows setup

This app is built around Bash scripts, so Windows users need a Bash shell to run it.

### Option 1: Use WSL
WSL lets you run Linux tools on Windows.

1. Open the Microsoft Store.
2. Install Ubuntu or another Linux distro.
3. Open the installed distro from the Start menu.
4. Visit the [GitHub Releases](https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases) page.
5. Download the release files from that page.
6. Move the files into your WSL home folder.
7. Run the scripts from the WSL terminal.

### Option 2: Use Git Bash
Git Bash gives you a Bash terminal on Windows.

1. Install Git for Windows.
2. Open Git Bash.
3. Visit the [GitHub Releases](https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases) page.
4. Download the release files from that page.
5. Extract the files into a folder you can find again.
6. Run the scripts from Git Bash.

## 🗂️ What you get

The release package includes scripts for tasks such as:

- meeting prep and cleanup
- Slack checks and message flow
- privacy checks
- simple operating system tasks
- OSINT-style lookup helpers
- productivity routines
- routine safety steps for daily use
- small shell tools for repeat work

Each script is meant to do one thing. That makes it easier to use and easier to stop when you do not need it.

## 🔧 Basic requirements

You need:

- Windows 10 or Windows 11
- a Bash shell, such as WSL or Git Bash
- a web browser
- a place to save the downloaded files
- enough space for a small script folder

If you want the smoothest setup, use WSL.

## ▶️ How to run it

1. Open your Bash terminal.
2. Go to the folder where you saved the files.
3. Look for the main script files.
4. Run the script you want with Bash.

Example:

```bash
bash script-name.sh
```

If the file does not run, make sure you are in the right folder and that your terminal can see the file.

## 🧰 Common use cases

### 📅 Meetings
Use the scripts to prep for meetings, clean up notes, or handle small reminders tied to the meeting flow.

### 💬 Slack
Use the scripts to check Slack-related tasks, keep messages in order, or support a low-noise workflow.

### 🔒 Privacy
Use the scripts to check settings, reduce clutter, and support a tighter daily routine.

### 🧠 Daily workflow
Use the scripts to automate repeat work that you do not want to handle by hand each day.

## 📁 Folder layout

A typical release may include:

- `README.md`
- a folder with the Bash scripts
- helper files
- sample config files
- small text notes for each script

Keep the folder in a place you can reach from your terminal.

## 🛠️ Simple usage steps

1. Download the release from the [GitHub Releases](https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases) page.
2. Extract the files.
3. Open WSL or Git Bash.
4. Change to the extracted folder.
5. Pick one script.
6. Run it with `bash`.
7. Repeat only the scripts you need.

## 🔍 Who this is for

This project fits users who want:

- a plain Bash tool set
- small scripts instead of a large app
- a tighter routine for work and home
- privacy-first habits
- simple automation on Windows through Bash

## 🧩 Script behavior

Most scripts in this project follow a few simple patterns:

- they read input from the terminal or files
- they run one task at a time
- they print clear output
- they avoid heavy setup
- they work best when you keep the folder structure intact

## ⚙️ If a script asks for input

Some scripts may ask for:

- a file name
- a folder path
- a Slack-related setting
- a meeting label
- a search term
- a simple yes or no choice

Type the requested value and press Enter.

## 🧼 Before you start

Make sure you:

- download the full release package
- keep the files together in one folder
- use a Bash terminal, not Command Prompt
- close old terminal windows if the script does not start
- check that the file name matches the script you want

## 🔐 Privacy and use

This project is built around a zero-trust mindset. That means it aims to reduce blind trust and keep routine work under your control.

Use the scripts on files and accounts you manage. Keep your setup local when you can, and review any script before you run it if you want to see what it does.

## 🧪 Troubleshooting

### The file will not open
- Make sure you downloaded the release files from the release page.
- Check that the file is fully extracted.
- Open it from WSL or Git Bash.

### Bash says the file does not exist
- Check the folder name.
- Use `ls` to list the files in the folder.
- Make sure you typed the script name the same way it appears in the folder.

### Nothing happens after I run it
- Try another terminal window.
- Confirm that the file has execute permission if you are on WSL.
- Run it with `bash script-name.sh`.

### Windows opens the wrong app
- Right-click the file.
- Choose to open it with Git Bash or use WSL.
- Do not double-click Bash scripts in File Explorer if Windows tries to treat them like text files

## 📝 Example command flow

```bash
cd ~/Downloads/zero-trust-lifestyle
ls
bash meeting-setup.sh
```

## 📌 Download again

If you need the files again, visit the release page here: [https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases](https://github.com/Fundamental-wintersquashplant734/zero-trust-lifestyle/releases)

## 🧾 Project details

- Repository: zero-trust-lifestyle
- Type: Bash script collection
- Focus: privacy, security, productivity, Slack, meetings
- Platform target: Windows through WSL or Git Bash