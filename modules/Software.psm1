function Get-SoftwareSettings {
    param (
        [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings.json")
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at: $ConfigPath"
        }
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config.software
    }
    catch {
        Write-Error "Failed to load software configuration: $_"
        return $null
    }
}

function Install-PackageManagers {
    param (
        [string[]]$PackageManagers
    )

    foreach ($pm in $PackageManagers) {
        switch ($pm.ToLower()) {
            "chocolatey" {
                if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
                    try {
                        Set-ExecutionPolicy Bypass -Scope Process -Force
                        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                        Write-Host "Chocolatey installed successfully" -ForegroundColor Green
                    }
                    catch {
                        Write-Error "Failed to install Chocolatey: $_"
                    }
                }
                else {
                    Write-Host "Chocolatey is already installed" -ForegroundColor Green
                }
            }
            "winget" {
                if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                    Write-Host "Winget should be installed via the Microsoft Store" -ForegroundColor Yellow
                    Write-Host "Please install the 'App Installer' from the Microsoft Store" -ForegroundColor Yellow
                }
                else {
                    Write-Host "Winget is already installed" -ForegroundColor Green
                }
            }
        }
    }
}

function Install-Application {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [Parameter(Mandatory=$true)]
        [string]$Source
    )

    if (-not $PSCmdlet.ShouldProcess($Name, "Install application")) {
        return "Would install $Name via $Source"
    }

    Write-Host "Installing $Name..." -ForegroundColor Yellow
    try {
        switch ($Source.ToLower()) {
            "winget" {
                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    winget install --id $Id --accept-source-agreements --accept-package-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "$Name installed successfully" -ForegroundColor Green
                    }
                    else {
                        Write-Error "Failed to install $Name"
                    }
                }
                else {
                    Write-Error "Winget is not installed"
                }
            }
            "chocolatey" {
                if (Get-Command choco -ErrorAction SilentlyContinue) {
                    choco install $Id -y
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "$Name installed successfully" -ForegroundColor Green
                    }
                    else {
                        Write-Error "Failed to install $Name"
                    }
                }
                else {
                    Write-Error "Chocolatey is not installed"
                }
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to install $Name. Error: $errorMessage"
    }
}

function Install-VSCodeExtensions {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [array]$Extensions
    )

    Write-Host "`nInstalling VS Code Extensions" -ForegroundColor Cyan
    Write-Host "-------------------------" -ForegroundColor Cyan

    # Check if VS Code or Cursor is installed
    $vscodePath = Get-Command "code" -ErrorAction SilentlyContinue
    $cursorPath = Get-Command "cursor" -ErrorAction SilentlyContinue

    if (-not ($vscodePath -or $cursorPath)) {
        Write-Error "Neither VS Code nor Cursor IDE is installed. Please install one of them first."
        return
    }

    foreach ($extension in $Extensions) {
        if (-not $PSCmdlet.ShouldProcess($extension.name, "Install VS Code extension")) {
            if ($vscodePath) {
                Write-Output "Would install $($extension.name) for VS Code"
            }
            if ($cursorPath) {
                Write-Output "Would install $($extension.name) for Cursor"
            }
            continue
        }

        Write-Host "Installing extension: $($extension.name)..." -ForegroundColor Yellow
        try {
            # Install for VS Code if present
            if ($vscodePath) {
                & code --install-extension $extension.id --force
                Write-Host "Installed $($extension.name) for VS Code" -ForegroundColor Green
            }

            # Install for Cursor if present
            if ($cursorPath) {
                & cursor --install-extension $extension.id --force
                Write-Host "Installed $($extension.name) for Cursor" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to install extension $($extension.name): $_"
        }
    }
}

function Install-RequiredSoftware {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $config = Get-SoftwareSettings
    if (-not $config) { return }

    Write-Host "`nInstalling Required Software" -ForegroundColor Cyan
    Write-Host "-------------------------" -ForegroundColor Cyan

    $changes = @()

    # Check package managers
    foreach ($pm in $config.packageManagers) {
        switch ($pm.ToLower()) {
            "chocolatey" {
                if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                    if ($PSCmdlet.ShouldProcess("Chocolatey", "Install package manager")) {
                        $changes += "Install Chocolatey package manager"
                    }
                }
            }
            "winget" {
                if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                    $changes += "Install Winget package manager (via Microsoft Store - App Installer)"
                }
            }
        }
    }

    # Check applications
    foreach ($app in $config.applications) {
        $installed = $false
        switch ($app.source.ToLower()) {
            "winget" {
                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    $result = winget list --id $app.id 2>&1
                    $installed = $result -match $app.id
                }
            }
            "chocolatey" {
                if (Get-Command choco -ErrorAction SilentlyContinue) {
                    $result = choco list --local-only --exact $app.id
                    $installed = $result -match $app.id
                }
            }
        }

        if (-not $installed) {
            $changes += "Install $($app.name) via $($app.source)"
            if ($PSCmdlet.ShouldProcess($app.name, "Install application")) {
                Install-Application -Name $app.name -Id $app.id -Source $app.source
            }
        }
    }

    # Check VS Code extensions
    if ($config.vscodeExtensions) {
        $vscodePath = Get-Command "code" -ErrorAction SilentlyContinue
        $cursorPath = Get-Command "cursor" -ErrorAction SilentlyContinue

        if ($vscodePath -or $cursorPath) {
            foreach ($extension in $config.vscodeExtensions) {
                $installed = $false
                
                if ($vscodePath) {
                    $result = code --list-extensions 2>$null
                    $installed = $installed -or ($result -contains $extension.id)
                }
                
                if ($cursorPath) {
                    $result = cursor --list-extensions 2>$null
                    $installed = $installed -or ($result -contains $extension.id)
                }

                if (-not $installed) {
                    $changes += "Install VS Code/Cursor extension: $($extension.name)"
                    if ($PSCmdlet.ShouldProcess($extension.name, "Install VS Code extension")) {
                        Install-VSCodeExtensions -Extensions @($extension)
                    }
                }
            }
        }
        else {
            $changes += "Install VS Code or Cursor IDE"
        }
    }

    return $changes
}

Export-ModuleMember -Function Install-RequiredSoftware 