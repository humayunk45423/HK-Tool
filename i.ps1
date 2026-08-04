# Humayoun Tool -- installer stub
# Served at: hktool.vercel.app/i
# Run with:  irm hktool.vercel.app/i | iex

$ErrorActionPreference = 'Stop'

# Self-elevate if not admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $enc = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes("irm https://hktool.vercel.app/i | iex"))
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc" -Verb RunAs
    exit
}

# Download latest script from GitHub and run it
$url = 'https://raw.githubusercontent.com/humayunk45423/HK-Tool/main/HumayounTool_v1.ps1'
$tmp = "$env:TEMP\HumayounTool_run.ps1"
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
