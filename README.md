# Windows Configuration Script

This PowerShell-based configuration tool helps you set up your Windows environment with an interactive interface. It includes:

- Default file location configuration
- Terminal customization (prompt and font settings)
- Standard software installation
- Windows Explorer configuration
- GitHub and Git setup with commit signing
- 1Password integration for secure secret management

## Requirements

- Windows 10 or later
- PowerShell 5.1 or later
- Administrator privileges
- 1Password account (optional, for secure secret management)
- EditorConfig extension for your IDE (recommended)

## Development Standards

This project uses EditorConfig to maintain consistent coding styles. The configuration includes:

### General Standards
- UTF-8 encoding
- Windows-style line endings (CRLF) for Windows files
- Unix-style line endings (LF) for shell scripts
- Final newline at end of file
- Trim trailing whitespace

### Language-Specific Standards
- PowerShell (*.ps1, *.psm1, *.psd1):
  - 4 spaces indentation
  - 120 characters line length

- JSON/Config files:
  - 4 spaces indentation for JSON
  - 2 spaces indentation for other config files

- Markdown:
  - 2 spaces indentation
  - Preserve trailing whitespace

For full details, see the `.editorconfig` file in the root directory.

### Source Control

The project includes a comprehensive `.gitignore` file that excludes:

- Operating System files
  - Windows system files (Thumbs.db, Desktop.ini)
  - macOS files (.DS_Store)
  - Linux temporary files

- Development files
  - PowerShell logs and temporary files
  - Visual Studio Code workspace files
  - Node.js dependencies
  - Build outputs and temporary files

- Security and Secrets
  - Certificates and keys
  - 1Password local files
  - Environment files (.env)

- IDE and Editor files
  - Visual Studio files
  - JetBrains IDE files
  - Sublime Text files

For the complete list of ignored files, see the `.gitignore` file in the root directory.

## Usage

### Basic Usage

1. Open PowerShell as Administrator
2. Navigate to the project directory
3. Run `.\Configure-Windows.ps1`

### Command Line Options

```powershell
.\Configure-Windows.ps1 [-Force] [-SkipFileLocations] [-SkipTerminal] [-SkipSoftware] [-SkipExplorer] [-SkipGitHub] [-DryRun]
```

- `-Force`: Run all configurations without prompting
- `-SkipFileLocations`: Skip file location configuration
- `-SkipTerminal`: Skip terminal configuration
- `-SkipSoftware`: Skip software installation
- `-SkipExplorer`: Skip Explorer settings
- `-SkipGitHub`: Skip GitHub configuration
- `-DryRun`: Show what would be changed without making actual changes

### Interactive Menu Options

1. Configure File Locations
2. Configure Terminal Settings
3. Install Required Software
4. Configure Windows Explorer
5. Configure GitHub
6. Configure All
7. Show Dry Run Summary
Q. Quit

## Features

### File Location Management
- Configure common file locations
- Set up development directories
- Create standard folder structure
- Set environment variables

### Terminal Customization
- Configure PowerShell prompt
- Set up terminal fonts
- Customize color schemes
- Configure Oh My Posh with Git status

### Software Installation
- Install common development tools
- Set up package managers
- Configure development environments
- Install VS Code extensions

### Windows Explorer Configuration
- Show file extensions
- Show hidden files
- Show protected OS files
- Configure navigation pane

### GitHub and Git Setup
- Configure Git with commit signing
- Set up SSH keys
- Configure GitHub CLI
- Set up GPG for commit verification

### 1Password Integration
- Secure storage of SSH keys
- GPG key management
- Git configuration storage
- Environment variable management

## Configuration

Edit `config/settings.json` to customize default settings before running the script. The configuration includes:

```json
{
    "fileLocations": {
        "developmentRoot": "C:\\Development",
        "documentsRoot": "%USERPROFILE%\\Documents",
        "projectsRoot": "C:\\Development\\Projects",
        "githubRoot": "C:\\Development\\github.com",
        "defaultFolders": ["Projects", "GitHub", "Workspace", "Tools"]
    },
    "terminal": {
        "font": {
            "name": "CascadiaCode NF",
            "size": 12
        },
        "colorScheme": {
            "background": "#0C0C0C",
            "foreground": "#CCCCCC",
            "cursor": "#FFFFFF"
        },
        "prompt": {
            "showGitStatus": true,
            "showExecutionTime": true,
            "showCurrentDirectory": true,
            "useOhMyPosh": true,
            "ohMyPoshTheme": "agnoster"
        }
    },
    "software": {
        "packageManagers": ["winget", "chocolatey"],
        "applications": [...],
        "vscodeExtensions": [...]
    },
    "github": {
        "sshKeyType": "ed25519",
        "sshKeyPath": "%USERPROFILE%\\.ssh\\id_ed25519",
        "configureGlobalGit": true,
        "gitConfig": {
            "core.autocrlf": "true",
            "init.defaultBranch": "main",
            "commit.gpgsign": "true",
            "gpg.program": "gpg",
            "tag.gpgsign": "true"
        },
        "use1Password": true,
        "1password": {
            "sshKeyItem": "GitHub SSH Key",
            "gpgKeyItem": "GitHub GPG Key",
            "gitConfigItem": "GitHub Configuration"
        }
    },
    "1password": {
        "account": "",
        "service_account_token_item": "Windows Config Service Account",
        "vault": "Developer",
        "categories": {
            "ssh_keys": "SSH Keys",
            "gpg_keys": "GPG Keys",
            "git_config": "Developer Config",
            "environment": "Environment Variables"
        }
    }
}
```

## Dry Run Mode

Use the `-DryRun` parameter to preview all changes that would be made:

```powershell
.\Configure-Windows.ps1 -DryRun
```

This will show:
- All files and directories that would be created
- All software that would be installed
- All system settings that would be changed
- All Git and GitHub configurations
- All environment variables that would be set

## Structure

```
.
├── Configure-Windows.ps1     # Main script
├── config/
│   └── settings.json        # Configuration settings
├── modules/
│   ├── FileLocations.psm1   # File location management
│   ├── Terminal.psm1        # Terminal customization
│   ├── Software.psm1        # Software installation
│   ├── SystemSettings.psm1  # Windows system settings
│   ├── GitHub.psm1          # GitHub and Git configuration
│   └── OnePassword.psm1     # 1Password integration
└── README.md                # This file
```

## Security

- All sensitive information is stored in 1Password
- SSH and GPG keys are managed securely
- Git commit signing is configured by default
- Proper file permissions are set for sensitive files

## Contributing

Feel free to submit issues and enhancement requests!
