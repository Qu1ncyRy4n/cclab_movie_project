# create_desktop_shortcut.ps1
#
# Creates a Desktop shortcut pointing at this experiment folder, so it's
# easy to find without navigating the repo each time. Safe to re-run —
# it just overwrites the one shortcut it made.
#
# Usage (from PowerShell, in this folder):
#   .\create_desktop_shortcut.ps1
#
# This addresses the same open TODO as the main README's "Windows shortcut
# to repo" item, scoped to exp_00 specifically since that's what's being
# tested first — the same script pattern works for the repo root too, just
# point $targetPath at it instead.

$targetPath = $PSScriptRoot
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "exp00_pilot_interleave.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $targetPath
$Shortcut.WorkingDirectory = $targetPath
$Shortcut.Description = "cclab_movie_project - exp_00 pilot (interleave, simplified)"
$Shortcut.Save()

Write-Host "Shortcut created:"
Write-Host "  $shortcutPath"
Write-Host "  -> $targetPath"
