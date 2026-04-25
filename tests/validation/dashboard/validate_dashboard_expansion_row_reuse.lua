local addon = {}

local function createFontString()
	local fontString = { shown = true, text = "" }
	function fontString:SetText(value)
		self.text = tostring(value or "")
	end
	function fontString:GetText()
		return self.text
	end
	function fontString:SetPoint() end
	function fontString:ClearAllPoints() end
	function fontString:SetJustifyH() end
	function fontString:SetFontObject() end
	function fontString:SetTextColor() end
	function fontString:SetWidth() end
	function fontString:GetStringWidth()
		return #tostring(self.text or "") * 7
	end
	function fontString:Show()
		self.shown = true
	end
	function fontString:Hide()
		self.shown = false
	end
	function fontString:SetShown(value)
		self.shown = value and true or false
	end
	return fontString
end

local function createTexture()
	local texture = { shown = true }
	function texture:SetAllPoints() end
	function texture:SetPoint() end
	function texture:ClearAllPoints() end
	function texture:SetColorTexture() end
	function texture:SetVertexColor() end
	function texture:SetHeight() end
	function texture:SetWidth() end
	function texture:SetSize() end
	function texture:SetTexture(value)
		self.texture = value
	end
	function texture:Show()
		self.shown = true
	end
	function texture:Hide()
		self.shown = false
	end
	function texture:SetShown(value)
		self.shown = value and true or false
	end
	return texture
end

local function createFrame(frameType, parent)
	local frame = { frameType = frameType, parent = parent, shown = true, width = 0, height = 0, scripts = {} }
	function frame:CreateTexture()
		return createTexture()
	end
	function frame:CreateFontString()
		return createFontString()
	end
	function frame:SetPoint() end
	function frame:ClearAllPoints() end
	function frame:SetAllPoints() end
	function frame:SetWidth(value)
		self.width = tonumber(value) or self.width
	end
	function frame:SetHeight(value)
		self.height = tonumber(value) or self.height
	end
	function frame:SetSize(width, height)
		self.width = tonumber(width) or self.width
		self.height = tonumber(height) or self.height
	end
	function frame:GetWidth()
		return self.width
	end
	function frame:GetHeight()
		return self.height
	end
	function frame:EnableMouse(value)
		self.mouseEnabled = value and true or false
	end
	function frame:SetEnabled(value)
		self.enabled = value and true or false
	end
	function frame:SetText(value)
		self.text = tostring(value or "")
	end
	function frame:SetScript(name, handler)
		self.scripts[name] = handler
	end
	function frame:Show()
		self.shown = true
	end
	function frame:Hide()
		self.shown = false
	end
	function frame:SetShown(value)
		self.shown = value and true or false
	end
	function frame:IsShown()
		return self.shown
	end
	return frame
end

CreateFrame = function(frameType, _, parent)
	return createFrame(frameType, parent)
end

UIParent = {}
GameTooltip = {
	Hide = function() end,
	SetOwner = function() end,
	ClearLines = function() end,
	AddLine = function() end,
	AddDoubleLine = function() end,
	Show = function() end,
}
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 } }
GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}
GameFontDisableSmall = {}
GameFontDisable = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local owner = {}
local content = CreateFrame("Frame", nil, UIParent)
content:SetSize(900, 1)
local scrollFrame = CreateFrame("ScrollFrame", nil, UIParent)
scrollFrame:SetSize(900, 400)
owner.dashboardUI = {
	rows = {
		(function()
			local row = CreateFrame("Frame", nil, content)
			row.background = row:CreateTexture(nil, "BACKGROUND")
			row.collectionIcon = row:CreateTexture(nil, "OVERLAY")
			row.tierLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.difficultyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.cells = {}
			row.subRows = {}
			return row
		end)(),
	},
}

local storedCache = {
	summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	revision = 1,
	instances = {
		["raid::1"] = {
			instanceKey = "raid::1",
			instanceType = "raid",
			journalInstanceID = 1,
			instanceName = "Test Raid",
			expansionName = "军团再临",
			expansionOrder = 6,
			instanceOrder = 1,
			difficulties = {},
		},
	},
	buckets = {},
	scanManifest = {},
	membershipIndex = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
		byItemID = {},
		bySourceID = {},
		byAppearanceID = {},
		bySetID = {},
	},
	reconcileQueue = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
		order = {},
		entries = {},
	},
}

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getDashboardInstanceType = function()
		return "raid"
	end,
	getStoredCache = function()
		return storedCache
	end,
	getDashboardBulkScanExpansionRows = function()
		return {
			{ expansionName = "军团再临", expansionOrder = 6, total = 1, completed = 0, state = "idle" },
		}
	end,
	getExpansionInfoForInstance = function(selection)
		return {
			expansionName = selection and selection.expansionName or "军团再临",
			expansionOrder = 6,
			instanceOrder = 1,
		}
	end,
	getExpansionOrder = function()
		return 6
	end,
	getDifficultyDisplayOrder = function()
		return 1
	end,
	getDisplaySetName = function(setEntry)
		return tostring(setEntry and setEntry.name or "")
	end,
	getSelectionLockoutProgress = function()
		return nil
	end,
	startDashboardBulkScan = function() end,
})

RaidDashboard.RenderContent(owner, content, scrollFrame)

assert(owner.dashboardUI.rows[1], "expected reused row slot")
assert(owner.dashboardUI.rows[1].refreshIconButton, "expected reused expansion row to lazily create refresh button")

print("validated_dashboard_expansion_row_reuse=true")
