function Get-GitHubSettings {
    param (
        [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings.json")
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found at: $ConfigPath"
        }
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config.github
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to load GitHub configuration: $errorMessage"
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
                $result = ssh-keygen -t $KeyType -f $keyPath -C $email -N '""'
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to generate SSH key. Exit code: $LASTEXITCODE"
                }
                Write-Host "Generated new SSH key" -ForegroundColor Green

                # Start ssh-agent and add the key
                $agentService = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
                if ($agentService) {
                    Start-Service ssh-agent
                    $result = ssh-add $keyPath
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to add key to ssh-agent. Exit code: $LASTEXITCODE"
                    }
                    else {
                        Write-Host "Added SSH key to ssh-agent" -ForegroundColor Green
                    }
                }
                else {
                    Write-Warning "ssh-agent service not found. Key will need to be added manually."
                }

                # Display the public key
                if (Test-Path "$keyPath.pub") {
                    $publicKey = Get-Content "$keyPath.pub"
                    Write-Host "`nYour public SSH key (copy this to GitHub):`n" -ForegroundColor Yellow
                    Write-Host $publicKey -ForegroundColor Cyan
                    Write-Host "`nAdd this key to your GitHub account at: https://github.com/settings/keys" -ForegroundColor Yellow

                    # Copy to clipboard
                    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                        Set-Clipboard -Value $publicKey
                        Write-Host "Public key has been copied to clipboard" -ForegroundColor Green
                    }
                }
                else {
                    Write-Warning "Public key file not found at: $keyPath.pub"
                }
            }
            else {
                Write-Host "SSH key already exists at $keyPath" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to generate/import SSH key: $errorMessage"
    }
}

function Set-GPGConfiguration {
    param (
        [Parameter(Mandatory=$false)]
        [string]$OnePasswordItem
    )

    try {
        # Check if GPG is installed
        $gpg = Get-Command gpg -ErrorAction Stop
        
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
            $keyMatch = $keys | Select-String -Pattern "sec.*?/(\w+)" | Select-Object -First 1
            if (-not $keyMatch -or -not $keyMatch.Matches -or -not $keyMatch.Matches[0].Groups[1].Value) {
                throw "Could not find GPG key ID"
            }
            $keyId = $keyMatch.Matches[0].Groups[1].Value

            # Configure Git to use this key
            git config --global user.signingkey $keyId
            Write-Host "Configured Git to use GPG key: $keyId" -ForegroundColor Green
        }

        # Configure GPG to work with Git
        git config --global gpg.program $gpg.Source

        # Enable commit and tag signing by default
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true

        # Add GPG instructions to Git commit template
        $templatePath = Join-Path $env:USERPROFILE ".gitmessage"
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
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to configure GPG: $errorMessage"
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

function Test-Dependencies {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    $dependencies = @{
        "Git" = @{
            Required = $true
            Command = "git"
            InstallCommand = "winget install Git.Git"
        }
        "GPG" = @{
            Required = $Config.gitConfig."commit.gpgsign" -eq "true"
            Command = "gpg"
            InstallCommand = "winget install GnuPG.GnuPG"
        }
        "SSH" = @{
            Required = $true
            Command = "ssh"
            InstallCommand = "Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
        }
        "GitHub CLI" = @{
            Required = $false
            Command = "gh"
            InstallCommand = "winget install GitHub.cli"
        }
        "1Password CLI" = @{
            Required = $Config.use1Password
            Command = "op"
            InstallCommand = "winget install AgileBits.1Password.CLI"
        }
    }

    $missingDeps = @()
    foreach ($dep in $dependencies.Keys) {
        $info = $dependencies[$dep]
        if (-not (Get-Command $info.Command -ErrorAction SilentlyContinue)) {
            if ($info.Required) {
                $missingDeps += @{
                    Name = $dep
                    InstallCommand = $info.InstallCommand
                }
            } else {
                Write-Host "Optional dependency $dep is not installed." -ForegroundColor Yellow
                Write-Host "To install, run: $($info.InstallCommand)" -ForegroundColor Yellow
                Write-Host
            }
        }
    }

    if ($missingDeps.Count -gt 0) {
        Write-Host "`nMissing required dependencies:" -ForegroundColor Red
        foreach ($dep in $missingDeps) {
            Write-Host "- $($dep.Name)" -ForegroundColor Red
            Write-Host "  To install, run: $($dep.InstallCommand)" -ForegroundColor Yellow
        }
        Write-Host "`nPlease install the required dependencies and run the script again." -ForegroundColor Red
        return $false
    }

    # Check SSH agent service
    $sshAgent = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    if (-not $sshAgent) {
        Write-Host "SSH agent service is not installed." -ForegroundColor Yellow
        Write-Host "To install, run: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0" -ForegroundColor Yellow
        return $false
    }
    if ($sshAgent.Status -ne "Running") {
        Write-Host "Starting SSH agent service..." -ForegroundColor Yellow
        Start-Service ssh-agent
    }

    return $true
}

function Set-GitHubConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $config = Get-GitHubSettings
    if (-not $config) { return }

    Write-Host "`nConfiguring GitHub" -ForegroundColor Cyan
    Write-Host "----------------" -ForegroundColor Cyan

    $changes = @()

    # Check if 1Password CLI is installed
    if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
        Write-Host "1Password CLI is not installed. Please install it using: winget install AgileBits.1Password.CLI" -ForegroundColor Yellow
        return $changes
    }

    # Check if Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Please install it first." -ForegroundColor Red
        return $changes
    }

    # Configure SSH key signing
    if ($config.useSSHSigning) {
        # Verify op-ssh-sign.exe exists
        $sshSigningProgram = [System.Environment]::ExpandEnvironmentVariables($config.sshSigningProgram)
        if (-not (Test-Path $sshSigningProgram)) {
            Write-Error "SSH signing program not found at: $sshSigningProgram"
            Write-Host "Please ensure 1Password is installed and the path is correct." -ForegroundColor Yellow
            return $changes
        }

        # Configure Git with SSH signing
        foreach ($setting in $config.gitConfig.PSObject.Properties) {
            $currentValue = git config --global $setting.Name
            $newValue = [System.Environment]::ExpandEnvironmentVariables($setting.Value)
            
            if ($currentValue -ne $newValue) {
                $changes += "Set Git config: $($setting.Name) = $newValue"
                if ($PSCmdlet.ShouldProcess("Git config $($setting.Name)", "Set value")) {
                    git config --global $setting.Name $newValue
                }
            }
        }
    }

    # Configure GitHub CLI if requested
    if ($config.useGitHubCLI) {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            $changes += "Install GitHub CLI"
            if ($PSCmdlet.ShouldProcess("GitHub CLI", "Install")) {
                winget install GitHub.cli
            }
        }
        else {
            # Check if already authenticated
            $authenticated = $false
            try {
                $null = gh auth status 2>&1
                $authenticated = $LASTEXITCODE -eq 0
            }
            catch {
                $authenticated = $false
            }

            if (-not $authenticated) {
                $changes += "Authenticate with GitHub CLI"
                if ($PSCmdlet.ShouldProcess("GitHub CLI", "Authenticate")) {
                    gh auth login
                }
            }
        }
    }

    return $changes
}

Export-ModuleMember -Function Set-GitHubConfiguration 
Export-ModuleMember -Function Set-GitHubConfiguration 