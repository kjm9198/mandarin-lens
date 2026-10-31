# Create Desktop Shortcut for Kamihi Lens on Windows
$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "Kamihi Lens.lnk"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetPath = Join-Path $ScriptDir "KamihiLens.bat"
$IconPath = Join-Path $ScriptDir "app\icon.png"

$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetPath
$Shortcut.WorkingDirectory = $ScriptDir
$Shortcut.Description = "Kamihi Lens Chinese Study Workspace"
$Shortcut.Save()

Write-Host "Kamihi Lens shortcut created on Desktop successfully!" -ForegroundColor Green
