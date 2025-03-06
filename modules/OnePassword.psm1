function Get-1PasswordSettings {
    param (
        [string]$ConfigPath = "..\config\settings.json"
    )
    
    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config.'1password'
    }
    catch {
        Write-Error "Failed to load 1Password configuration: $_"
        return $null
    }
}

function Initialize-1Password {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    try {
        # Check if 1Password CLI is installed
        if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
            Write-Error "1Password CLI is not installed. Please install it first."
            return $false
        }

        # Check if already signed in
        $signedIn = $false
        try {
            $null = op account list 2>$null
            $signedIn = $true
        }
        catch {
            $signedIn = $false
        }

        if (-not $signedIn) {
            $config = Get-1PasswordSettings
            if (-not $config) { return $false }

            if (-not $config.account) {
                $config.account = Read-Host "Enter your 1Password account address (e.g., my.1password.com)"
            }

            Write-Host "Please sign in to 1Password..." -ForegroundColor Yellow
            op signin --account $config.account

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to sign in to 1Password"
                return $false
            }
        }

        Write-Host "Successfully connected to 1Password" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to initialize 1Password: $_"
        return $false
    }
}

function Get-1PasswordSecret {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ItemName,
        [string]$Field = "password",
        [string]$Vault = $null
    )

    try {
        $config = Get-1PasswordSettings
        if (-not $config) { return $null }

        $vaultArg = ""
        if ($Vault) {
            $vaultArg = "--vault=$Vault"
        }
        elseif ($config.vault) {
            $vaultArg = "--vault=$($config.vault)"
        }

        $secret = op item get $ItemName $vaultArg --fields $Field
        return $secret
    }
    catch {
        Write-Error "Failed to get secret from 1Password: $_"
        return $null
    }
}

function Import-1PasswordSSHKey {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ItemName,
        [Parameter(Mandatory=$true)]
        [string]$KeyPath
    )

    try {
        $config = Get-1PasswordSettings
        if (-not $config) { return $false }

        $keyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
        $sshDir = Split-Path -Parent $keyPath

        # Create .ssh directory if it doesn't exist
        if (-not (Test-Path $sshDir)) {
            New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
            Write-Host "Created .ssh directory" -ForegroundColor Green
        }

        # Get private key from 1Password
        $privateKey = Get-1PasswordSecret -ItemName $ItemName -Field "private key"
        $publicKey = Get-1PasswordSecret -ItemName $ItemName -Field "public key"

        if (-not $privateKey -or -not $publicKey) {
            Write-Error "Failed to retrieve SSH key from 1Password"
            return $false
        }

        # Save keys to files
        Set-Content -Path $keyPath -Value $privateKey -NoNewline
        Set-Content -Path "$keyPath.pub" -Value $publicKey -NoNewline

        # Set correct permissions
        icacls $keyPath /inheritance:r
        icacls $keyPath /grant:r ${env:USERNAME}:"(F)"

        # Start ssh-agent and add the key
        Start-Service ssh-agent
        ssh-add $keyPath

        Write-Host "SSH key imported successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to import SSH key from 1Password: $_"
        return $false
    }
}

function Import-1PasswordGPGKey {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ItemName
    )

    try {
        # Check if GPG is installed
        if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
            Write-Error "GPG is not installed. Please install it first."
            return $false
        }

        # Get private key from 1Password
        $privateKey = Get-1PasswordSecret -ItemName $ItemName -Field "private key"
        if (-not $privateKey) {
            Write-Error "Failed to retrieve GPG key from 1Password"
            return $false
        }

        # Import the key
        $privateKey | gpg --import
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to import GPG key"
            return $false
        }

        Write-Host "GPG key imported successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to import GPG key from 1Password: $_"
        return $false
    }
}

function Get-1PasswordGitConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ItemName
    )

    try {
        $config = Get-1PasswordSettings
        if (-not $config) { return $null }

        # Get Git configuration from 1Password
        $gitConfig = @{}
        
        # Get user info
        $gitConfig["user.name"] = Get-1PasswordSecret -ItemName $ItemName -Field "git_username"
        $gitConfig["user.email"] = Get-1PasswordSecret -ItemName $ItemName -Field "git_email"

        # Get signing key if available
        $signingKey = Get-1PasswordSecret -ItemName $ItemName -Field "signing_key" -ErrorAction SilentlyContinue
        if ($signingKey) {
            $gitConfig["user.signingkey"] = $signingKey
            $gitConfig["commit.gpgsign"] = "true"
        }

        return $gitConfig
    }
    catch {
        Write-Error "Failed to get Git configuration from 1Password: $_"
        return $null
    }
}

Export-ModuleMember -Function Initialize-1Password, Import-1PasswordSSHKey, Import-1PasswordGPGKey, Get-1PasswordGitConfig 