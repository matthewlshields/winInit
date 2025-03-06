function Get-ConfiguredLocations {
    param (
        [string]$ConfigPath = "..\config\settings.json"
    )
    
    try {
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
    if (-not $config) { return }

    Write-Host "`nConfiguring File Locations" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan

    # Create main development directory
    if ($PSCmdlet.ShouldProcess($config.developmentRoot, "Create development root directory")) {
        New-Item -Path $config.developmentRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Development root directory: $($config.developmentRoot)" -ForegroundColor Green
    }

    # Create default folders
    if ($PSCmdlet.ShouldProcess("Default folders", "Create default folder structure")) {
        New-DefaultDirectories -BasePath $config.developmentRoot -Folders $config.defaultFolders
    }

    # Set environment variables
    if ($PSCmdlet.ShouldProcess("Environment variables", "Set development environment variables")) {
        [System.Environment]::SetEnvironmentVariable("DEV_HOME", $config.developmentRoot, [System.EnvironmentVariableTarget]::User)
        [System.Environment]::SetEnvironmentVariable("PROJECTS_HOME", $config.projectsRoot, [System.EnvironmentVariableTarget]::User)
        Write-Host "Environment variables set successfully" -ForegroundColor Green
    }
}

Export-ModuleMember -Function Set-FileLocations 