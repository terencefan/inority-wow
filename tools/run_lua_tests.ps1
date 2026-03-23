$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

$testScripts = @(
	"tests\\dungeon_dashboard_test.lua",
	"tests\\format_lockout_progress_test.lua",
	"tests\\priest_ordering_test.lua",
	"tools\\validate_dashboard_setpieces.lua",
	"tools\\validate_journal_instance_resolution.lua",
	"tools\\validate_setpiece_multisource.lua",
	"tools\\validate_universal_setpiece_classes.lua"
)

function Invoke-LuaScriptChecked {
	param(
		[string]$ScriptPath
	)

	& lua $ScriptPath
	if ($LASTEXITCODE -ne 0) {
		throw "Lua validation failed with exit code ${LASTEXITCODE}: $ScriptPath"
	}
}

Push-Location $repoRoot
try {
	foreach ($scriptPath in $testScripts) {
		if (-not (Test-Path -LiteralPath $scriptPath)) {
			Write-Error "Lua validation script not found: $scriptPath"
		}
		Invoke-LuaScriptChecked -ScriptPath $scriptPath
	}
}
finally {
	Pop-Location
}
