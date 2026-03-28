local addon = { DifficultyRules = {} }

local function createFontString()
	local fontString = {
		shown = true,
		text = "",
		width = 0,
	}

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
	function fontString:Show()
		self.shown = true
	end
	function fontString:Hide()
		self.shown = false
	end
	function fontString:SetShown(value)
		self.shown = value and true or false
	end
	function fontString:IsShown()
		return self.shown
	end
	function fontString:SetWidth(value)
		self.width = tonumber(value) or 0
	end
	function fontString:GetStringWidth()
		return #tostring(self.text or "") * 7
	end

	return fontString
end

local function createTexture()
	local texture = {
		shown = true,
		texture = nil,
	}

	function texture:SetAllPoints() end
	function texture:SetPoint() end
	function texture:ClearAllPoints() end
	function texture:SetColorTexture() end
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
	function texture:IsShown()
		return self.shown
	end

	return texture
end

local function createFrame(frameType, parent)
	local frame = {
		frameType = frameType,
		parent = parent,
		shown = true,
		width = 0,
		height = 0,
		scripts = {},
	}

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
	function frame:SetVerticalScroll(value)
		self.verticalScroll = value
	end

	return frame
end

CreateFrame = function(frameType, _, parent)
	return createFrame(frameType, parent)
end

GameTooltip = {
	Hide = function() end,
	SetOwner = function() end,
	ClearLines = function() end,
	AddLine = function() end,
	Show = function() end,
}

RAID_CLASS_COLORS = {
	PRIEST = { r = 1, g = 1, b = 1 },
}

GameFontNormal = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}
GameFontDisableSmall = {}
GameFontDisable = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local collapsedState = {}

local store = {
	summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false),
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	collectSameAppearance = false,
	revision = 1,
	instances = {
		["raid::1"] = {
			instanceKey = "raid::1",
			instanceType = "raid",
			journalInstanceID = 1,
			instanceName = "Mock Raid",
			expansionName = "Mock Expansion",
			expansionOrder = 1,
			instanceOrder = 1,
			raidOrder = 1,
			difficulties = {
				[16] = {
					difficultyID = 16,
					progress = 8,
					encounters = 8,
					state = "ready",
					bucketKeys = {
						total = "raid::1::16::TOTAL::ALL",
						byClass = {
							PRIEST = "raid::1::16::CLASS::PRIEST",
						},
					},
				},
			},
		},
	},
	buckets = {
		["raid::1::16::CLASS::PRIEST"] = {
			bucketKey = "raid::1::16::CLASS::PRIEST",
			counts = { setCollected = 1, setTotal = 2, collectibleCollected = 0, collectibleTotal = 0 },
			setIDs = { [1504] = true },
			members = {
				setPieces = {
					["piece::1"] = { collected = true, itemID = 1, sourceID = 1, setIDs = { 1504 } },
					["piece::2"] = { collected = false, itemID = 2, sourceID = 2, setIDs = { 1504 } },
				},
				collectibles = {},
			},
		},
		["raid::1::16::TOTAL::ALL"] = {
			bucketKey = "raid::1::16::TOTAL::ALL",
			counts = { setCollected = 1, setTotal = 2, collectibleCollected = 0, collectibleTotal = 0 },
			setIDs = { [1504] = true },
			members = {
				setPieces = {
					["piece::1"] = { collected = true, itemID = 1, sourceID = 1, setIDs = { 1504 } },
					["piece::2"] = { collected = false, itemID = 2, sourceID = 2, setIDs = { 1504 } },
				},
				collectibles = {},
			},
		},
	},
	scanManifest = {},
	membershipIndex = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false),
		byItemID = {},
		bySourceID = {},
		byAppearanceID = {},
		bySetID = {},
	},
	reconcileQueue = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false),
		order = {},
		entries = {},
	},
}

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getStoredCache = function()
		return store
	end,
	getDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getDifficultyName = function(difficultyID)
		if tonumber(difficultyID) == 16 then
			return "Mythic"
		end
		return tostring(difficultyID)
	end,
	getDifficultyDisplayOrder = function(difficultyID)
		return tonumber(difficultyID) or 999
	end,
	getExpansionOrder = function()
		return 1
	end,
	getSetProgress = function()
		return 0, 0
	end,
	isCollectSameAppearanceEnabled = function()
		return false
	end,
	getInstanceGroupTag = function()
		return "T"
	end,
	getDashboardInstanceType = function()
		return "raid"
	end,
	isExpansionCollapsed = function(expansionName)
		return collapsedState[tostring(expansionName or "")] == true
	end,
	toggleExpansionCollapsed = function(expansionName)
		local key = tostring(expansionName or "")
		collapsedState[key] = not collapsedState[key]
		return collapsedState[key]
	end,
})

local firstData = assert(RaidDashboard.BuildData())
collapsedState["Mock Expansion"] = true
local secondData = assert(RaidDashboard.BuildData())
assert(firstData == secondData, "expected collapse toggle to keep dashboard build cache hot")

local owner = { dashboardMetricMode = "sets" }
local content = createFrame("Frame", nil)
content:SetSize(700, 1)
local scrollFrame = createFrame("ScrollFrame", nil)
scrollFrame:SetSize(720, 400)

collapsedState["Mock Expansion"] = false
RaidDashboard.RenderContent(owner, content, scrollFrame)
assert(owner.dashboardUI and owner.dashboardUI.rows and owner.dashboardUI.rows[1], "expected expansion row to render")
assert(owner.dashboardUI.rows[1]:IsShown(), "expected expansion row to stay visible when expanded")
assert(owner.dashboardUI.rows[2] and owner.dashboardUI.rows[2]:IsShown(), "expected instance row to render when expansion is expanded")
local expandedHeight = tonumber(content.height) or 0
local expandedSummary = owner.dashboardUI.rows[1].cells[1].topText:GetText()

collapsedState["Mock Expansion"] = true
RaidDashboard.RenderContent(owner, content, scrollFrame)
assert(owner.dashboardUI.rows[1]:IsShown(), "expected expansion row to stay visible when collapsed")
assert(owner.dashboardUI.rows[2] and not owner.dashboardUI.rows[2]:IsShown(), "expected instance row to hide when expansion is collapsed")
local collapsedHeight = tonumber(content.height) or 0
local collapsedSummary = owner.dashboardUI.rows[1].cells[1].topText:GetText()

assert(collapsedHeight < expandedHeight, "expected collapsed content height to shrink")
assert(expandedSummary == collapsedSummary, "expected expansion summary metric to stay stable across collapse toggles")

collapsedState["Mock Expansion"] = false
RaidDashboard.RenderContent(owner, content, scrollFrame)
assert(owner.dashboardUI.rows[2] and owner.dashboardUI.rows[2]:IsShown(), "expected instance row to show again after re-expanding")

print("validated_dashboard_expand_collapse=true")
print(string.format("expanded_height=%d", expandedHeight))
print(string.format("collapsed_height=%d", collapsedHeight))
