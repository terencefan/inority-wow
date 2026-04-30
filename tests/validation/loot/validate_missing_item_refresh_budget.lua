local addon = {}

assert(loadfile("src/loot/LootPanelController.lua"))("MogTracker", addon)

local LootPanelController = assert(addon.LootPanelController)

local lootRefreshPending = false

LootPanelController.Configure({
	getLootRefreshPending = function()
		return lootRefreshPending
	end,
	setLootRefreshPending = function(value)
		lootRefreshPending = value and true or false
	end,
})

LootPanelController.ResetMissingItemRefreshState()

assert(LootPanelController.GetMissingItemRefreshAttempts() == 0, "expected missing-item retry state to start empty")
assert(
	LootPanelController.GetMissingItemRefreshDelaySeconds() == 3,
	"expected missing-item retry delay to be 3 seconds"
)
assert(
	LootPanelController.GetMissingItemRefreshMaxAttempts() == 40,
	"expected missing-item retry budget to allow longer refresh polling"
)

for attempt = 1, LootPanelController.GetMissingItemRefreshMaxAttempts() do
	local shouldSchedule = LootPanelController.EvaluateMissingItemRefresh({
		missingItemData = true,
		selectionKey = "raid::1",
	})
	assert(shouldSchedule == true, string.format("expected attempt %d to schedule a retry", attempt))
	assert(
		LootPanelController.GetMissingItemRefreshAttempts() == attempt,
		string.format("expected attempt count %d", attempt)
	)
end

do
	local shouldSchedule = LootPanelController.EvaluateMissingItemRefresh({
		missingItemData = true,
		selectionKey = "raid::1",
	})
	assert(shouldSchedule == false, "expected observations beyond the retry budget to stop auto-refresh scheduling")
	assert(
		LootPanelController.GetMissingItemRefreshAttempts() == LootPanelController.GetMissingItemRefreshMaxAttempts(),
		"expected retry count to stay capped"
	)
end

do
	local shouldSchedule = LootPanelController.EvaluateMissingItemRefresh({
		missingItemData = true,
		selectionKey = "raid::2",
	})
	assert(shouldSchedule == true, "expected a different selection to get a fresh retry budget")
	assert(LootPanelController.GetMissingItemRefreshAttempts() == 1, "expected retry count reset for new selection")
	LootPanelController.EvaluateMissingItemRefresh({
		missingItemData = false,
		selectionKey = "raid::2",
	})
	assert(LootPanelController.GetMissingItemRefreshAttempts() == 0, "expected resolved data to reset retry state")
end

print("validated_missing_item_refresh_budget=true")
