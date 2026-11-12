--[[
	DiabolicUI movers (Diablo-WoW)

	Makes non-bar elements movable and resizable: minimap, quest tracker, cast bar,
	buffs, target, target of target, focus. They unlock together with the action
	bars (/dui lock, or "Закрепить" in the DiabolicBars window): drag the green
	boxes, right click a box to put the element back to its default place.

	Saved per account in DiabolicUI_OptionsDB.movers[key] = { x, y, scale },
	x/y = offset of the element's center from the center of the DiabolicUI frame.
]]
local ADDON, Engine = ...
local Module = Engine:NewModule("Movers", "LOW")

local pairs, ipairs, type = pairs, ipairs, type
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local PREFIX = "|cff8a0707Diabolic|r|cffffffffUI|r: "

local function DB()
	DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or {}
	DiabolicUI_OptionsDB.movers = DiabolicUI_OptionsDB.movers or {}
	return DiabolicUI_OptionsDB.movers
end

local function Widget(module, widget)
	local m = Engine:GetModule(module, true)
	local w = m and m:GetWidget(widget)
	return w and w.GetFrame and w:GetFrame()
end

-- key, title, getter, secure (can't be moved in combat)
local List = {
	{ key = "minimap", title = "Миникарта", get = function()
		local m = Engine:GetModule("Minimap", true); return m and m.frame
	end },
	{ key = "tracker", title = "Задачи", get = function()
		local m = Engine:GetModule("ObjectivesTracker", true); return m and m.Holder
	end },
	{ key = "castbar", title = "Полоса заклинаний", get = function()
		local left = Widget("UnitFrames", "Unit: Player")
		local cb = left and left.CastBar
		return cb and (cb.scaffold or (cb.GetScaffold and cb:GetScaffold()))
	end },
	{ key = "buffs", title = "Баффы игрока", get = function()
		local m = Engine:GetModule("BuffFrame", true); return m and m.Holder
	end },
	{ key = "target", title = "Цель", secure = true, get = function() return Widget("UnitFrames", "Unit: Target") end },
	{ key = "tot", title = "Цель цели", secure = true, get = function() return Widget("UnitFrames", "Unit: ToT") end },
	{ key = "focus", title = "Фокус", secure = true, get = function() return Widget("UnitFrames", "Unit: Focus") end },
}
Module.List = List
local ByKey = {}
for _, e in ipairs(List) do ByKey[e.key] = e end

-------------------------------------------------------------------------------
-- positioning
-------------------------------------------------------------------------------
local function SavePoints(frame)
	local t = {}
	for i = 1, frame:GetNumPoints() do
		t[i] = { frame:GetPoint(i) }
	end
	return t
end

local function RestorePoints(frame, points)
	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		frame:SetPoint(unpack(p))
	end
end

local function Apply(e)
	local frame = e.frame
	if not frame then return end
	if e.secure and InCombatLockdown() then
		Module.pending = true
		return
	end
	local saved = DB()[e.key]
	local UICenter = Engine:GetFrame()
	if saved and saved.scale then
		frame:SetScale(saved.scale)
	elseif e.defaultScale then
		frame:SetScale(e.defaultScale)
	end
	if saved and saved.x and saved.y then
		local k = UICenter:GetEffectiveScale() / frame:GetEffectiveScale()
		-- elements with a TOP/BOTTOM pair (tracker) need a fixed height once moved
		if e.key == "tracker" then
			frame:SetHeight(frame:GetHeight() > 1 and frame:GetHeight() or 500)
		end
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UICenter, "CENTER", saved.x * k, saved.y * k)
	elseif e.defaultPoints then
		RestorePoints(frame, e.defaultPoints)
	end
	if e.mover and e.mover:IsShown() then Module:PlaceMover(e) end
end

Module.Register = function(self, e)
	if e.frame then return true end
	local frame = e.get()
	if not frame then return end
	e.frame = frame
	e.defaultPoints = SavePoints(frame)
	e.defaultScale = frame:GetScale()
	Apply(e)
	return true
end

Module.RegisterAll = function(self)
	local missing
	for _, e in ipairs(List) do
		if not self:Register(e) then missing = true end
	end
	return not missing
end

-------------------------------------------------------------------------------
-- mover boxes
-------------------------------------------------------------------------------
Module.PlaceMover = function(self, e)
	local frame, mover = e.frame, e.mover
	local UICenter = Engine:GetFrame()
	local ui, fs = UICenter:GetEffectiveScale(), frame:GetEffectiveScale()
	local w, h = frame:GetWidth() * fs / ui, frame:GetHeight() * fs / ui
	if w < 20 then w = 20 end
	if h < 16 then h = 16 end
	mover:SetSize(w, h)
	local cx, cy = frame:GetCenter()
	mover:ClearAllPoints()
	if cx and cy then
		mover:SetPoint("CENTER", UICenter, "BOTTOMLEFT", cx * fs / ui, cy * fs / ui)
	else
		mover:SetPoint("CENTER", UICenter, "CENTER", 0, 0)
	end
end

local function Mover_OnDragStop(mover)
	mover:StopMovingOrSizing()
	local e = mover.element
	local UICenter = Engine:GetFrame()
	local cx, cy = mover:GetCenter()
	local ux, uy = UICenter:GetCenter()
	if not (cx and ux) then return end
	local db = DB()
	db[e.key] = db[e.key] or {}
	db[e.key].x, db[e.key].y = cx - ux, cy - uy
	Apply(e)
end

local function Mover_OnMouseUp(mover, button)
	if button == "RightButton" then
		local e = mover.element
		local db = DB()
		local scale = db[e.key] and db[e.key].scale
		db[e.key] = scale and { scale = scale } or nil
		Apply(e)
		Module:PlaceMover(e)
	end
end

Module.CreateMover = function(self, e)
	local m = CreateFrame("Frame", nil, Engine:GetFrame())
	m:SetFrameStrata("DIALOG")
	m:SetBackdrop({ bgFile = [[Interface\ChatFrame\ChatFrameBackground]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
	m:SetBackdropColor(0, .6, 0, .45)
	m:SetBackdropBorderColor(.2, 1, .2, .9)
	m:EnableMouse(true)
	m:SetMovable(true)
	m:SetClampedToScreen(true)
	m:RegisterForDrag("LeftButton")
	m:SetScript("OnDragStart", m.StartMoving)
	m:SetScript("OnDragStop", Mover_OnDragStop)
	m:SetScript("OnMouseUp", Mover_OnMouseUp)
	m:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(e.title)
		GameTooltip:AddLine("Перетащите, чтобы переместить.", 1, 1, 1)
		GameTooltip:AddLine("Правый клик — вернуть на место.", 1, 1, 1)
		GameTooltip:AddLine("Размер: /dui → Элементы.", .7, .7, .7)
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local text = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER")
	text:SetText(e.title)
	m.element = e
	m:Hide()
	e.mover = m
	return m
end

Module.Unlock = function(self)
	if InCombatLockdown() then return end
	self:RegisterAll()
	for _, e in ipairs(List) do
		if e.frame then
			local m = e.mover or self:CreateMover(e)
			self:PlaceMover(e)
			m:Show()
		end
	end
	self.unlocked = true
end

Module.Lock = function(self)
	for _, e in ipairs(List) do
		if e.mover then e.mover:Hide() end
	end
	self.unlocked = nil
end

-------------------------------------------------------------------------------
-- options API
-------------------------------------------------------------------------------
Module.GetScale = function(self, key)
	local saved = DB()[key]
	local e = ByKey[key]
	return (saved and saved.scale) or (e and e.defaultScale) or 1
end

Module.SetScale = function(self, key, scale)
	local e = ByKey[key]
	if not e then return end
	if e.secure and InCombatLockdown() then
		return print(PREFIX .. "нельзя менять в бою.")
	end
	local db = DB()
	db[key] = db[key] or {}
	db[key].scale = scale
	self:Register(e)
	Apply(e)
end

Module.ResetAll = function(self)
	if InCombatLockdown() then return print(PREFIX .. "нельзя в бою.") end
	wipe(DB())
	for _, e in ipairs(List) do
		if e.frame then
			e.frame:SetScale(e.defaultScale or 1)
			Apply(e)
		end
	end
end

-------------------------------------------------------------------------------
-- module
-------------------------------------------------------------------------------
Module.OnEnable = function(self)
	-- the frames are created by other modules, some only after login
	local tries, elapsed = 0, 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(f, e)
		elapsed = elapsed + e
		if elapsed < .5 then return end
		elapsed = 0
		tries = tries + 1
		if (self:RegisterAll() and not InCombatLockdown()) or tries > 40 then
			f:SetScript("OnUpdate", nil)
		end
	end)

	-- unlock/lock together with the action bars
	local BT = _G.DiabolicBars
	if BT then
		hooksecurefunc(BT, "Unlock", function() self:Unlock() end)
		hooksecurefunc(BT, "Lock", function() self:Lock() end)
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "Lock")
end

Module.OnRegenEnabled = function(self)
	if self.pending then
		self.pending = nil
		for _, e in ipairs(List) do Apply(e) end
	end
end
