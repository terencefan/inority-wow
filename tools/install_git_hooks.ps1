param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$hooksPath = Join-Path $repoRoot ".githooks"

if (-not (Test-Path -LiteralPath $hooksPath)) {
	throw "Hooks directory not found: $hooksPath"
}

Push-Location $repoRoot
try {
	& git config core.hooksPath ".githooks"
	if ($LASTEXITCODE -ne 0) {
		throw "Failed to set git core.hooksPath to .githooks"
	}

	Write-Host "Git hooks installed."
	Write-Host "core.hooksPath = .githooks"
}
finally {
	Pop-Location
}
