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

local raidRenderCalls = 0
local setOverviewRenderCalls = 0
local setHideCalls = 0

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
		class_sets = makeButton(),
	},
	scanRaidButton = makeButton(),
	scanDungeonButton = makeButton(),
	scanPvpButton = makeButton(),
	raidRowDivider = makeButton(),
	dungeonRowDivider = makeButton(),
	dashboardViewKey = "class_sets",
}

DashboardPanelController.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardPanel = function()
		return dashboardPanel
	end,
})

addon.RaidDashboard = {
	HideWidgets = function() end,
	RenderContent = function()
		raidRenderCalls = raidRenderCalls + 1
	end,
}

addon.SetDashboard = {
	HideWidgets = function()
		setHideCalls = setHideCalls + 1
	end,
	RenderOverviewContent = function()
		setOverviewRenderCalls = setOverviewRenderCalls + 1
	end,
}

addon.PvpDashboard = {
	HideWidgets = function() end,
}

DashboardPanelController.RefreshDashboardPanel()

assert(setHideCalls >= 1, "expected set dashboard widgets to be hidden before rerender")
assert(setOverviewRenderCalls == 1, "expected class sets view to render via SetDashboard overview")
assert(raidRenderCalls == 0, "expected raid dashboard render path to stay inactive for class sets view")
assert(dashboardPanel.title.text == "职业套装进度看板", "expected class set dashboard title")
assert(dashboardPanel.scanRaidButton.shown == false, "expected raid scan button hidden in class sets view")
assert(dashboardPanel.scanDungeonButton.shown == false, "expected dungeon scan button hidden in class sets view")
assert(dashboardPanel.scanPvpButton.shown == false, "expected pvp scan button hidden in class sets view")
assert(dashboardPanel.viewButtons.class_sets.enabled == false, "expected active class sets button disabled")
assert(dashboardPanel.viewButtons.raid_sets.enabled == true, "expected raid sets button enabled while inactive")

print("validated_dashboard_class_sets_view=true")
