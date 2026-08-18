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

# ── Apps Script scriptlets ─────────────────────────────────────────────────────
# The real pages are HtmlService TEMPLATES: doGet evaluates <?= ?> / <?!= ?> before
# serving. GitHub Pages serves the file verbatim, so anything left here reaches the
# browser as literal text.
#
# In markup that is merely ugly — the header read
#   "KPI Monitor <?!= tenantGet('hospital_name') ?> HA v.5"
# on the published demo for months, and the cockpit/military sidebar links pointed at
# a URL that never existed.
#
# Inside a <script> block it is fatal. The LIFF launcher work (10 ส.ค.69) added
#   var BOOT_TOKEN = <?!= JSON.stringify(bootToken || '') ... ?>;
# and an unevaluated scriptlet there is a JS syntax error, which kills the ENTIRE
# block — every function defined after it, i.e. the whole application. The page still
# paints its static shell, so it looks alive while nothing works.
#
# Order matters: the ScriptApp patterns include the '?view=' suffix so the whole href
# is replaced, not just the function call.
# Matched as regex, not literal text: the BOOT_* scriptlets contain a nested
# .replace(/</g, '\u003c') whose exact spelling is an upstream detail this build has no
# business depending on. Matching the assignment instead survives an edit to the inside.
$Scriptlets = @(
    # the two BOOT_* assignments: the demo has no LINE handshake to carry over
    @{ Pattern = 'var BOOT_TOKEN = <\?.*?\?>;'; Replace = "var BOOT_TOKEN = '';" },
    @{ Pattern = 'var BOOT_EMAIL = <\?.*?\?>;'; Replace = "var BOOT_EMAIL = '';" },
    # sidebar links -> the sibling demo pages
    @{ Pattern = '<\?= ScriptApp\.getService\(\)\.getUrl\(\) \?>\?view=cockpit';  Replace = 'demo-cockpit.html' },
    @{ Pattern = '<\?= ScriptApp\.getService\(\)\.getUrl\(\) \?>\?view=military'; Replace = 'demo-military.html' },
    # tenant name — deliberately a made-up hospital: this file is public on GitHub Pages
    @{ Pattern = "<\?!= tenantGet\('hospital_name'\) \?>"; Replace = 'โรงพยาบาลสาธิต' }
)

function Build($src, $mockP, $dst) {
    if (-not (Test-Path $src))   { throw "real app not found: $src" }
    if (-not (Test-Path $mockP)) { throw "mock not found: $mockP" }
    $html = [System.IO.File]::ReadAllText($src)
    $mock = [System.IO.File]::ReadAllText($mockP)
    if ($html.IndexOf('<body>') -lt 0) { throw "no <body> tag in $src" }
    $out = $html.Replace('<body>', "<body>`r`n$mock")

    $hit = 0
    foreach ($s in $Scriptlets) {
        $n = ([regex]::Matches($out, $s.Pattern)).Count
        if ($n -gt 0) {
            $out = [regex]::Replace($out, $s.Pattern, $s.Replace)
            $hit += $n
        }
    }

    # Fail loudly on any scriptlet this script has not been taught about. Without this
    # the next one added upstream ships a dead demo that looks fine in a diff, which is
    # exactly how the BOOT_TOKEN breakage went unnoticed.
    $left = [regex]::Matches($out, '<\?[^>]{0,200}?\?>')
    if ($left.Count -gt 0) {
        $sample = ($left | Select-Object -First 3 | ForEach-Object { $_.Value }) -join ' | '
        throw "$([System.IO.Path]::GetFileName($dst)): $($left.Count) unhandled Apps Script scriptlet(s) — add them to `$Scriptlets. First: $sample"
    }

    $enc = New-Object System.Text.UTF8Encoding($false)   # no BOM
    [System.IO.File]::WriteAllText($dst, $out, $enc)
    Write-Host ("  {0,-22} {1,4} KB   scriptlets substituted: {2}" -f (Split-Path $dst -Leaf), [math]::Round((Get-Item $dst).Length / 1KB), $hit)
}

Write-Host "Building demo pages..." -ForegroundColor Cyan
Build "$ws\WebAppHTML.html"        "$PSScriptRoot\_demo_mock.html"          "$PSScriptRoot\demo.html"
Build "$ws\CEOCockpit.html"        "$PSScriptRoot\_demo_mock_cockpit.html"  "$PSScriptRoot\demo-cockpit.html"
Build "$ws\MilitaryReadiness.html" "$PSScriptRoot\_demo_mock_military.html" "$PSScriptRoot\demo-military.html"
Write-Host "Done. verify in a browser, then: git add demo*.html; git commit; git push" -ForegroundColor Green
