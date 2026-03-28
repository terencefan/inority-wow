local addon = {}

assert(loadfile("src/dashboard/DashboardPanelController.lua"))("MogTracker", addon)

local DashboardPanelController = assert(addon.DashboardPanelController)

local function makeLabel()
	return {
		text = "",
		SetText = function(self, value)
			self.text = tostring(value or "")
		end,
	}
end

local function makeButton()
	return {
		enabled = true,
		shown = true,
		text = "",
		SetEnabled = function(self, value)
			self.enabled = value and true or false
		end,
		SetShown = function(self, value)
			self.shown = value and true or false
		end,
		SetText = function(self, value)
			self.text = tostring(value or "")
		end,
	}
end

local consumeCalls = 0
local renderCalls = 0
local startCalls = {}

local dashboardPanel = {
	content = {},
	scrollFrame = {},
	title = makeLabel(),
	subtitle = makeLabel(),
	viewButtons = {
		raid_sets = makeButton(),
		dungeon_sets = makeButton(),
		raid_collectibles = makeButton(),
		dungeon_collectibles = makeButton(),
	},
	scanRaidButton = makeButton(),
	scanDungeonButton = makeButton(),
	dashboardViewKey = "raid_sets",
}

DashboardPanelController.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardPanel = function()
		return dashboardPanel
	end,
	StartDashboardBulkScan = function(_, instanceType)
		startCalls[#startCalls + 1] = tostring(instanceType or "")
	end,
})

addon.RaidDashboard = {
	RenderContent = function()
		renderCalls = renderCalls + 1
	end,
}

DashboardPanelController.RefreshDashboardPanel()
DashboardPanelController.RefreshDashboardPanel()

assert(consumeCalls == 0, "expected refresh path to avoid auto-consuming pending collection updates")
assert(renderCalls == 2, "expected render content to still run on each refresh")
assert(dashboardPanel.title.text == "幻化统计看板", "expected dashboard title to refresh")
assert(dashboardPanel.viewButtons.raid_sets.enabled == false, "expected active view button disabled")
assert(dashboardPanel.viewButtons.dungeon_sets.enabled == true, "expected inactive view button enabled")
assert(dashboardPanel.scanRaidButton.shown == true, "expected raid scan button visible in unified dashboard view")
assert(dashboardPanel.scanDungeonButton.shown == true, "expected dungeon scan button visible in unified dashboard view")
assert(dashboardPanel.scanRaidButton.text == "扫描团队副本", "expected raid scan button label")
assert(dashboardPanel.scanDungeonButton.text == "扫描地下城", "expected dungeon scan button label")

print("validated_dashboard_deferred_collection_refresh=true")
