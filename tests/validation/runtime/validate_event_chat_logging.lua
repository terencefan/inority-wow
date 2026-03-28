local addon = {}
_G.unpack = _G.unpack or table.unpack

assert(loadfile("src/runtime/EventsCommandController.lua"))("MogTracker", addon)

local EventsCommandController = assert(addon.EventsCommandController)

local printed = {}
local registeredEvents = {}
local eventHandler

local frame = {
	RegisterEvent = function(_, eventName)
		registeredEvents[#registeredEvents + 1] = eventName
	end,
	SetScript = function(_, scriptName, fn)
		if scriptName == "OnEvent" then
			eventHandler = fn
		end
	end,
}

EventsCommandController.Configure({
	Print = function(message)
		printed[#printed + 1] = tostring(message or "")
	end,
	InitializeDefaults = function()
	end,
	PruneExpiredBossKillCaches = function()
	end,
	CaptureSavedInstances = function()
	end,
	InitializePanel = function()
	end,
	InitializeLootPanel = function()
	end,
	CreateMinimapButton = function()
	end,
	InvalidateLootDataCache = function()
	end,
	RecordEncounterKill = function()
	end,
	RefreshLootPanel = function()
	end,
})

EventsCommandController.RegisterCoreEvents(frame, "MogTracker")

assert(#registeredEvents == 8, "expected eight registered core events")
assert(type(eventHandler) == "function", "expected OnEvent handler to be installed")

eventHandler(frame, "ADDON_LOADED", "MogTracker")
eventHandler(frame, "PLAYER_LOGIN")
eventHandler(frame, "GET_ITEM_INFO_RECEIVED", 19019, true)
eventHandler(frame, "CHAT_MSG_LOOT", "你获得了物品：[测试披风]")
eventHandler(frame, "ENCOUNTER_LOOT_RECEIVED", 2032, 19019, "|cff0070dd|Hitem:19019::::::::|h[雷霆之怒]|h|r")
eventHandler(frame, "ENCOUNTER_END", 1, "Illidan Stormrage", nil, nil, 1)
eventHandler(frame, "TRANSMOG_COLLECTION_UPDATED")

assert(printed[1] == "event: ADDON_LOADED addon=MogTracker", "expected addon loaded message")
assert(printed[2] == "event: PLAYER_LOGIN", "expected player login message")
assert(printed[3] == "event: GET_ITEM_INFO_RECEIVED itemID=19019 ok=true", "expected item info message")
assert(printed[4] == "event: CHAT_MSG_LOOT message=你获得了物品：[测试披风]", "expected chat msg loot message")
assert(printed[5] == "event: ENCOUNTER_LOOT_RECEIVED encounterID=2032 itemID=19019 item=|cff0070dd|Hitem:19019::::::::|h[雷霆之怒]|h|r", "expected encounter loot received message")
assert(printed[6] == "event: ENCOUNTER_END boss=Illidan Stormrage success=1", "expected encounter end message")
assert(printed[7] == "event: TRANSMOG_COLLECTION_UPDATED", "expected transmog event message")

print("validated_event_chat_logging=true")
