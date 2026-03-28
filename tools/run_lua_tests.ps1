$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

$testScripts = @(
	"tests\\unit\\dashboard\\dungeon_dashboard_test.lua",
	"tests\\unit\\core\\format_lockout_progress_test.lua",
	"tests\\unit\\core\\priest_ordering_test.lua",
	"tests\\validation\\data\\validate_storage_layer_metadata.lua",
	"tests\\validation\\dashboard\\validate_dashboard_setpieces.lua",
	"tests\\validation\\dashboard\\validate_dashboard_metric_views.lua",
	"tests\\validation\\dashboard\\validate_dashboard_highest_difficulty.lua",
	"tests\\validation\\dashboard\\validate_dashboard_expand_collapse.lua",
	"tests\\validation\\dashboard\\validate_dashboard_collection_refresh.lua",
	"tests\\validation\\dashboard\\validate_dashboard_deferred_collection_refresh.lua",
	"tests\\validation\\dashboard\\validate_dashboard_bulk_scan_plan.lua",
	"tests\\validation\\dashboard\\validate_dashboard_planned_expansion_rows.lua",
	"tests\\validation\\dashboard\\validate_dashboard_expansion_row_reuse.lua",
	"tests\\validation\\dashboard\\validate_dashboard_slot_fallback.lua",
	"tests\\validation\\runtime\\validate_event_chat_logging.lua",
	"tests\\validation\\loot\\validate_current_instance_loot_summary.lua",
	"tests\\validation\\loot\\validate_lootdata_current_instance_summary.lua",
	"tests\\validation\\loot\\validate_lootpanel_filtered_autocollapse.lua",
	"tests\\validation\\loot\\validate_missing_item_refresh_budget.lua",
	"tests\\validation\\loot\\validate_missing_item_debug_logging.lua",
	"tests\\validation\\loot\\validate_set_same_appearance_collection.lua",
	"tests\\validation\\metadata\\validate_journal_instance_resolution.lua",
	"tests\\validation\\item_facts\\validate_item_fact_cold_start.lua",
	"tests\\validation\\loot\\validate_setpiece_multisource.lua",
	"tests\\validation\\loot\\validate_universal_setpiece_classes.lua"
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
