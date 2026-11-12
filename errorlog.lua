--[[
	DiabolicUI error log (Diablo-WoW)
	Keeps the last Lua errors in SavedVariables (WTF\Account\<acc>\SavedVariables\DiabolicUI.lua,
	table DiabolicUI_ErrorLog) so they can be sent to the developers.
	The previous error handler (Blizzard popup, BugSack...) keeps working.
	  /dui errors       - print the log
	  /dui errors clear - clear it
]]
local MAX = 60
local pending = {}
local log -- points to DiabolicUI_ErrorLog once the saved variables are loaded

local function store(msg)
	msg = tostring(msg)
	local list = log or pending
	for _, e in ipairs(list) do
		if e.msg == msg then
			e.count = (e.count or 1) + 1
			e.last = date("%Y-%m-%d %H:%M:%S")
			return
		end
	end
	if #list >= MAX then table.remove(list, 1) end
	list[#list + 1] = {
		msg = msg,
		stack = debugstack and debugstack(3, 12, 0) or "",
		count = 1,
		first = date("%Y-%m-%d %H:%M:%S"),
		last = date("%Y-%m-%d %H:%M:%S"),
		build = (GetBuildInfo())
	}
end

local previous = geterrorhandler()
seterrorhandler(function(msg, ...)
	pcall(store, msg)
	if previous then
		return previous(msg, ...)
	end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
	if addon ~= "DiabolicUI" then return end
	self:UnregisterEvent("ADDON_LOADED")
	DiabolicUI_ErrorLog = DiabolicUI_ErrorLog or {}
	log = DiabolicUI_ErrorLog
	for _, e in ipairs(pending) do log[#log + 1] = e end
	while #log > MAX do table.remove(log, 1) end
	wipe(pending)
end)

DiabolicUI_GetErrorLog = function() return log or pending end
