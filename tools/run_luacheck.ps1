param(
	[switch]$FailOnWarnings
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot ".luacheckrc"
$luacheckScript = Join-Path $env:APPDATA "luarocks\\bin\\luacheck"
$luarocksRoot = Join-Path $env:APPDATA "luarocks"
$luarocksShareLuaPath = Join-Path $luarocksRoot "share\\lua\\5.4"
$luarocksLibLuaPath = Join-Path $luarocksRoot "lib\\lua\\5.4"
$luarocksBinPath = Join-Path $luarocksRoot "bin"
$luarocksLuaPath = & luarocks path --lr-path
$luarocksLuaCPath = & luarocks path --lr-cpath

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

function Prepend-EnvList {
	param(
		[string]$CurrentValue,
		[string[]]$Entries
	)

	$parts = @()
	$seen = @{}

	foreach ($entry in $Entries) {
		if ([string]::IsNullOrWhiteSpace($entry)) {
			continue
		}

		foreach ($piece in ($entry -split ';')) {
			$normalized = $piece.Trim()
			if ([string]::IsNullOrWhiteSpace($normalized) -or $seen.ContainsKey($normalized)) {
				continue
			}
			$seen[$normalized] = $true
			$parts += $normalized
		}
	}

	foreach ($piece in (($CurrentValue -split ';'))) {
		$normalized = $piece.Trim()
		if ([string]::IsNullOrWhiteSpace($normalized) -or $seen.ContainsKey($normalized)) {
			continue
		}
		$seen[$normalized] = $true
		$parts += $normalized
	}

	return ($parts -join ';')
}

Push-Location $repoRoot
try {
	$rockLuaEntries = @(
		(Join-Path $luarocksShareLuaPath "?.lua"),
		(Join-Path $luarocksShareLuaPath "?\\init.lua")
	)
	$rockLuaCEntries = @(
		(Join-Path $luarocksLibLuaPath "?.dll")
	)
	$env:LUA_PATH = Prepend-EnvList -CurrentValue $env:LUA_PATH -Entries ($rockLuaEntries + @($luarocksLuaPath))
	$env:LUA_CPATH = Prepend-EnvList -CurrentValue $env:LUA_CPATH -Entries ($rockLuaCEntries + @($luarocksLuaCPath))
	$env:PATH = Prepend-EnvList -CurrentValue $env:PATH -Entries @($luarocksBinPath)
	Invoke-NativeChecked -FilePath "lua" -ArgumentList (@($luacheckScript, "--config", $configPath) + $targets)
}
finally {
	Pop-Location
}
