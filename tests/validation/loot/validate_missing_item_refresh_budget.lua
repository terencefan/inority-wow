local addon = {}

assert(loadfile("src/loot/LootPanelRenderer.lua"))("MogTracker", addon)

local LootPanelRenderer = assert(addon.LootPanelRenderer)

LootPanelRenderer.ResetMissingItemRefreshState()

assert(LootPanelRenderer.GetMissingItemRefreshAttempts() == 0, "expected missing-item retry state to start empty")
assert(LootPanelRenderer.GetMissingItemRefreshDelaySeconds() == 3, "expected missing-item retry delay to be 3 seconds")
assert(
	LootPanelRenderer.GetMissingItemRefreshMaxAttempts() == 40,
	"expected missing-item retry budget to allow longer refresh polling"
)

for attempt = 1, LootPanelRenderer.GetMissingItemRefreshMaxAttempts() do
	local shouldSchedule = LootPanelRenderer.EvaluateMissingItemRefresh({
		missingItemData = true,
		selectionKey = "raid::1",
	})
	assert(shouldSchedule == true, string.format("expected attempt %d to schedule a retry", attempt))
	assert(
		LootPanelRenderer.GetMissingItemRefreshAttempts() == attempt,
		string.format("expected attempt count %d", attempt)
	)
end

do
	local shouldSchedule = LootPanelRenderer.EvaluateMissingItemRefresh({
		missingItemData = true,
		selectionKey = "raid::1",
	})
	assert(shouldSchedule == false, "expected observations beyond the retry budget to stop auto-refresh scheduling")
	assert(
		LootPanelRenderer.GetMissingItemRefreshAttempts() == LootPanelRenderer.GetMissingItemRefreshMaxAttempts(),
		"expected retry count to stay capped"
	)
end

do
	local shouldSchedule = LootPanelRenderer.EvaluateMissingItemRefresh({
		missingItemData = true,
		selectionKey = "raid::2",
	})
	assert(shouldSchedule == true, "expected a different selection to get a fresh retry budget")
	assert(LootPanelRenderer.GetMissingItemRefreshAttempts() == 1, "expected retry count reset for new selection")
	LootPanelRenderer.EvaluateMissingItemRefresh({
		missingItemData = false,
		selectionKey = "raid::2",
	})
	assert(LootPanelRenderer.GetMissingItemRefreshAttempts() == 0, "expected resolved data to reset retry state")
end

print("validated_missing_item_refresh_budget=true")
