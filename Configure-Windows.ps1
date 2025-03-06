#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [switch]$Force,
    [switch]$SkipFileLocations,
    [switch]$SkipTerminal,
    [switch]$SkipSoftware,
    [switch]$SkipExplorer,
    [switch]$SkipGitHub,
    [switch]$DryRun
)

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
$modulePath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulePath "FileLocations.psm1") -Force
Import-Module (Join-Path $modulePath "Terminal.psm1") -Force
Import-Module (Join-Path $modulePath "Software.psm1") -Force
Import-Module (Join-Path $modulePath "SystemSettings.psm1") -Force
Import-Module (Join-Path $modulePath "GitHub.psm1") -Force
Import-Module (Join-Path $modulePath "OnePassword.psm1") -Force

function Get-CurrentState {
    param (
        [string]$Section
    )

    $state = @{}
    
    switch ($Section) {
        "FileLocations" {
            $state = @{
                "Development Root Exists" = Test-Path $env:DEV_HOME
                "Projects Root Exists" = Test-Path $env:PROJECTS_HOME
                "Environment Variables Set" = ($env:DEV_HOME -ne $null -and $env:PROJECTS_HOME -ne $null)
            }
        }
        "Terminal" {
            $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            $state = @{
                "Windows Terminal Settings Exist" = Test-Path $wtSettingsPath
                "Oh My Posh Installed" = [bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue)
                "PowerShell Profile Exists" = Test-Path $PROFILE
            }
            if (Test-Path $wtSettingsPath) {
                $wtSettings = Get-Content -Path $wtSettingsPath -Raw | ConvertFrom-Json
                $state["Current Font"] = $wtSettings.profiles.defaults.font.face
                $state["Current Font Size"] = $wtSettings.profiles.defaults.font.size
            }
        }
        "Software" {
            $state = @{
                "Chocolatey Installed" = [bool](Get-Command choco -ErrorAction SilentlyContinue)
                "Winget Installed" = [bool](Get-Command winget -ErrorAction SilentlyContinue)
                "VS Code/Cursor Installed" = [bool]((Get-Command code -ErrorAction SilentlyContinue) -or (Get-Command cursor -ErrorAction SilentlyContinue))
            }
        }
        "Explorer" {
            $explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            $state = @{
                "Show File Extensions" = (Get-ItemProperty -Path $explorerKey).HideFileExt -eq 0
                "Show Hidden Files" = (Get-ItemProperty -Path $explorerKey).Hidden -eq 1
                "Show Protected OS Files" = (Get-ItemProperty -Path $explorerKey).ShowSuperHidden -eq 1
                "Expand to Current Folder" = (Get-ItemProperty -Path $explorerKey).NavPaneExpandToCurrentFolder -eq 1
                "Show All Folders" = (Get-ItemProperty -Path $explorerKey).NavPaneShowAllFolders -eq 1
            }
        }
        "GitHub" {
            $state = @{
                "Git Installed" = [bool](Get-Command git -ErrorAction SilentlyContinue)
                "GPG Installed" = [bool](Get-Command gpg -ErrorAction SilentlyContinue)
                "SSH Installed" = [bool](Get-Command ssh -ErrorAction SilentlyContinue)
                "GitHub CLI Installed" = [bool](Get-Command gh -ErrorAction SilentlyContinue)
                "1Password CLI Installed" = [bool](Get-Command op -ErrorAction SilentlyContinue)
                "SSH Agent Running" = [bool]((Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -eq 'Running')
            }
            if ($state["Git Installed"]) {
                $state["Git User Configured"] = [bool](git config --global user.name)
                $state["Git Email Configured"] = [bool](git config --global user.email)
                $state["Git Signing Configured"] = [bool](git config --global commit.gpgsign)
            }
        }
    }
    return $state
}

function Show-DryRunSummary {
    param (
        [string]$Section,
        [array]$Changes,
        [hashtable]$CurrentState = $null
    )

    Write-Host "`n$Section Changes:" -ForegroundColor Cyan
    Write-Host ("-" * ($Section.Length + 9))

    if ($CurrentState) {
        Write-Host "`nCurrent State:" -ForegroundColor Yellow
        foreach ($key in $CurrentState.Keys) {
            $value = $CurrentState[$key]
            $color = if ($value) { "Green" } else { "Red" }
            Write-Host "- $key : " -NoNewline
            Write-Host "$value" -ForegroundColor $color
        }
        Write-Host "`nProposed Changes:" -ForegroundColor Yellow
    }

    if ($Changes.Count -eq 0) {
        Write-Host "No changes required - current state matches desired state" -ForegroundColor Green
    }
    else {
        foreach ($change in $Changes) {
            Write-Host "- $change" -ForegroundColor White
        }
    }
}

function Get-ConfigurationSummary {
    $configPath = Join-Path $PSScriptRoot "config\settings.json"
    if (-not (Test-Path $configPath)) {
        Write-Host "`nError: Configuration file not found at: $configPath" -ForegroundColor Red
        Write-Host "Please ensure the configuration file exists before running the script." -ForegroundColor Yellow
        exit 1
    }

    $summary = @{
        "File Locations" = @()
        "Terminal Settings" = @()
        "Software Installation" = @()
        "Explorer Settings" = @()
        "GitHub Configuration" = @()
    }

    # File Locations
    if (-not $SkipFileLocations) {
        $summary["File Locations"] = Set-FileLocations -WhatIf
    }

    # Terminal Settings
    if (-not $SkipTerminal) {
        $summary["Terminal Settings"] = Set-TerminalConfiguration -WhatIf
    }

    # Software Installation
    if (-not $SkipSoftware) {
        $summary["Software Installation"] = Install-RequiredSoftware -WhatIf
    }

    # Explorer Settings
    if (-not $SkipExplorer) {
        $summary["Explorer Settings"] = Set-ExplorerSettings -WhatIf
    }

    # GitHub Configuration
    if (-not $SkipGitHub) {
        $summary["GitHub Configuration"] = Set-GitHubConfiguration -WhatIf
    }

    return $summary
}

function Show-Menu {
    Clear-Host
    Write-Host "Windows Configuration Tool" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host
    Write-Host "1. Configure File Locations"
    Write-Host "2. Configure Terminal Settings"
    Write-Host "3. Install Required Software"
    Write-Host "4. Configure Windows Explorer"
    Write-Host "5. Configure GitHub"
    Write-Host "6. Configure All"
    Write-Host "7. Show Dry Run Summary"
    Write-Host "Q. Quit"
    Write-Host
    Write-Host "Select an option: " -NoNewline
}

function Invoke-Configuration {
    param (
        [string]$Option
    )

    switch ($Option) {
        "1" {
            if (-not $SkipFileLocations) {
                Set-FileLocations -WhatIf:$DryRun
            }
        }
        "2" {
            if (-not $SkipTerminal) {
                Set-TerminalConfiguration -WhatIf:$DryRun
            }
        }
        "3" {
            if (-not $SkipSoftware) {
                Install-RequiredSoftware -WhatIf:$DryRun
            }
        }
        "4" {
            if (-not $SkipExplorer) {
                Set-ExplorerSettings -WhatIf:$DryRun
            }
        }
        "5" {
            if (-not $SkipGitHub) {
                Set-GitHubConfiguration -WhatIf:$DryRun
            }
        }
        "6" {
            if (-not $SkipFileLocations) {
                Set-FileLocations -WhatIf:$DryRun
            }
            if (-not $SkipTerminal) {
                Set-TerminalConfiguration -WhatIf:$DryRun
            }
            if (-not $SkipSoftware) {
                Install-RequiredSoftware -WhatIf:$DryRun
            }
            if (-not $SkipExplorer) {
                Set-ExplorerSettings -WhatIf:$DryRun
            }
            if (-not $SkipGitHub) {
                Set-GitHubConfiguration -WhatIf:$DryRun
            }
        }
        "7" {
            $summary = Get-ConfigurationSummary
            foreach ($section in $summary.Keys) {
                $sectionName = $section -replace " Configuration$", "" -replace " Settings$", "" -replace " Installation$", ""
                $currentState = Get-CurrentState -Section $sectionName
                Show-DryRunSummary -Section $section -Changes $summary[$section] -CurrentState $currentState
            }
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        default {
            Write-Host "Invalid option selected" -ForegroundColor Red
        }
    }
}

# Main script execution
if ($DryRun) {
    Write-Host "`nDRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host "=====================================" -ForegroundColor Yellow
    
    $summary = Get-ConfigurationSummary
    foreach ($section in $summary.Keys) {
        $sectionName = $section -replace " Configuration$", "" -replace " Settings$", "" -replace " Installation$", ""
        $currentState = Get-CurrentState -Section $sectionName
        Show-DryRunSummary -Section $section -Changes $summary[$section] -CurrentState $currentState
    }
    
    Write-Host "`nThis is a dry run. No changes were made." -ForegroundColor Yellow
    exit
}

if ($Force) {
    # Run all configurations without prompting
    Invoke-Configuration -Option "6"
}
else {
    do {
        Show-Menu
        $option = Read-Host
        if ($option -ne "Q") {
            Invoke-Configuration -Option $option
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($option -ne "Q")
}

Write-Host "`nConfiguration complete!" -ForegroundColor Green 