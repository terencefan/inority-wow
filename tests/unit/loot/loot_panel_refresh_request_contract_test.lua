local addon = {}

assert(loadfile("src/loot/LootPanelController.lua"))("MogTracker", addon)

local LootPanelController = assert(addon.LootPanelController)

local lootPanelState = {
	currentTab = "loot",
	lastManualTab = "sets",
}

local buttonState = {
	lootEnabled = nil,
	setsEnabled = nil,
}

local callOrder = {}
local refreshRequests = {}

local lootPanel = {
	lootTabButton = {
		SetEnabled = function(_, enabled)
			buttonState.lootEnabled = enabled
		end,
	},
	setsTabButton = {
		SetEnabled = function(_, enabled)
			buttonState.setsEnabled = enabled
		end,
	},
}

LootPanelController.Configure({
	getLootPanel = function()
		return lootPanel
	end,
	getLootPanelState = function()
		return lootPanelState
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
	ResetLootPanelScrollPosition = function()
		callOrder[#callOrder + 1] = "reset_scroll"
	end,
	RefreshLootPanel = function(request)
		callOrder[#callOrder + 1] = "refresh"
		refreshRequests[#refreshRequests + 1] = request
	end,
})

-- RefreshRequest regression: open restores remembered tab and keeps strong refresh semantics.
local openRequest = LootPanelController.RequestLootPanelRefresh({
	reason = "open",
})

assert(openRequest.reason == "open", "expected RefreshRequest.reason=open")
assert(lootPanelState.currentTab == "sets", "expected open to restore lastManualTab")
assert(table.concat(callOrder, ",") == "prefer,invalidate,reset_active,refresh", "expected open refresh call order")

callOrder = {}
LootPanelController.SetLootPanelTab("loot")

local tabRequest = assert(refreshRequests[#refreshRequests], "expected tab refresh request")
assert(tabRequest.reason == "tab_changed", "expected tab change RefreshRequest")
assert(tabRequest.targetTab == "loot", "expected tab change targetTab=loot")
assert(lootPanelState.lastManualTab == "loot", "expected tab change to remember lastManualTab")
assert(buttonState.lootEnabled == false, "expected loot tab button disabled when active")
assert(buttonState.setsEnabled == true, "expected sets tab button enabled when inactive")
assert(table.concat(callOrder, ",") == "reset_scroll,refresh", "expected tab change to reset scroll and refresh")

print("loot_panel_refresh_request_contract_test passed")
