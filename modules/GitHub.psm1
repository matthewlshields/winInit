function Get-GitHubSettings {
    param (
        [string]$ConfigPath = "..\config\settings.json"
    )
    
    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config.github
    }
    catch {
        Write-Error "Failed to load GitHub configuration: $_"
        return $null
    }
}

function New-SSHKey {
    param (
        [Parameter(Mandatory=$true)]
        [string]$KeyType,
        [Parameter(Mandatory=$true)]
        [string]$KeyPath,
        [Parameter(Mandatory=$false)]
        [string]$OnePasswordItem
    )

    try {
        if ($OnePasswordItem) {
            # Use 1Password to get and configure SSH key
            $result = Import-1PasswordSSHKey -ItemName $OnePasswordItem -KeyPath $KeyPath
            if (-not $result) {
                throw "Failed to import SSH key from 1Password"
            }
        }
        else {
            $keyPath = [System.Environment]::ExpandEnvironmentVariables($KeyPath)
            $sshDir = Split-Path -Parent $keyPath

            # Create .ssh directory if it doesn't exist
            if (-not (Test-Path $sshDir)) {
                New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
                Write-Host "Created .ssh directory" -ForegroundColor Green
            }

            # Generate SSH key if it doesn't exist
            if (-not (Test-Path $keyPath)) {
                $email = Read-Host "Enter your GitHub email address"
                ssh-keygen -t $KeyType -f $keyPath -C $email -N '""'
                Write-Host "Generated new SSH key" -ForegroundColor Green

                # Start ssh-agent and add the key
                Start-Service ssh-agent
                ssh-add $keyPath
                Write-Host "Added SSH key to ssh-agent" -ForegroundColor Green

                # Display the public key
                $publicKey = Get-Content "$keyPath.pub"
                Write-Host "`nYour public SSH key (copy this to GitHub):`n" -ForegroundColor Yellow
                Write-Host $publicKey -ForegroundColor Cyan
                Write-Host "`nAdd this key to your GitHub account at: https://github.com/settings/keys" -ForegroundColor Yellow

                # Copy to clipboard
                Set-Clipboard -Value $publicKey
                Write-Host "Public key has been copied to clipboard" -ForegroundColor Green
            }
            else {
                Write-Host "SSH key already exists at $keyPath" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Error "Failed to generate/import SSH key: $_"
    }
}

function Set-GPGConfiguration {
    param (
        [Parameter(Mandatory=$false)]
        [string]$OnePasswordItem
    )

    try {
        # Check if GPG is installed
        if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
            Write-Error "GPG is not installed. Please install it first."
            return $false
        }

        if ($OnePasswordItem) {
            # Import GPG key from 1Password
            $result = Import-1PasswordGPGKey -ItemName $OnePasswordItem
            if (-not $result) {
                throw "Failed to import GPG key from 1Password"
            }
        }
        else {
            # List existing GPG keys
            $keys = gpg --list-secret-keys --keyid-format LONG
            if (-not $keys) {
                Write-Host "No GPG keys found. Please generate one using: gpg --full-generate-key" -ForegroundColor Yellow
                Write-Host "After generating the key, run this script again." -ForegroundColor Yellow
                return $false
            }

            # Get the first key ID
            $keyId = ($keys | Select-String -Pattern "sec.*?/(\w+)" | Select-Object -First 1).Matches.Groups[1].Value
            if (-not $keyId) {
                Write-Error "Could not find GPG key ID"
                return $false
            }

            # Configure Git to use this key
            git config --global user.signingkey $keyId
            Write-Host "Configured Git to use GPG key: $keyId" -ForegroundColor Green
        }

        # Configure GPG to work with Git
        $gpgPath = (Get-Command gpg).Source
        git config --global gpg.program $gpgPath

        # Enable commit and tag signing by default
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true

        # Add GPG instructions to Git commit template if not already present
        $templatePath = [System.IO.Path]::Combine($env:USERPROFILE, ".gitmessage")
        if (-not (Test-Path $templatePath)) {
            @"

# GPG Signing Information:
# This commit will be automatically signed with your GPG key.
# If the signing fails, make sure:
# 1. Your GPG key is properly configured
# 2. The GPG agent is running
# 3. You have the correct key selected
"@ | Set-Content $templatePath
            git config --global commit.template $templatePath
        }

        Write-Host "GPG signing has been configured successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to configure GPG: $_"
        return $false
    }
}

function Set-GitConfiguration {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$GitConfig,
        [Parameter(Mandatory=$false)]
        [string]$OnePasswordItem
    )

    try {
        # Configure global Git settings
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Error "Git is not installed"
            return
        }

        if ($OnePasswordItem) {
            # Get Git configuration from 1Password
            $onePasswordConfig = Get-1PasswordGitConfig -ItemName $OnePasswordItem
            if ($onePasswordConfig) {
                $GitConfig = $onePasswordConfig + $GitConfig
            }
        }

        # Get user info if not already configured and not using 1Password
        if (-not $OnePasswordItem) {
            $userName = git config --global user.name
            $userEmail = git config --global user.email

            if (-not $userName) {
                $userName = Read-Host "Enter your Git user name"
                git config --global user.name $userName
            }

            if (-not $userEmail) {
                $userEmail = Read-Host "Enter your Git email address"
                git config --global user.email $userEmail
            }
        }

        # Configure Git settings
        foreach ($key in $GitConfig.Keys) {
            git config --global $key $GitConfig[$key]
            Write-Host "Configured Git setting: $key = $($GitConfig[$key])" -ForegroundColor Green
        }

        # If commit signing is enabled, ensure GPG is properly configured
        if ($GitConfig["commit.gpgsign"] -eq "true") {
            Set-GPGConfiguration -OnePasswordItem $OnePasswordItem
        }
    }
    catch {
        Write-Error "Failed to configure Git: $_"
    }
}

function Initialize-GitHubCLI {
    try {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-Error "GitHub CLI is not installed"
            return
        }

        # Check if already authenticated
        $status = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Please authenticate with GitHub..." -ForegroundColor Yellow
            gh auth login --web --git-protocol ssh
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully authenticated with GitHub" -ForegroundColor Green
            }
            else {
                Write-Error "Failed to authenticate with GitHub"
            }
        }
        else {
            Write-Host "Already authenticated with GitHub" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to initialize GitHub CLI: $_"
    }
}

function Set-GitHubConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $config = Get-GitHubSettings
    if (-not $config) { return }

    Write-Host "`nConfiguring GitHub Settings" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan

    # Initialize 1Password if configured
    $use1Password = $false
    if ($config.use1Password) {
        $use1Password = Initialize-1Password
        if (-not $use1Password) {
            Write-Host "Falling back to manual configuration..." -ForegroundColor Yellow
        }
    }

    # Generate/Import SSH key
    if ($PSCmdlet.ShouldProcess("SSH key", "Generate/Import SSH key")) {
        $onePasswordItem = $use1Password ? $config.'1password'.sshKeyItem : $null
        New-SSHKey -KeyType $config.sshKeyType -KeyPath $config.sshKeyPath -OnePasswordItem $onePasswordItem
    }

    # Configure Git
    if ($config.configureGlobalGit -and $PSCmdlet.ShouldProcess("Git configuration", "Set global Git configuration")) {
        $onePasswordItem = $use1Password ? $config.'1password'.gitConfigItem : $null
        Set-GitConfiguration -GitConfig $config.gitConfig -OnePasswordItem $onePasswordItem
    }

    # Import GPG key if configured
    if ($use1Password -and $config.'1password'.gpgKeyItem -and $PSCmdlet.ShouldProcess("GPG key", "Import GPG key")) {
        Import-1PasswordGPGKey -ItemName $config.'1password'.gpgKeyItem
    }

    # Initialize GitHub CLI
    if ($PSCmdlet.ShouldProcess("GitHub CLI", "Initialize and authenticate GitHub CLI")) {
        Initialize-GitHubCLI
    }
}

Export-ModuleMember -Function Set-GitHubConfiguration 