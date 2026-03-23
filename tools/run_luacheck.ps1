param(
	[switch]$FailOnWarnings
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot ".luacheckrc"
$luacheckScript = Join-Path $env:APPDATA "luarocks\\bin\\luacheck"
$luarocksLuaPath = & luarocks path --lr-path
$luarocksLuaCPath = & luarocks path --lr-cpath
$luarocksBinPath = & luarocks path --lr-bin

if (-not (Test-Path -LiteralPath $luacheckScript)) {
	Write-Error "luacheck is not installed in %APPDATA%\\luarocks\\bin. Install it first, then rerun this script."
}

$targets = @(
	"src",
	"tests",
	"tools"
)

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

	$summary = ($output | Select-String -Pattern "Total:\s+\d+\s+warnings\s+/\s+(\d+)\s+errors" | Select-Object -Last 1)
	$hasOnlyWarnings = $summary -and $summary.Matches[0].Groups[1].Value -eq "0"

	if ($hasOnlyWarnings -and -not $FailOnWarnings) {
		return
	}

	throw "Command failed with exit code ${exitCode}: $FilePath $($ArgumentList -join ' ')"
}

Push-Location $repoRoot
try {
	if ($luarocksLuaPath) {
		$env:LUA_PATH = "$luarocksLuaPath;$env:LUA_PATH"
	}
	if ($luarocksLuaCPath) {
		$env:LUA_CPATH = "$luarocksLuaCPath;$env:LUA_CPATH"
	}
	if ($luarocksBinPath) {
		$env:PATH = "$luarocksBinPath;$env:PATH"
	}
	Invoke-NativeChecked -FilePath "lua" -ArgumentList (@($luacheckScript, "--config", $configPath) + $targets)
}
finally {
	Pop-Location
}
