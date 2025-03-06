function Set-ExplorerSettings {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    try {
        Write-Host "`nConfiguring Windows Explorer Settings" -ForegroundColor Cyan
        Write-Host "--------------------------------" -ForegroundColor Cyan

        $changes = @()
        $explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $currentSettings = Get-ItemProperty -Path $explorerKey

        # Check file extensions setting
        if ($currentSettings.HideFileExt -ne 0) {
            $changes += "Show file extensions"
            if (-not $WhatIf -and $PSCmdlet.ShouldProcess("Show file extensions", "Configure Explorer")) {
                Set-ItemProperty -Path $explorerKey -Name "HideFileExt" -Value 0
            }
        }

        # Check hidden files setting
        if ($currentSettings.Hidden -ne 1) {
            $changes += "Show hidden files"
            if (-not $WhatIf -and $PSCmdlet.ShouldProcess("Show hidden files", "Configure Explorer")) {
                Set-ItemProperty -Path $explorerKey -Name "Hidden" -Value 1
            }
        }

        # Check protected OS files setting
        if ($currentSettings.ShowSuperHidden -ne 1) {
            $changes += "Show protected operating system files"
            if (-not $WhatIf -and $PSCmdlet.ShouldProcess("Show protected OS files", "Configure Explorer")) {
                Set-ItemProperty -Path $explorerKey -Name "ShowSuperHidden" -Value 1
            }
        }

        # Check expand to current folder setting
        if ($currentSettings.NavPaneExpandToCurrentFolder -ne 1) {
            $changes += "Enable expanding Explorer to current folder"
            if (-not $WhatIf -and $PSCmdlet.ShouldProcess("Expand to current folder", "Configure Explorer")) {
                Set-ItemProperty -Path $explorerKey -Name "NavPaneExpandToCurrentFolder" -Value 1
            }
        }

        # Check show all folders setting
        if ($currentSettings.NavPaneShowAllFolders -ne 1) {
            $changes += "Show all folders in navigation pane"
            if (-not $WhatIf -and $PSCmdlet.ShouldProcess("Show all folders", "Configure Explorer")) {
                Set-ItemProperty -Path $explorerKey -Name "NavPaneShowAllFolders" -Value 1
            }
        }

        # Only restart Explorer if changes were made
        if ($changes.Count -gt 0 -and -not $WhatIf -and $PSCmdlet.ShouldProcess("Restart Explorer", "Apply changes")) {
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            Start-Process "explorer" -ErrorAction SilentlyContinue
        }

        return $changes
    }
    catch {
        Write-Error "Failed to configure Explorer settings: $_"
        return @("Failed to configure Explorer settings: $_")
    }
}

Export-ModuleMember -Function Set-ExplorerSettings 