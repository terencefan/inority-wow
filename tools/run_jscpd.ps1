param(
	[switch]$FailOnClones
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot ".jscpd.json"
$jscpdCommand = Get-Command "jscpd" -ErrorAction SilentlyContinue

if (-not $jscpdCommand) {
	Write-Error "jscpd is not available on PATH. Install it with 'npm install -g jscpd', then rerun this script."
}

function Invoke-NativeChecked {
	param(
		[string]$FilePath,
		[string[]]$ArgumentList
	)

	$output = & $FilePath @ArgumentList 2>&1
	$exitCode = $LASTEXITCODE
	if ($output) {
		$output | ForEach-Object { $_ }
	}

	if ($exitCode -eq 0) {
		return
	}

	if (-not $FailOnClones) {
		$hasCloneSummary = $output | Select-String -Pattern "Found \d+ clones\."
		if ($hasCloneSummary) {
			return
		}
	}

	throw "Command failed with exit code ${exitCode}: $FilePath $($ArgumentList -join ' ')"
}

Push-Location $repoRoot
try {
	Invoke-NativeChecked -FilePath $jscpdCommand.Source -ArgumentList @(
		"--config",
		$configPath,
		"src",
		"Locale",
		"tests",
		"tools"
	)
}
finally {
	Pop-Location
}
