--[[
	Minimap buttons (Diablo-WoW)
	DiabolicUI hides the Blizzard minimap cluster, which also hid the tracking,
	mail, LFG, battleground and calendar buttons, plus every addon/server button
	attached to the minimap. This collects them into a row under the round minimap.
]]
local ADDON, Engine = ...
local Module = Engine:NewModule("MinimapButtons", "LOW")

local pairs, ipairs, select, type = pairs, ipairs, select, type
local CreateFrame = CreateFrame

local SIZE, SPACING, PER_ROW = 26, 3, 7

-- Blizzard buttons we always want (shown only while the game shows them)
local BLIZZARD = { "MiniMapTracking", "GameTimeFrame", "MiniMapMailFrame", "MiniMapLFGFrame", "MiniMapBattlefieldFrame" }

-- things on/around the minimap that are not buttons for this bar
local IGNORE = {
	Minimap = true, MinimapBackdrop = true, MinimapBorder = true, MinimapBorderTop = true,
	MinimapZoomIn = true, MinimapZoomOut = true, MinimapZoneTextButton = true, MinimapNorthTag = true,
	MiniMapWorldMapButton = true, MinimapPing = true, MiniMapVoiceChatFrame = true, MiniMapPing = true,
	MiniMapInstanceDifficulty = true, TimeManagerClockButton = true, MiniMapTrackingButton = true,
	MiniMapMailBorder = true, MinimapCompassTexture = true, MiniMapBattlefieldDropDown = true,
	MiniMapLFGFrameDropDown = true, MinimapCluster = true,
}

local slots = {}   -- [button] = slot frame
local order = {}   -- buttons in display order

local function Layout()
	local bar = Module.bar
	if not bar then return end
	local n = 0
	for _, button in ipairs(order) do
		local slot = slots[button]
		local shown = button:IsShown() and not button.__duiHidden
		if shown then
			n = n + 1
			local col = (n - 1) % PER_ROW
			local row = math.floor((n - 1) / PER_ROW)
			slot:ClearAllPoints()
			slot:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (SIZE + SPACING), -row * (SIZE + SPACING))
			slot:Show()
		else
			slot:Hide()
		end
	end
	local cols = math.min(n, PER_ROW)
	bar:SetWidth(math.max(1, cols * (SIZE + SPACING) - SPACING))
	bar:SetHeight(math.max(1, math.ceil(n / PER_ROW) * (SIZE + SPACING)))
end

local function Pin(button)
	if button.__duiPinning then return end
	button.__duiPinning = true
	button:ClearAllPoints()
	button:SetPoint("CENTER", slots[button], "CENTER", 0, 0)
	button.__duiPinning = nil
end

local function Adopt(button)
	if slots[button] or not button or not button.GetName then return end
	local name = button:GetName()
	if not name or IGNORE[name] then return end

	local slot = CreateFrame("Frame", nil, Module.bar)
	slot:SetSize(SIZE, SIZE)
	slots[button] = slot
	order[#order + 1] = button

	local w, h = button:GetWidth(), button:GetHeight()
	local big = math.max(w or SIZE, h or SIZE)
	if big and big > 0 then
		button:SetScale(SIZE / big)
	end
	button:SetParent(slot)
	button:SetFrameLevel(slot:GetFrameLevel() + 2)
	Pin(button)
	-- addons (LibDBIcon) re-place their buttons around the map, keep them in the bar
	hooksecurefunc(button, "SetPoint", Pin)
	if button.HookScript then
		button:HookScript("OnShow", Layout)
		button:HookScript("OnHide", Layout)
	end
	-- no dragging around the round map
	if button.RegisterForDrag then button:RegisterForDrag() end
end

local function IsButtonLike(f)
	if not f or not f.GetName or not f:GetName() then return end
	if f:IsObjectType("Button") then return true end
	if f.HasScript and f:HasScript("OnClick") and f:GetScript("OnClick") then return true end
	-- Frames that contain a button (MiniMapTracking, mail, LFG...)
	return false
end

Module.Scan = function(self)
	for _, name in ipairs(BLIZZARD) do
		local f = _G[name]
		if f then Adopt(f) end
	end
	for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
		if parent then
			for i = 1, parent:GetNumChildren() do
				local child = select(i, parent:GetChildren())
				if IsButtonLike(child) then Adopt(child) end
			end
		end
	end
	Layout()
end

Module.OnEnable = function(self)
	local minimap = Engine:GetModule("Minimap", true)
	local holder = minimap and minimap.frame
	if not holder then return end

	local bar = CreateFrame("Frame", "DiabolicUIMinimapButtons", holder)
	bar:SetFrameStrata("MEDIUM")
	bar:SetPoint("TOP", holder, "BOTTOM", 0, -26)
	bar:SetSize(1, 1)
	self.bar = bar

	self:Scan()
	-- addons and the client add buttons later, look again a few times
	local elapsed, scans = 0, 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(f, e)
		elapsed = elapsed + e
		if elapsed < 2 then return end
		elapsed = 0
		scans = scans + 1
		self:Scan()
		if scans >= 5 then f:SetScript("OnUpdate", nil) end
	end)
	self:RegisterEvent("ADDON_LOADED", "Scan")
	self:RegisterEvent("UPDATE_PENDING_MAIL", "Scan")
end
