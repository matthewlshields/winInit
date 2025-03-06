function Get-TerminalSettings {
    param (
        [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings.json")
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at: $ConfigPath"
        }
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config.terminal
    }
    catch {
        Write-Error "Failed to load terminal configuration: $_"
        return $null
    }
}

function Set-TerminalFont {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FontName,
        [int]$FontSize = 12
    )

    try {
        # Set for current session
        $Host.UI.RawUI.FontFamily = $FontName
        $Host.UI.RawUI.FontSize = $FontSize

        # Update Windows Terminal settings if available
        $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        if (Test-Path $wtSettingsPath) {
            $wtSettings = Get-Content -Path $wtSettingsPath -Raw | ConvertFrom-Json
            $wtSettings.profiles.defaults.font.face = $FontName
            $wtSettings.profiles.defaults.font.size = $FontSize
            $wtSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $wtSettingsPath
            Write-Host "Windows Terminal font settings updated successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to set terminal font: $_"
    }
}

function Set-TerminalColors {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Background,
        [Parameter(Mandatory=$true)]
        [string]$Foreground,
        [Parameter(Mandatory=$true)]
        [string]$Cursor
    )

    try {
        # Update Windows Terminal settings if available
        $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        if (Test-Path $wtSettingsPath) {
            $wtSettings = Get-Content -Path $wtSettingsPath -Raw | ConvertFrom-Json
            $wtSettings.profiles.defaults.background = $Background
            $wtSettings.profiles.defaults.foreground = $Foreground
            $wtSettings.profiles.defaults.cursorColor = $Cursor
            $wtSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $wtSettingsPath
            Write-Host "Windows Terminal color settings updated successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to set terminal colors: $_"
    }
}

function Set-OhMyPoshPrompt {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Theme
    )

    try {
        # Check if Oh My Posh is installed
        if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
            Write-Error "Oh My Posh is not installed. Please install it first."
            return
        }

        # Create or update PowerShell profile
        $profilePath = $PROFILE
        $profileDir = Split-Path -Parent $profilePath

        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }

        # Add Oh My Posh initialization to profile
        $ohMyPoshInit = @"
# Oh My Posh Configuration
oh-my-posh init pwsh --config "$Theme" | Invoke-Expression
"@

        if (Test-Path $profilePath) {
            $currentProfile = Get-Content $profilePath -Raw
            if ($currentProfile -notmatch 'oh-my-posh init') {
                Add-Content -Path $profilePath -Value "`n$ohMyPoshInit"
            }
        } else {
            Set-Content -Path $profilePath -Value $ohMyPoshInit
        }

        # Initialize Oh My Posh in current session
        oh-my-posh init pwsh --config "$Theme" | Invoke-Expression

        Write-Host "Oh My Posh configured successfully with theme: $Theme" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure Oh My Posh: $_"
    }
}

function Set-CustomPrompt {
    param (
        [bool]$ShowGitStatus = $true,
        [bool]$ShowExecutionTime = $true,
        [bool]$ShowCurrentDirectory = $true,
        [bool]$UseOhMyPosh = $false,
        [string]$OhMyPoshTheme = "agnoster"
    )

    if ($UseOhMyPosh) {
        Set-OhMyPoshPrompt -Theme $OhMyPoshTheme
        return
    }

    $promptScript = {
        $origLastExitCode = $LASTEXITCODE
        $curPath = $ExecutionContext.SessionState.Path.CurrentLocation.Path
        $prompt = "`n"

        if ($ShowCurrentDirectory) {
            $prompt += "[DIR] $curPath`n"
        }

        if ($ShowGitStatus -and (Get-Command git -ErrorAction SilentlyContinue)) {
            $gitBranch = git branch --show-current 2>$null
            if ($gitBranch) {
                $prompt += "[GIT] $gitBranch "
                $gitStatus = git status --porcelain 2>$null
                if ($gitStatus) {
                    $prompt += "*"
                }
                $prompt += "`n"
            }
        }

        if ($ShowExecutionTime) {
            $prompt += "[$(Get-Date -Format "HH:mm:ss")]`n"
        }

        $prompt += "> "
        $LASTEXITCODE = $origLastExitCode
        return $prompt
    }

    Set-Item -Path Function:\prompt -Value $promptScript
    Write-Host "Custom prompt configured successfully" -ForegroundColor Green
}

function Set-TerminalConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $config = Get-TerminalSettings
    if (-not $config) { return }

    Write-Host "`nConfiguring Terminal Settings" -ForegroundColor Cyan
    Write-Host "--------------------------" -ForegroundColor Cyan

    # Check current Windows Terminal settings
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $changes = @()
    
    if (Test-Path $wtSettingsPath) {
        $wtSettings = Get-Content -Path $wtSettingsPath -Raw | ConvertFrom-Json
        
        # Check font settings
        if ($PSCmdlet.ShouldProcess("Terminal font", "Set terminal font settings")) {
            $currentFont = $wtSettings.profiles.defaults.font.face
            $currentSize = $wtSettings.profiles.defaults.font.size
            
            if ($currentFont -ne $config.font.name -or $currentSize -ne $config.font.size) {
                $changes += "Update font to $($config.font.name) (size: $($config.font.size))"
                if (-not $WhatIf) {
                    Set-TerminalFont -FontName $config.font.name -FontSize $config.font.size
                }
            }
        }

        # Check color settings
        if ($PSCmdlet.ShouldProcess("Terminal colors", "Set terminal color scheme")) {
            $currentBg = $wtSettings.profiles.defaults.background
            $currentFg = $wtSettings.profiles.defaults.foreground
            $currentCursor = $wtSettings.profiles.defaults.cursorColor
            
            if ($currentBg -ne $config.colorScheme.background -or 
                $currentFg -ne $config.colorScheme.foreground -or 
                $currentCursor -ne $config.colorScheme.cursor) {
                $changes += "Update color scheme (Background: $($config.colorScheme.background), Foreground: $($config.colorScheme.foreground))"
                if (-not $WhatIf) {
                    Set-TerminalColors -Background $config.colorScheme.background `
                                     -Foreground $config.colorScheme.foreground `
                                     -Cursor $config.colorScheme.cursor
                }
            }
        }
    } else {
        $changes += "Windows Terminal settings file not found - will create with default settings"
    }

    # Check prompt settings
    if ($PSCmdlet.ShouldProcess("Terminal prompt", "Configure custom prompt")) {
        $promptChanged = $false
        
        if ($config.prompt.useOhMyPosh) {
            if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
                $changes += "Install Oh My Posh"
                $promptChanged = $true
            } elseif (-not (Test-Path $PROFILE) -or -not (Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue | Select-String -Pattern "oh-my-posh init")) {
                $changes += "Configure Oh My Posh with theme: $($config.prompt.ohMyPoshTheme)"
                $promptChanged = $true
            }
        } else {
            # Check if current prompt matches desired configuration
            $currentPrompt = Get-Content Function:\prompt -ErrorAction SilentlyContinue
            if (-not $currentPrompt -or 
                ($config.prompt.showGitStatus -and -not ($currentPrompt.ToString() -match '\[GIT\]')) -or
                ($config.prompt.showExecutionTime -and -not ($currentPrompt.ToString() -match '\[\$\(Get-Date')) -or
                ($config.prompt.showCurrentDirectory -and -not ($currentPrompt.ToString() -match '\[DIR\]'))) {
                $changes += "Update custom prompt configuration"
                $promptChanged = $true
            }
        }

        if ($promptChanged -and -not $WhatIf) {
            Set-CustomPrompt -ShowGitStatus $config.prompt.showGitStatus `
                           -ShowExecutionTime $config.prompt.showExecutionTime `
                           -ShowCurrentDirectory $config.prompt.showCurrentDirectory `
                           -UseOhMyPosh $config.prompt.useOhMyPosh `
                           -OhMyPoshTheme $config.prompt.ohMyPoshTheme
        }
    }

    return $changes
}

Export-ModuleMember -Function Set-TerminalConfiguration 