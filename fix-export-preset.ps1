param(
    [string]$PresetPath = "./export_presets.cfg",
    [string]$IncludeFilter = "*.txt,*.csv,*.json",
    [string]$ExportFilter = "all_resources"
)

if (-not (Test-Path -LiteralPath $PresetPath)) {
    Write-Error "Preset file not found: $PresetPath"
    exit 1
}

$content = Get-Content -LiteralPath $PresetPath -Raw
$original = $content

$content = [regex]::Replace($content, 'export_filter="[^"]*"', ('export_filter="{0}"' -f $ExportFilter), 1)
$content = [regex]::Replace($content, 'include_filter="[^"]*"', ('include_filter="{0}"' -f $IncludeFilter), 1)

if ($content -ne $original) {
    Set-Content -LiteralPath $PresetPath -Value $content -NoNewline
    Write-Host "Updated $PresetPath"
} else {
    Write-Host "No changes needed in $PresetPath"
}

Write-Host "Current settings:"
Select-String -Path $PresetPath -Pattern '^export_filter=|^include_filter=' | ForEach-Object { $_.Line }
