function Get-SoftwareSettings {
    param (
        [string]$ConfigPath = "..\config\settings.json"
    )
    
    try {
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
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [Parameter(Mandatory=$true)]
        [string]$Source
    )

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
        Write-Error "Failed to install $Name: $_"
    }
}

function Install-VSCodeExtensions {
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
        Write-Host "Installing extension: $($extension.name)..." -ForegroundColor Yellow
        try {
            # Install for VS Code if present
            if ($vscodePath) {
                & code --install-extension $extension.id --force
                Write-Host "Installed $($extension.name) for VS Code" -ForegroundColor Green
            }

            # Install for Cursor if present (Cursor uses the same extension marketplace as VS Code)
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

    # Install package managers
    if ($PSCmdlet.ShouldProcess("Package managers", "Install package managers")) {
        Install-PackageManagers -PackageManagers $config.packageManagers
    }

    # Install applications
    foreach ($app in $config.applications) {
        if ($PSCmdlet.ShouldProcess($app.name, "Install application")) {
            Install-Application -Name $app.name -Id $app.id -Source $app.source
        }
    }

    # Install VS Code extensions
    if ($config.vscodeExtensions -and $PSCmdlet.ShouldProcess("VS Code extensions", "Install extensions")) {
        Install-VSCodeExtensions -Extensions $config.vscodeExtensions
    }
}

Export-ModuleMember -Function Install-RequiredSoftware 