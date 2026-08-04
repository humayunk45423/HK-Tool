$ErrorActionPreference = 'Stop'
try {
    $content = Get-Content -Path 'f:\Me & My Docs\1. Recent Projects\HK-Tool\HumayounTool_v1.ps1' -Raw
    if ($content -match '(?s)\[xml\]$xaml = @''\r?\n(.*?)\r?\n''@') {
        $xmlContent = $Matches[1]
        Add-Type -AssemblyName PresentationFramework
        $reader = [System.Xml.XmlNodeReader]::new([xml]$xmlContent)
        $win = [Windows.Markup.XamlReader]::Load($reader)
        # Attempt to measure layout or show to trigger template expansion
        $win.Measure([System.Windows.Size]::new(800, 600))
        Write-Host 'XAML IS PERFECT'
    } else {
        Write-Host 'Regex did not match'
    }
} catch {
    Write-Host 'XAML ERROR: ' $_.Exception.Message
    if ($_.Exception.InnerException) {
        Write-Host 'INNER: ' $_.Exception.InnerException.Message
    }
}
