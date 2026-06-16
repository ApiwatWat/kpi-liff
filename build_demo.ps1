# build_demo.ps1 — regenerate demo.html from the REAL WebAppHTML.html + _demo_mock.html
#
# Why: demo.html IS the real KPI Monitor frontend with google.script.run replaced
# by a fake-data mock (see _demo_mock.html) + auto-login. When the real app
# (WebAppHTML.html) changes, rerun this to keep the demo looking identical.
#
# Usage:  powershell -File build_demo.ps1
# Output: demo.html (UTF-8 no BOM) — deploy by: git add demo.html; git commit; git push
$ErrorActionPreference = 'Stop'
$src   = "$env:USERPROFILE\OneDrive\HOSxP_Work\Project KPI monitor\clasp_workspace\WebAppHTML.html"
$mockP = "$PSScriptRoot\_demo_mock.html"
$dst   = "$PSScriptRoot\demo.html"

if (-not (Test-Path $src))   { throw "real app not found: $src (run on a machine with the clasp_workspace)" }
if (-not (Test-Path $mockP)) { throw "mock not found: $mockP" }

$html = [System.IO.File]::ReadAllText($src)
$mock = [System.IO.File]::ReadAllText($mockP)
if ($html.IndexOf('<body>') -lt 0) { throw "no <body> tag in real app HTML" }

# literal insert right after <body> (mock defines window.google BEFORE the app script runs)
$out = $html.Replace('<body>', "<body>`r`n$mock")
$enc = New-Object System.Text.UTF8Encoding($false)   # no BOM
[System.IO.File]::WriteAllText($dst, $out, $enc)

Write-Host ("demo.html rebuilt: {0} KB" -f [math]::Round((Get-Item $dst).Length/1KB))
Write-Host "next: git add demo.html; git commit -m 'rebuild demo'; git push"
