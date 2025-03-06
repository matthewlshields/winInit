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

function Show-DryRunSummary {
    param (
        [string]$Section,
        [array]$Changes
    )

    Write-Host "`n$Section Changes:" -ForegroundColor Cyan
    Write-Host ("-" * ($Section.Length + 9))
    if ($Changes.Count -eq 0) {
        Write-Host "No changes would be made" -ForegroundColor Yellow
    }
    else {
        foreach ($change in $Changes) {
            Write-Host "- $change" -ForegroundColor Green
        }
    }
}

function Get-ConfigurationSummary {
    $summary = @{
        "File Locations" = @()
        "Terminal Settings" = @()
        "Software Installation" = @()
        "Explorer Settings" = @()
        "GitHub Configuration" = @()
    }

    # File Locations
    if (-not $SkipFileLocations) {
        $config = Get-Content -Path "config\settings.json" -Raw | ConvertFrom-Json
        $summary["File Locations"] = @(
            "Create development root: $($config.fileLocations.developmentRoot)",
            "Create default folders: $($config.fileLocations.defaultFolders -join ', ')",
            "Set environment variables: DEV_HOME, PROJECTS_HOME"
        )
    }

    # Terminal Settings
    if (-not $SkipTerminal) {
        $config = Get-Content -Path "config\settings.json" -Raw | ConvertFrom-Json
        $summary["Terminal Settings"] = @(
            "Configure font: $($config.terminal.font.name) (size: $($config.terminal.font.size))",
            "Set color scheme",
            "Configure prompt with Git status and execution time",
            "Set up Oh My Posh with theme: $($config.terminal.prompt.ohMyPoshTheme)"
        )
    }

    # Software Installation
    if (-not $SkipSoftware) {
        $config = Get-Content -Path "config\settings.json" -Raw | ConvertFrom-Json
        $apps = $config.software.applications.name -join ', '
        $extensions = $config.software.vscodeExtensions.name -join ', '
        $summary["Software Installation"] = @(
            "Install applications: $apps",
            "Install VS Code extensions: $extensions"
        )
    }

    # Explorer Settings
    if (-not $SkipExplorer) {
        $summary["Explorer Settings"] = @(
            "Show file extensions",
            "Show hidden files",
            "Show protected OS files",
            "Configure navigation pane"
        )
    }

    # GitHub Configuration
    if (-not $SkipGitHub) {
        $config = Get-Content -Path "config\settings.json" -Raw | ConvertFrom-Json
        $summary["GitHub Configuration"] = @(
            "Configure Git with commit signing",
            "Set up SSH key",
            "Configure GitHub CLI"
        )
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
                Show-DryRunSummary -Section $section -Changes $summary[$section]
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
        Show-DryRunSummary -Section $section -Changes $summary[$section]
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