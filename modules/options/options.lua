--[[
	DiabolicUI options (Diablo-WoW) — one menu for the whole interface.
	Replaces the old options.lua / movers.lua / moveframes.lua / minimap_button.lua,
	which overlapped, registered the same /diomove command three times and saved into
	a table that was never declared in the .toc (so nothing was kept between sessions).

	/dui                 open/close the menu
	/dui lock            lock/unlock the action bars (drag them while unlocked)
	/dui kb              keybinding mode (hover a button and press a key)
	/dui reset           default action bar layout
	/dui errors [clear]  print/clear the error log
	Also available in Esc > Interface > AddOns > DiabolicUI.
]]
local ADDON, Engine = ...
local Module = Engine:NewModule("Options", "LOW")
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)

local pairs, ipairs, type, select, tostring = pairs, ipairs, type, select, tostring
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local PREFIX = "|cff8a0707Diabolic|r|cffffffffUI|r: "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

-------------------------------------------------------------------------------
-- saved settings (per character)
-------------------------------------------------------------------------------
local function CharDB()
	DiabolicUI_CharDB = DiabolicUI_CharDB or {}
	DiabolicUI_CharDB.hidden = DiabolicUI_CharDB.hidden or {}
	return DiabolicUI_CharDB
end

-------------------------------------------------------------------------------
-- element registry: things that can be hidden
-------------------------------------------------------------------------------
local Hider = CreateFrame("Frame")
Hider:Hide()

local function W(module, widget)
	local m = Engine:GetModule(module, true)
	local w = m and m:GetWidget(widget)
	if w and w.GetFrame then return w:GetFrame() end
end

local function Collect(...)
	local t = {}
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		if type(f) == "table" and f.SetParent then t[#t + 1] = f end
	end
	return t
end

local Elements = {
	{ key = "playerorbs", title = "Сферы здоровья и ресурса", secure = true, get = function()
		local UF = Engine:GetModule("UnitFrames", true)
		local t = Collect(W("UnitFrames", "Unit: Player"))
		if UF and UF.artwork then
			for _, tex in pairs(UF.artwork) do
				local p = tex.GetParent and tex:GetParent()
				if p then
					local dupe
					for _, f in ipairs(t) do if f == p then dupe = true end end
					if not dupe then t[#t + 1] = p end
				end
			end
		end
		return t
	end },
	{ key = "target", title = "Фрейм цели (сверху)", secure = true, get = function() return Collect(W("UnitFrames", "Unit: Target")) end },
	{ key = "tot", title = "Цель цели", secure = true, get = function() return Collect(W("UnitFrames", "Unit: ToT")) end },
	{ key = "focus", title = "Фокус", secure = true, get = function() return Collect(W("UnitFrames", "Unit: Focus")) end },
	{ key = "pet", title = "Фрейм питомца", secure = true, get = function() return Collect(W("UnitFrames", "Unit: Pet")) end },
	{ key = "minimap", title = "Миникарта", get = function()
		local m = Engine:GetModule("Minimap", true)
		return Collect(m and m.GetFrame and m:GetFrame())
	end },
	{ key = "xp", title = "Полоска опыта / парагона", get = function()
		return Collect(W("ActionBars", "Bar: XP"), _G.ParagonXPBarFrame)
	end },
	{ key = "buffs", title = "Баффы и дебаффы игрока", get = function()
		return Collect(BuffFrame, TemporaryEnchantFrame, ConsolidatedBuffs)
	end },
	{ key = "tracker", title = "Список заданий", get = function() return Collect(WatchFrame) end },
	{ key = "chat", title = "Окна чата", get = function()
		local t = {}
		for i = 1, (NUM_CHAT_WINDOWS or 10) do
			for _, s in ipairs({ "", "Tab", "ButtonFrame" }) do
				local f = _G["ChatFrame" .. i .. s]
				if f then t[#t + 1] = f end
			end
		end
		for _, n in ipairs({ "GeneralDockManager", "ChatFrameMenuButton", "FriendsMicroButton" }) do
			if _G[n] then t[#t + 1] = _G[n] end
		end
		return t
	end },
}
local ElementByKey = {}
for _, e in ipairs(Elements) do ElementByKey[e.key] = e end

local pendingApply
local function ApplyElement(e, hidden)
	if e.secure and InCombatLockdown() then
		pendingApply = true
		return false
	end
	for _, f in ipairs(e.get() or {}) do
		if hidden then
			if not f.__duiParent then
				f.__duiParent = f:GetParent() or UIParent
				f:SetParent(Hider)
			end
		elseif f.__duiParent then
			f:SetParent(f.__duiParent)
			f.__duiParent = nil
		end
	end
	return true
end

Module.SetElementHidden = function(self, key, hidden)
	local e = ElementByKey[key]
	if not e then return end
	CharDB().hidden[key] = hidden and true or nil
	if not ApplyElement(e, hidden) then
		Print("изменение применится после выхода из боя.")
	end
	if key == "xp" then
		local AB = Engine:GetModule("ActionBars", true)
		if AB and AB.UpdateArtwork then AB:UpdateArtwork() end
	end
end

Module.ApplyAllElements = function(self)
	local hidden = CharDB().hidden
	for _, e in ipairs(Elements) do
		if hidden[e.key] then ApplyElement(e, true) end
	end
end

-------------------------------------------------------------------------------
-- action bars (embedded DiabolicBars / Bartender4)
-------------------------------------------------------------------------------
local function BT() return _G.DiabolicBars end

local Bars = {
	{ id = 1, title = "Основная панель (1 ряд)" },
	{ id = 6, title = "Нижняя панель (2 ряд)" },
	{ id = 5, title = "Нижняя панель (3 ряд)" },
	{ id = 3, title = "Правая панель 1" },
	{ id = 4, title = "Правая панель 2" },
	{ module = "PetBar", title = "Панель питомца" },
	{ module = "StanceBar", title = "Панель стоек / облика" },
	{ module = "MicroMenu", title = "Меню (персонаж, магазин, трансмог...)" },
	{ module = "BagBar", title = "Сумки" },
	{ module = "MultiCast", title = "Тотемы (шаман)" },
}

local function BarEnabled(b)
	local bt = BT()
	if not bt or not bt.db then return false end
	if b.id then
		local AB = bt:GetModule("ActionBars", true)
		return AB and AB.db.profile.actionbars[b.id].enabled
	end
	local m = bt:GetModule(b.module, true)
	return m and m.db and m.db.profile.enabled
end

local function SetBarEnabled(b, on)
	local bt = BT()
	if not bt or InCombatLockdown() then
		Print("панели нельзя менять в бою.")
		return
	end
	if b.id then
		local AB = bt:GetModule("ActionBars", true)
		if not AB then return end
		if on then AB:EnableBar(b.id) else AB:DisableBar(b.id); AB.db.profile.actionbars[b.id].enabled = false end
	else
		local m = bt:GetModule(b.module, true)
		if m then m:ToggleModule(nil, on and true or false) end
	end
	local AB = Engine:GetModule("ActionBars", true)
	if AB and AB.RaiseBars then AB:RaiseBars() end
end

-------------------------------------------------------------------------------
-- small widget helpers
-------------------------------------------------------------------------------
local BACKDROP = {
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
	edgeFile = path .. [[textures\DiabolicUI_Tooltip_Border.tga]],
	edgeSize = 32, tile = false, tileSize = 0,
	insets = { left = 23, right = 23, top = 23, bottom = 23 }
}

local function Header(parent, text, x, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(text)
	fs:SetTextColor(.85, .7, .4)
	return fs
end

local function Check(parent, text, x, y, get, set)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x, y)
	local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
	label:SetText(text)
	cb.refresh = function() cb:SetChecked(get() and true or false) end
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		self.refresh()
	end)
	return cb
end

local function Button(parent, text, x, y, w, onclick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w or 150, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", onclick)
	return b
end

-------------------------------------------------------------------------------
-- menu
-------------------------------------------------------------------------------
Module.CreateMenu = function(self)
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "DiabolicUIOptionsFrame", UIParent)
	f:SetSize(640, 560)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop(BACKDROP)
	f:SetBackdropColor(0, 0, 0, .9)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "DiabolicUIOptionsFrame")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("TOP", 0, -28)
	title:SetText("|cff8a0707Diabolic|r|cffffffffUI|r")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -18, -18)

	f.checks = {}
	local L, R = 34, 340

	-- left column: action bars
	Header(f, "Панели команд", L, -64)
	Button(f, "Разблокировать / закрепить", L, -92, 190, function() self:ToggleLock() end)
	Button(f, "Назначить клавиши", L + 196, -92, 100, function() self:KeyBindMode() end)
	Button(f, "Все настройки панелей…", L, -118, 190, function()
		f:Hide()
		local AB = Engine:GetModule("ActionBars", true)
		if AB then AB:OpenBarOptions() end
	end)
	Button(f, "Сбросить", L + 196, -118, 100, function()
		local AB = Engine:GetModule("ActionBars", true)
		if AB then AB:ApplyDefaultLayout() end
		self:Refresh()
	end)

	local rowsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rowsLabel:SetPoint("TOPLEFT", L + 4, -152)
	rowsLabel:SetText("Рядов внизу:")
	for i = 1, 3 do
		local b = Button(f, tostring(i), L + 90 + (i - 1) * 36, -146, 32, function()
			local AB = Engine:GetModule("ActionBars", true)
			if AB then AB:SetNumBottomRows(i) end
			self:Refresh()
		end)
	end

	local y = -176
	for _, b in ipairs(Bars) do
		f.checks[#f.checks + 1] = Check(f, b.title, L, y, function() return BarEnabled(b) end, function(v) SetBarEnabled(b, v) end)
		y = y - 24
	end
	f.checks[#f.checks + 1] = Check(f, "Подложка (демон, ангел, череп)", L, y,
		function() local AB = Engine:GetModule("ActionBars", true); return AB and AB.db.show_artwork ~= false end,
		function(v) local AB = Engine:GetModule("ActionBars", true); if AB then AB.db.show_artwork = v; AB:UpdateArtwork() end end)

	-- right column: elements
	Header(f, "Элементы интерфейса", R, -64)
	y = -92
	for _, e in ipairs(Elements) do
		f.checks[#f.checks + 1] = Check(f, e.title, R, y,
			function() return not CharDB().hidden[e.key] end,
			function(v) self:SetElementHidden(e.key, not v) end)
		y = y - 24
	end

	-- enemies
	y = y - 8
	Header(f, "Полоски врагов", R, y)
	y = y - 26
	local NP = Engine:GetModule("NamePlates", true)
	local modes = {
		{ "normal", "Над моделью (боссы и элиты — сверху)" },
		{ "all", "Над моделью для всех врагов" },
		{ "top", "Только сверху (как раньше)" },
	}
	f.radios = {}
	for _, m in ipairs(modes) do
		local r = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
		r:SetPoint("TOPLEFT", R + 4, y)
		local label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", r, "RIGHT", 4, 0)
		label:SetText(m[2])
		r.mode = m[1]
		r:SetScript("OnClick", function()
			if NP then NP:SetEnemyMode(m[1]) end
			self:Refresh()
		end)
		f.radios[#f.radios + 1] = r
		y = y - 20
	end
	if NP then
		f.checks[#f.checks + 1] = Check(f, "Мои дебаффы над полоской цели", R, y - 4,
			function() return NP.db and NP.db.showDebuffs end,
			function(v) NP.db.showDebuffs = v end)
	end

	-- footer: error log
	f.errors = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.errors:SetPoint("BOTTOMLEFT", 36, 34)
	Button(f, "Журнал ошибок", 440, -(560 - 56), 160, function() self:PrintErrors() end)

	self.frame = f
	f:SetScript("OnShow", function() self:Refresh() end)
	return f
end

Module.Refresh = function(self)
	local f = self.frame
	if not f then return end
	for _, cb in ipairs(f.checks) do cb.refresh() end
	local NP = Engine:GetModule("NamePlates", true)
	local mode = NP and NP.db and NP.db.enemyMode or "normal"
	for _, r in ipairs(f.radios) do r:SetChecked(r.mode == mode) end
	local n = #(DiabolicUI_GetErrorLog and DiabolicUI_GetErrorLog() or {})
	f.errors:SetText(n > 0 and ("Ошибок в журнале: %d (/dui errors)"):format(n) or "Ошибок нет")
end

Module.Toggle = function(self)
	local f = self:CreateMenu()
	if f:IsShown() then f:Hide() else f:Show() end
end

Module.ToggleLock = function(self)
	if InCombatLockdown() then return Print("нельзя в бою.") end
	local AB = Engine:GetModule("ActionBars", true)
	if AB then AB:ToggleBarLock() end
	if self.frame then self.frame:Hide() end
end

Module.KeyBindMode = function(self)
	local KB = LibStub and LibStub("LibKeyBound-1.0", true)
	if KB then
		if self.frame then self.frame:Hide() end
		KB:Toggle()
	end
end

Module.PrintErrors = function(self, clear)
	local log = DiabolicUI_GetErrorLog and DiabolicUI_GetErrorLog() or {}
	if clear then
		wipe(log)
		Print("журнал ошибок очищен.")
		return self:Refresh()
	end
	if #log == 0 then return Print("ошибок нет.") end
	Print(("ошибок: %d (полностью — в WTF\\...\\SavedVariables\\DiabolicUI.lua)"):format(#log))
	for i = math.max(1, #log - 9), #log do
		local e = log[i]
		DEFAULT_CHAT_FRAME:AddMessage(("|cffff5555%d.|r [x%d] %s"):format(i, e.count or 1, e.msg))
	end
end

-------------------------------------------------------------------------------
-- Blizzard Interface Options entry
-------------------------------------------------------------------------------
Module.CreateBlizzardPanel = function(self)
	local panel = CreateFrame("Frame")
	panel.name = "DiabolicUI"
	local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText("|cff8a0707Diabolic|r|cffffffffUI|r — Diablo-WoW")
	local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
	d:SetWidth(560)
	d:SetJustifyH("LEFT")
	d:SetText("Все настройки интерфейса открываются командой |cffffd100/dui|r или кнопкой ниже.")
	local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetSize(200, 24)
	b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
	b:SetText("Открыть настройки DiabolicUI")
	b:SetScript("OnClick", function()
		if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
		HideUIPanel(GameMenuFrame)
		self:Toggle()
	end)
	InterfaceOptions_AddCategory(panel)
end

-------------------------------------------------------------------------------
-- module
-------------------------------------------------------------------------------
Module.OnInit = function(self)
	CharDB()
end

Module.OnEnable = function(self)
	SLASH_DIABOLICUIOPTIONS1 = "/dui"
	SLASH_DIABOLICUIOPTIONS2 = "/диабло"
	SlashCmdList["DIABOLICUIOPTIONS"] = function(msg)
		msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if msg == "lock" or msg == "unlock" then
			self:ToggleLock()
		elseif msg == "kb" or msg == "bind" then
			self:KeyBindMode()
		elseif msg == "reset" then
			local AB = Engine:GetModule("ActionBars", true)
			if AB then AB:ApplyDefaultLayout() end
		elseif msg == "errors" then
			self:PrintErrors()
		elseif msg == "errors clear" then
			self:PrintErrors(true)
		else
			self:Toggle()
		end
	end
	self:CreateBlizzardPanel()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
end

Module.OnEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
	self:ApplyAllElements()
end

Module.OnRegenEnabled = function(self)
	if pendingApply then
		pendingApply = nil
		self:ApplyAllElements()
		-- un-hide requests made in combat
		local hidden = CharDB().hidden
		for _, e in ipairs(Elements) do
			if not hidden[e.key] then ApplyElement(e, false) end
		end
	end
end
