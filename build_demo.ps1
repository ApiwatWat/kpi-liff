# build_demo.ps1 — regenerate the demo pages from the REAL frontend HTML + their mock.
#
# Each demo = the real page with google.script.run replaced by a fake-data mock
# (inserted right after <body>, so window.google is defined BEFORE the app script).
# Rerun whenever the real app changes to keep the demos identical.
#
#   demo.html          = WebAppHTML.html        + _demo_mock.html          (KPI Monitor + Exec Summary)
#   demo-cockpit.html  = CEOCockpit.html        + _demo_mock_cockpit.html  (CEO Cockpit)
#   demo-military.html = MilitaryReadiness.html + _demo_mock_military.html (ความพร้อมกำลังพล)
#
# Usage:  powershell -File build_demo.ps1
# Deploy: git add demo*.html; git commit -m 'rebuild demo'; git push   (GitHub Pages)
$ErrorActionPreference = 'Stop'
$ws = "$env:USERPROFILE\OneDrive\HOSxP_Work\Project KPI monitor\clasp_workspace"

function Build($src, $mockP, $dst) {
    if (-not (Test-Path $src))   { throw "real app not found: $src" }
    if (-not (Test-Path $mockP)) { throw "mock not found: $mockP" }
    $html = [System.IO.File]::ReadAllText($src)
    $mock = [System.IO.File]::ReadAllText($mockP)
    if ($html.IndexOf('<body>') -lt 0) { throw "no <body> tag in $src" }
    $out = $html.Replace('<body>', "<body>`r`n$mock")
    $enc = New-Object System.Text.UTF8Encoding($false)   # no BOM
    [System.IO.File]::WriteAllText($dst, $out, $enc)
    Write-Host ("  {0,-22} {1} KB" -f (Split-Path $dst -Leaf), [math]::Round((Get-Item $dst).Length / 1KB))
}

Write-Host "Building demo pages..." -ForegroundColor Cyan
Build "$ws\WebAppHTML.html"        "$PSScriptRoot\_demo_mock.html"          "$PSScriptRoot\demo.html"
Build "$ws\CEOCockpit.html"        "$PSScriptRoot\_demo_mock_cockpit.html"  "$PSScriptRoot\demo-cockpit.html"
Build "$ws\MilitaryReadiness.html" "$PSScriptRoot\_demo_mock_military.html" "$PSScriptRoot\demo-military.html"
Write-Host "Done. next: git add demo*.html; git commit -m 'rebuild demo'; git push" -ForegroundColor Green
