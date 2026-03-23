param(
	[switch]$FailOnClones
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot ".jscpd.json"
$jscpdCli = Join-Path $repoRoot "node_modules\.bin\jscpd.cmd"

if (-not (Test-Path -LiteralPath $jscpdCli)) {
	Write-Error "jscpd is not installed locally. Run 'npm install' first, then rerun this script."
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
	Invoke-NativeChecked -FilePath $jscpdCli -ArgumentList @(
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
