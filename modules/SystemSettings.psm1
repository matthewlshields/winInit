function Set-ExplorerSettings {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    try {
        Write-Host "`nConfiguring Windows Explorer Settings" -ForegroundColor Cyan
        Write-Host "--------------------------------" -ForegroundColor Cyan

        # Show file extensions
        if ($PSCmdlet.ShouldProcess("Show file extensions", "Configure Explorer")) {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
            Write-Host "Enabled showing file extensions" -ForegroundColor Green
        }

        # Show hidden files
        if ($PSCmdlet.ShouldProcess("Show hidden files", "Configure Explorer")) {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
            Write-Host "Enabled showing hidden files" -ForegroundColor Green
        }

        # Show protected operating system files
        if ($PSCmdlet.ShouldProcess("Show protected OS files", "Configure Explorer")) {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1
            Write-Host "Enabled showing protected operating system files" -ForegroundColor Green
        }

        # Expand Explorer to current folder
        if ($PSCmdlet.ShouldProcess("Expand to current folder", "Configure Explorer")) {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "NavPaneExpandToCurrentFolder" -Value 1
            Write-Host "Enabled expanding Explorer to current folder" -ForegroundColor Green
        }

        # Show all folders in Explorer navigation pane
        if ($PSCmdlet.ShouldProcess("Show all folders", "Configure Explorer")) {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "NavPaneShowAllFolders" -Value 1
            Write-Host "Enabled showing all folders in navigation pane" -ForegroundColor Green
        }

        # Restart Explorer to apply changes
        if ($PSCmdlet.ShouldProcess("Restart Explorer", "Apply changes")) {
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            Start-Process "explorer" -ErrorAction SilentlyContinue
            Write-Host "Restarted Explorer to apply changes" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to configure Explorer settings: $_"
    }
}

Export-ModuleMember -Function Set-ExplorerSettings 