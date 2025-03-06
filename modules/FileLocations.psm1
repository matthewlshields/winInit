function Get-ConfiguredLocations {
    param (
        [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings.json")
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at: $ConfigPath"
        }
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config.fileLocations
    }
    catch {
        Write-Error "Failed to load file locations configuration: $_"
        return $null
    }
}

function New-DefaultDirectories {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [string[]]$Folders
    )

    foreach ($folder in $Folders) {
        $path = Join-Path -Path $BasePath -ChildPath $folder
        if (-not (Test-Path -Path $path)) {
            try {
                New-Item -Path $path -ItemType Directory -Force
                Write-Host "Created directory: $path" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to create directory '$path': $_"
            }
        }
        else {
            Write-Host "Directory already exists: $path" -ForegroundColor Yellow
        }
    }
}

function Set-FileLocations {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $config = Get-ConfiguredLocations
    if (-not $config) { 
        Write-Error "No file locations configuration found"
        return 
    }

    Write-Host "`nConfiguring File Locations" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan

    $changes = @()

    # Required paths to check
    $requiredPaths = @{
        "developmentRoot" = $config.developmentRoot
        "projectsRoot" = $config.projectsRoot
        "githubRoot" = $config.githubRoot
    }

    # Check each required path
    foreach ($pathKey in $requiredPaths.Keys) {
        $pathValue = $requiredPaths[$pathKey]
        if (-not $pathValue) {
            Write-Error "Required path '$pathKey' is not configured"
            continue
        }

        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($pathValue)
        if (-not (Test-Path $expandedPath)) {
            $changes += "Create $pathKey directory: $expandedPath"
            if ($PSCmdlet.ShouldProcess($expandedPath, "Create directory")) {
                New-Item -Path $expandedPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    # Check default folders if configured
    if ($config.defaultFolders) {
        $devRoot = [System.Environment]::ExpandEnvironmentVariables($config.developmentRoot)
        foreach ($folder in $config.defaultFolders) {
            $path = Join-Path -Path $devRoot -ChildPath $folder
            if (-not (Test-Path -Path $path)) {
                $changes += "Create directory: $path"
                if ($PSCmdlet.ShouldProcess($path, "Create directory")) {
                    New-Item -Path $path -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    }

    # Check additional paths if configured
    $additionalPaths = @(
        @{ Key = "documents"; EnvVar = "documentsRoot" },
        @{ Key = "downloads"; EnvVar = $null },
        @{ Key = "pictures"; EnvVar = $null },
        @{ Key = "desktop"; EnvVar = $null }
    )

    foreach ($pathInfo in $additionalPaths) {
        $pathValue = $config.($pathInfo.Key)
        if ($pathValue) {
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($pathValue)
            if (-not (Test-Path $expandedPath)) {
                $changes += "Create $($pathInfo.Key) directory: $expandedPath"
                if ($PSCmdlet.ShouldProcess($expandedPath, "Create directory")) {
                    New-Item -Path $expandedPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    }

    # Set environment variables
    $envVars = @{
        "DEV_HOME" = $config.developmentRoot
        "PROJECTS_HOME" = $config.projectsRoot
    }

    foreach ($envVar in $envVars.GetEnumerator()) {
        $currentValue = [System.Environment]::GetEnvironmentVariable($envVar.Key, [System.EnvironmentVariableTarget]::User)
        $newValue = [System.Environment]::ExpandEnvironmentVariables($envVar.Value)
        
        if ($currentValue -ne $newValue) {
            $changes += "Set $($envVar.Key) environment variable to: $newValue"
            if ($PSCmdlet.ShouldProcess($envVar.Key, "Set environment variable")) {
                [System.Environment]::SetEnvironmentVariable($envVar.Key, $newValue, [System.EnvironmentVariableTarget]::User)
            }
        }
    }

    return $changes
}

Export-ModuleMember -Function Set-FileLocations 