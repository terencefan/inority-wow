param(
	[switch]$SkipFormat,
	[switch]$SkipDuplication,
	[switch]$SkipLuaLS,
	[switch]$FailOnWarnings
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$syntaxTargets = @(
	"src",
	"tests",
	"tools",
	"Locale"
)

function Invoke-NativeChecked {
	param(
		[string]$FilePath,
		[string[]]$ArgumentList
	)

	& $FilePath @ArgumentList
	if ($LASTEXITCODE -ne 0) {
		throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ArgumentList -join ' ')"
	}
}

Push-Location $repoRoot
try {
	foreach ($target in $syntaxTargets) {
		$luaFiles = Get-ChildItem -Path $target -Recurse -Filter *.lua -File
		foreach ($luaFile in $luaFiles) {
			Invoke-NativeChecked -FilePath "luac" -ArgumentList @("-p", $luaFile.FullName)
		}
	}

	if ($FailOnWarnings) {
		Invoke-NativeChecked -FilePath "powershell" -ArgumentList @(
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			(Join-Path $PSScriptRoot "run_luacheck.ps1"),
			"-FailOnWarnings"
		)
	} else {
		Invoke-NativeChecked -FilePath "powershell" -ArgumentList @(
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			(Join-Path $PSScriptRoot "run_luacheck.ps1")
		)
	}

	if (-not $SkipLuaLS) {
		Invoke-NativeChecked -FilePath "powershell" -ArgumentList @(
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			(Join-Path $PSScriptRoot "run_luals_check.ps1")
		)
	}

	if (-not $SkipDuplication) {
		Invoke-NativeChecked -FilePath "powershell" -ArgumentList @(
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			(Join-Path $PSScriptRoot "run_jscpd.ps1")
		)
	}

	if (-not $SkipFormat) {
		Invoke-NativeChecked -FilePath "powershell" -ArgumentList @(
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			(Join-Path $PSScriptRoot "run_stylua.ps1"),
			"-Check"
		)
	}

	Invoke-NativeChecked -FilePath "powershell" -ArgumentList @(
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		(Join-Path $PSScriptRoot "run_lua_tests.ps1")
	)
}
finally {
	Pop-Location
}
