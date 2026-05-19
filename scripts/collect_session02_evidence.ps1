$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path evidence\buoi-02\mock-screenshots | Out-Null

Write-Host "[Lab02] Collecting tool versions..."
$versions = @()
$versions += "# Tool versions"
$versions += ""
$versions += "## Node"
$versions += (node --version 2>$null)
$versions += ""
$versions += "## npm"
$versions += (npm --version 2>$null)
$versions += ""
$versions += "## Spectral"
$versions += (npx spectral --version 2>$null)
$versions += ""
$versions += "## Prism"
$versions += (npx prism --version 2>$null)
$versions | Out-File -Encoding utf8 evidence\buoi-02\tool-versions.txt

Write-Host "[Lab02] Running Spectral lint..."
npx spectral lint openapi.yaml --ruleset campus-spectral.yaml --format text | Out-File -Encoding utf8 evidence\buoi-02\spectral-report.txt

Write-Host "[Lab02] Collecting git log..."
git log --oneline -n 10 | Out-File -Encoding utf8 evidence\buoi-02\git-log.txt

Write-Host "[Lab02] Done. Evidence saved to evidence/buoi-02/"
