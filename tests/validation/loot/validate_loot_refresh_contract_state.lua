local addon = {}

assert(loadfile("src/loot/LootDataController.lua"))("MogTracker", addon)

local LootDataController = assert(addon.LootDataController)

-- RefreshRequest validation: manual_refresh is strong refresh, runtime_event is weak refresh,
-- and class scope upgrades filter_changed into collect invalidation.
local manualRefresh = LootDataController.BuildRefreshContractState({
	reason = "manual_refresh",
})
assert(manualRefresh.reason == "manual_refresh", "expected manual_refresh reason")
assert(manualRefresh.shouldResetSessionBaseline == true, "expected manual_refresh to reset session baseline")
assert(manualRefresh.shouldInvalidateCollect == true, "expected manual_refresh to invalidate collect")

local runtimeEvent = LootDataController.BuildRefreshContractState({
	reason = "runtime_event",
})
assert(runtimeEvent.reason == "runtime_event", "expected runtime_event reason")
assert(runtimeEvent.shouldResetSessionBaseline == false, "expected runtime_event to keep session baseline")
assert(runtimeEvent.shouldInvalidateCollect == false, "expected runtime_event to avoid collect invalidation")
assert(runtimeEvent.shouldPreserveCollapseState == true, "expected runtime_event to preserve collapse state")

local filterChanged = LootDataController.BuildRefreshContractState({
	reason = "filter_changed",
})
assert(filterChanged.shouldInvalidateCollect == false, "expected normal filter_changed to stay derive-only")
assert(filterChanged.shouldPreserveCollapseState == true, "expected filter_changed to preserve collapse state")

local classScopeUpgrade = LootDataController.BuildRefreshContractState({
	reason = "filter_changed",
	classScopeModeChanged = true,
})
assert(classScopeUpgrade.shouldInvalidateCollect == true, "expected class scope upgrade to invalidate collect")

local selectionChanged = LootDataController.BuildRefreshContractState({
	reason = "selection_changed",
})
assert(selectionChanged.shouldClearCollapseState == true, "expected selection_changed to clear collapse state")

print("validated_loot_refresh_contract_state=true")
