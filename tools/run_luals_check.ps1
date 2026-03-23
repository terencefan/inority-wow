param(
	[switch]$FailOnWarnings,
	[ValidateSet("Error", "Warning", "Information", "Hint")]
	[string]$CheckLevel = "Warning"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$defaultLuaLSPath = "C:\Users\Terence\AppData\Local\Microsoft\WinGet\Packages\LuaLS.lua-language-server_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\lua-language-server.exe"
$luaLSCommand = Get-Command "lua-language-server" -ErrorAction SilentlyContinue
$luaLSPath = if ($luaLSCommand) { $luaLSCommand.Source } elseif (Test-Path -LiteralPath $defaultLuaLSPath) { $defaultLuaLSPath } else { $null }

if (-not $luaLSPath) {
	Write-Error "lua-language-server is not installed or not on PATH. Install LuaLS first, then rerun this script."
}

$logDir = Join-Path $repoRoot "dist\luals-check"
if (-not (Test-Path -LiteralPath $logDir)) {
	New-Item -ItemType Directory -Path $logDir | Out-Null
}
$metaDir = Join-Path $logDir "meta"
if (-not (Test-Path -LiteralPath $metaDir)) {
	New-Item -ItemType Directory -Path $metaDir | Out-Null
}

$args = @(
	"--configpath=.luarc.json",
	"--logpath=$logDir",
	"--metapath=$metaDir",
	"--check=$repoRoot",
	"--check_format=pretty",
	"--checklevel=$CheckLevel"
)

Push-Location $repoRoot
try {
	$previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
	$PSNativeCommandUseErrorActionPreference = $false
	$output = & $luaLSPath @args 2>&1
	$exitCode = $LASTEXITCODE
	if ($output) {
		$output | ForEach-Object { $_ }
	}

	if ($exitCode -eq 0) {
		return
	}

	$hasErrors = $output -match "\[Error\]"
	if (-not $FailOnWarnings -and -not $hasErrors) {
		return
	}

	throw "lua-language-server check failed with exit code ${exitCode}"
}
finally {
	$PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
	Pop-Location
}
