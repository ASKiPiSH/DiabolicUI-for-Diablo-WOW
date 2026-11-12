--[[
	DiabolicUI options (Diablo-WoW)
	Everything lives in one window: the DiabolicBars (Bartender4) options, with the
	DiabolicUI pages added after the bar pages.

	/dui                 open the options (bars page)
	/dui lock            unlock/lock bars and movable elements
	/dui kb              keybinding mode (hover a button and press a key)
	/dui reset           default action bar layout
	/dui errors [clear]  print/clear the error log
	Also: Esc > Interface > AddOns > DiabolicUI.
]]
local ADDON, Engine = ...
local Module = Engine:NewModule("Options", "LOW")

local pairs, ipairs, type, select, tostring = pairs, ipairs, type, select, tostring
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local PREFIX = "|cff8a0707Diabolic|r|cffffffffUI|r: "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

-------------------------------------------------------------------------------
-- saved settings
-------------------------------------------------------------------------------
local function CharDB()
	DiabolicUI_CharDB = DiabolicUI_CharDB or {}
	DiabolicUI_CharDB.hidden = DiabolicUI_CharDB.hidden or {}
	return DiabolicUI_CharDB
end

local function OptDB()
	DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or {}
	return DiabolicUI_OptionsDB
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
		return Collect(m and m.frame)
	end },
	{ key = "minimapbuttons", title = "Кнопки у миникарты", get = function()
		local m = Engine:GetModule("MinimapButtons", true)
		return Collect(m and m.bar)
	end },
	{ key = "xp", title = "Полоска опыта / парагона", get = function()
		return Collect(W("ActionBars", "Bar: XP"), _G.ParagonXPBarFrame)
	end },
	{ key = "buffs", title = "Баффы и дебаффы игрока", get = function()
		return Collect(BuffFrame, TemporaryEnchantFrame, ConsolidatedBuffs)
	end },
	{ key = "tracker", title = "Задачи", get = function() return Collect(WatchFrame) end },
	{ key = "chat", title = "Окна чата", get = function()
		local t = {}
		for i = 1, (NUM_CHAT_WINDOWS or 10) do
			for _, s in ipairs({ "", "Tab", "ButtonFrame" }) do
				local f = _G["ChatFrame" .. i .. s]
				if f then t[#t + 1] = f end
			end
		end
		for _, n in ipairs({ "GeneralDockManager", "ChatFrameMenuButton" }) do
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
-- actions
-------------------------------------------------------------------------------
local function AB() return Engine:GetModule("ActionBars", true) end
local function NP() return Engine:GetModule("NamePlates", true) end
local function MV() return Engine:GetModule("Movers", true) end

Module.ToggleLock = function(self)
	if InCombatLockdown() then return Print("нельзя в бою.") end
	local BT = _G.DiabolicBars
	if BT and BT.ToggleLock then BT:ToggleLock() end
	local ACD = LibStub("AceConfigDialog-3.0", true)
	if ACD then ACD:Close("DiabolicBars") end
end

Module.KeyBindMode = function(self)
	local KB = LibStub("LibKeyBound-1.0", true)
	if KB then
		local ACD = LibStub("AceConfigDialog-3.0", true)
		if ACD then ACD:Close("DiabolicBars") end
		KB:Toggle()
	end
end

Module.Open = function(self, group)
	if InCombatLockdown() then return Print("настройки недоступны в бою.") end
	local ACD = LibStub("AceConfigDialog-3.0", true)
	if not ACD then return end
	ACD:Open("DiabolicBars")
	ACD:SelectGroup("DiabolicBars", group or "bars")
end

Module.PrintErrors = function(self, clear)
	local log = DiabolicUI_GetErrorLog and DiabolicUI_GetErrorLog() or {}
	if clear then
		wipe(log)
		return Print("журнал ошибок очищен.")
	end
	if #log == 0 then return Print("ошибок нет.") end
	Print(("ошибок: %d (полностью — в WTF\\...\\SavedVariables\\DiabolicUI.lua)"):format(#log))
	for i = math.max(1, #log - 9), #log do
		local e = log[i]
		DEFAULT_CHAT_FRAME:AddMessage(("|cffff5555%d.|r [x%d] %s"):format(i, e.count or 1, e.msg))
	end
end

-------------------------------------------------------------------------------
-- AceConfig pages (added to the DiabolicBars options window)
-------------------------------------------------------------------------------
local function BuildOptions()
	local args = {}

	-- Interface ---------------------------------------------------------------
	args.dui_general = {
		type = "group", order = 30, name = "Интерфейс",
		args = {
			about = { type = "description", order = 0, fontSize = "medium",
				name = "Общие настройки DiabolicUI. Панели команд настраиваются в разделе «Панели» выше.\n" },
			uiScale = {
				type = "range", order = 1, width = "double",
				name = "Размер интерфейса DiabolicUI",
				desc = "Размер всех элементов DiabolicUI (панели, сферы, цель, миникарта). Не зависит от масштаба в настройках видео.",
				min = .5, max = 1.5, step = .05, isPercent = true,
				get = function() return tonumber(OptDB().uiScale) or 1 end,
				set = function(_, v)
					if InCombatLockdown() then return Print("нельзя в бою.") end
					OptDB().uiScale = v
					Engine:UpdateScale()
				end,
			},
			unlock = {
				type = "execute", order = 2,
				name = "Перемещение элементов",
				desc = "Разблокировать панели и элементы (миникарта, задачи, полоса заклинаний, баффы, цель, фокус). Перетаскивайте зелёные рамки; правый клик возвращает элемент на место.",
				func = function() Module:ToggleLock() end,
			},
			keybind = {
				type = "execute", order = 3,
				name = "Назначить клавиши",
				desc = "Наведите курсор на кнопку и нажмите клавишу.",
				func = function() Module:KeyBindMode() end,
			},
			hdr1 = { type = "header", order = 10, name = "Нижние панели" },
			rows = {
				type = "select", order = 11,
				name = "Рядов кнопок внизу",
				desc = "Подложка (демон, ангел, череп) подстраивается под 1, 2 или 3 ряда.",
				values = { [1] = "1 ряд (крупные кнопки)", [2] = "2 ряда", [3] = "3 ряда" },
				get = function() local m = AB(); return m and m:GetNumBottomRows() or 1 end,
				set = function(_, v) local m = AB(); if m then m:SetNumBottomRows(v) end end,
			},
			artwork = {
				type = "toggle", order = 12,
				name = "Подложка (демон, ангел, череп)",
				get = function() local m = AB(); return m and m.db.show_artwork ~= false end,
				set = function(_, v) local m = AB(); if m then m.db.show_artwork = v; m:UpdateArtwork() end end,
			},
			resetLayout = {
				type = "execute", order = 13,
				name = "Раскладка по умолчанию",
				desc = "Вернуть все панели команд на места по умолчанию.",
				confirm = true, confirmText = "Вернуть все панели на места по умолчанию?",
				func = function() local m = AB(); if m then m:ApplyDefaultLayout() end end,
			},
			resetMovers = {
				type = "execute", order = 14,
				name = "Сбросить элементы",
				desc = "Вернуть миникарту, задачи, полосу заклинаний, баффы, цель и фокус на места и к исходному размеру.",
				confirm = true, confirmText = "Вернуть элементы на места по умолчанию?",
				func = function() local m = MV(); if m then m:ResetAll() end end,
			},
		},
	}

	-- Elements -----------------------------------------------------------------
	local el = {
		about = { type = "description", order = 0, fontSize = "medium",
			name = "Снимите галочку, чтобы скрыть элемент. Размер — ползунком рядом. Переместить: «Интерфейс» → «Перемещение элементов».\n" },
	}
	for i, e in ipairs(Elements) do
		el[e.key] = {
			type = "toggle", order = i * 2, width = "double",
			name = e.title,
			get = function() return not CharDB().hidden[e.key] end,
			set = function(_, v) Module:SetElementHidden(e.key, not v) end,
		}
	end
	local mv = MV()
	if mv and mv.List then
		el.hdrSize = { type = "header", order = 100, name = "Размер" }
		for i, m in ipairs(mv.List) do
			el["size_" .. m.key] = {
				type = "range", order = 100 + i,
				name = m.title,
				min = .5, max = 2, step = .05, isPercent = true,
				get = function() return MV():GetScale(m.key) end,
				set = function(_, v) MV():SetScale(m.key, v) end,
			}
		end
	end
	args.dui_elements = { type = "group", order = 31, name = "Элементы", args = el }

	-- Bars above the units -------------------------------------------------------
	args.dui_plates = {
		type = "group", order = 32, name = "Полоски над головой",
		args = {
			about = { type = "description", order = 0, fontSize = "medium",
				name = "Полоски здоровья над моделями в стиле DiabolicUI. Боссы, элиты и редкие противники всегда показываются и сверху экрана.\n" },
			mode = {
				type = "select", order = 1, width = "double",
				name = "Цель показывается",
				values = {
					plates = "Над моделью (боссы, элиты, редкие — сверху)",
					enemies = "Над моделью только обычные враги",
					top = "Только сверху экрана (как раньше)",
				},
				get = function() local m = NP(); return m and m.db.targetMode or "plates" end,
				set = function(_, v) local m = NP(); if m then m:SetEnemyMode(v) end end,
			},
			friendly = {
				type = "toggle", order = 2, width = "double",
				name = "Полоски над союзниками и игроками",
				desc = "Включает полоски над дружественными персонажами и НИП.",
				get = function() local m = NP(); return m and m.db.showFriendlyPlates end,
				set = function(_, v) local m = NP(); if m then m.db.showFriendlyPlates = v; m:ApplyPlateCVars(); m:UpdateTopTargetFrame() end end,
			},
			scale = {
				type = "range", order = 3, width = "double",
				name = "Размер полосок",
				min = .4, max = 1.5, step = .05, isPercent = true,
				get = function() local m = NP(); return m and m.db.scale or .8 end,
				set = function(_, v) local m = NP(); if m then m.db.scale = v; m:UpdateScale() end end,
			},
			healthText = {
				type = "toggle", order = 4,
				name = "Здоровье числом",
				get = function() local m = NP(); return m and m.db.showHealthText end,
				set = function(_, v) local m = NP(); if m then m.db.showHealthText = v end end,
			},
			debuffs = {
				type = "toggle", order = 5,
				name = "Мои дебаффы над целью",
				get = function() local m = NP(); return m and m.db.showDebuffs end,
				set = function(_, v) local m = NP(); if m then m.db.showDebuffs = v end end,
			},
		},
	}

	-- Error log -----------------------------------------------------------------
	args.dui_errors = {
		type = "group", order = 33, name = "Журнал ошибок",
		args = {
			list = {
				type = "description", order = 1, fontSize = "small",
				name = function()
					local log = DiabolicUI_GetErrorLog and DiabolicUI_GetErrorLog() or {}
					if #log == 0 then return "Ошибок нет." end
					local out = {}
					for i = #log, math.max(1, #log - 14), -1 do
						local e = log[i]
						out[#out + 1] = ("|cffff5555[x%d]|r %s"):format(e.count or 1, e.msg)
					end
					return table.concat(out, "\n\n")
				end,
			},
			clear = {
				type = "execute", order = 2, name = "Очистить",
				func = function() Module:PrintErrors(true); LibStub("AceConfigRegistry-3.0"):NotifyChange("DiabolicBars") end,
			},
		},
	}
	return args
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
	d:SetText("Все настройки интерфейса и панелей открываются командой |cffffd100/dui|r или кнопкой ниже.")
	local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetSize(220, 24)
	b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
	b:SetText("Открыть настройки DiabolicUI")
	b:SetScript("OnClick", function()
		if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
		HideUIPanel(GameMenuFrame)
		self:Open()
	end)
	InterfaceOptions_AddCategory(panel)
end

-------------------------------------------------------------------------------
-- module
-------------------------------------------------------------------------------
Module.OnInit = function(self)
	CharDB()
	-- the DiabolicBars options table is built lazily, add our pages when it is
	local BT = _G.DiabolicBars
	if BT then
		BT.OnOptionsCreated = function(_, options)
			for k, v in pairs(BuildOptions()) do
				options.args[k] = v
			end
		end
	end
end

Module.OnEnable = function(self)
	SLASH_DIABOLICUIOPTIONS1 = "/dui"
	SLASH_DIABOLICUIOPTIONS2 = "/диабло"
	SlashCmdList["DIABOLICUIOPTIONS"] = function(msg)
		msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if msg == "lock" or msg == "unlock" or msg == "move" then
			self:ToggleLock()
		elseif msg == "kb" or msg == "bind" then
			self:KeyBindMode()
		elseif msg == "reset" then
			local m = AB(); if m then m:ApplyDefaultLayout() end
		elseif msg == "errors" then
			self:PrintErrors()
		elseif msg == "errors clear" then
			self:PrintErrors(true)
		else
			self:Open()
		end
	end
	self:CreateBlizzardPanel()
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")

	-- apply hidden elements once everything exists
	local elapsed, done = 0, 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(f, e)
		elapsed = elapsed + e
		if elapsed < 1 then return end
		elapsed = 0
		done = done + 1
		if not InCombatLockdown() then
			self:ApplyAllElements()
		end
		if done >= 3 then f:SetScript("OnUpdate", nil) end
	end)
end

Module.OnRegenEnabled = function(self)
	if pendingApply then
		pendingApply = nil
		local hidden = CharDB().hidden
		for _, e in ipairs(Elements) do ApplyElement(e, hidden[e.key] and true or false) end
	end
end
