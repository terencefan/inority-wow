param(
	[switch]$Check
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$styluaPath = Get-Command stylua -ErrorAction SilentlyContinue

if (-not $styluaPath) {
	Write-Error "stylua is not installed or not on PATH. Install it first, then rerun this script."
}

$targets = @(
	"src",
	"tests",
	"tools",
	"Locale"
)

$args = @()
if ($Check) {
	$args += "--check"
	$args += "--respect-ignores"
} else {
	$args += "--respect-ignores"
}
$args += $targets

Push-Location $repoRoot
try {
	& $styluaPath.Source @args
	if ($LASTEXITCODE -ne 0) {
		throw "stylua failed with exit code ${LASTEXITCODE}"
	}
}
finally {
	Pop-Location
}
