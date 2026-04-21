local addon = {}

assert(loadfile("src/loot/LootPanelController.lua"))("MogTracker", addon)

local LootPanelController = assert(addon.LootPanelController)

local callOrder = {}
local lootPanelShown = false
local lootPanel = {
	IsShown = function()
		return lootPanelShown
	end,
	Show = function()
		lootPanelShown = true
	end,
	Hide = function()
		lootPanelShown = false
	end,
}

LootPanelController.Configure({
	getLootPanel = function()
		return lootPanel
	end,
	PreferCurrentLootPanelSelectionOnOpen = function()
		callOrder[#callOrder + 1] = "prefer"
	end,
	InvalidateLootDataCache = function()
		callOrder[#callOrder + 1] = "invalidate"
	end,
	ResetLootPanelSessionState = function(active)
		callOrder[#callOrder + 1] = active and "reset_active" or "reset_inactive"
	end,
	RefreshLootPanel = function()
		callOrder[#callOrder + 1] = "refresh"
	end,
	RecordLootPanelOpenDebug = function() end,
})

LootPanelController.InitializeLootPanel = function() end

LootPanelController.ToggleLootPanel()

local expected = { "prefer", "invalidate", "reset_active", "refresh" }
assert(#callOrder == #expected, string.format("call count mismatch: %d ~= %d", #callOrder, #expected))
for index, value in ipairs(expected) do
	assert(callOrder[index] == value, string.format("callOrder[%d] mismatch: %s ~= %s", index, tostring(callOrder[index]), value))
end

print("loot_panel_open_invalidate_test passed")
