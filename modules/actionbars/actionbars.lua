--[[
	DiabolicUI ActionBars host module (Diablo-WoW edition)

	The action buttons, paging, keybinds, pet/stance/bag bars and the micro menu
	are provided by the embedded DiabolicBars (Bartender4 4.4.2, see \bartender).
	This module only keeps what DiabolicUI is famous for:
	  * the bottom artwork (demon, angel, skull) sized for 1/2/3 bottom rows
	  * the anchor frames ("Controller: Main/Side/Pet/Stance") that the orbs,
	    quest tracker, totem bar etc. are positioned by
	  * a default Diablo-style layout for the bars (applied once, or on demand)
	  * the DiabolicUI button border skin (see skin.lua)
]]

local _, Engine = ...
local L = Engine:GetLocale()

-- HIGH priority: unitframes, tracker etc. fetch our anchor frames in their OnInit
local Module = Engine:NewModule("ActionBars", "HIGH")

-- Lua API
local pairs, ipairs, unpack, tonumber, tostring = pairs, ipairs, unpack, tonumber, tostring
local math_max, math_min, math_floor = math.max, math.min, math.floor

-- WoW API
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsXPUserDisabled = IsXPUserDisabled
local UnitLevel = UnitLevel
local GetAccountExpansionLevel = GetAccountExpansionLevel
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE

-- Version of the default layout. Bump it to push a new default layout to everybody once.
local LAYOUT_VERSION = 1

-- Bartender bar ids that make up the bottom rows, bottom-most first:
-- 1 = main bar, 6 = Blizzard "bottom left", 5 = Blizzard "bottom right"
local BOTTOM_ROW_BARS = { 1, 6, 5 }

-- pixel size of a button in the 1/2/3 row modes (identical to the old DiabolicUI bars)
local BUTTON_PX = { 50, 44, 36 }
local BUTTON_PADDING_PX = 4
local BAR_INSET = 10 -- distance from screen bottom to the lowest row

-- Bartender ButtonBar geometry (see bartender\ButtonBar.lua UpdateButtonLayout)
local BT_BUTTON = 36
local BT_MARGIN_BOTTOM = 7 -- bar frame bottom -> lowest button bottom (growVertical DOWN, 1 row)
local BT_MARGIN_TOP = 3
local BT_MARGIN_LEFT = 5

local function clamp(n, lo, hi) return math_max(lo, math_min(hi, n)) end

-- 3.3.5 has no Region:SetShown()
local function SetShown(region, show)
	if show then region:Show() else region:Hide() end
end

-------------------------------------------------------------------------------
-- Anchor widgets (kept for compatibility with the rest of DiabolicUI)
-------------------------------------------------------------------------------
local function NewAnchorWidget(name)
	local widget = Module:SetWidget(name)
	widget.GetFrame = function(self) return self.frame end
	return widget
end
NewAnchorWidget("Controller: Main")
NewAnchorWidget("Controller: Side")
NewAnchorWidget("Controller: Pet")
NewAnchorWidget("Controller: Stance")

Module.GetNumBottomRows = function(self)
	return clamp(tonumber(self.db and self.db.num_bars) or 1, 1, 3)
end

-- whether or not the XP bar is shown (not at max level, xp not disabled)
Module.IsXPEnabled = function(self)
	local max = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE]
	if IsXPUserDisabled() or UnitLevel("player") == max then
		return
	end
	return true
end

Module.CreateAnchors = function(self)
	local config = self.config.structure.controllers
	local UICenter = Engine:GetFrame()
	local mode = tostring(self:GetNumBottomRows())

	-- Main: covers the bottom button rows. Not secure on purpose:
	-- nothing secure is parented to it, it's only used as an anchor.
	local Main = CreateFrame("Frame", "DiabolicUIMainBarAnchor", UICenter)
	Main:SetFrameStrata("BACKGROUND")
	Main:SetSize(unpack(config.main.size[mode]))
	Main:SetPoint("BOTTOM", UICenter, "BOTTOM", 0, BAR_INSET)
	Main:SetAttribute("numbars", tonumber(mode)) -- read by the XP bar widget
	self:GetWidget("Controller: Main").frame = Main

	-- Side: right screen edge, where the two vertical bars live
	local Side = CreateFrame("Frame", "DiabolicUISideBarAnchor", UICenter)
	Side:SetSize(unpack(config.side.size["2"]))
	Side:SetPoint("RIGHT", UICenter, "RIGHT", 0, 0)
	Side:SetPoint("TOP", UICenter, "TOP", 0, -326)
	self:GetWidget("Controller: Side").frame = Side

	-- Pet: left of the side bars
	local Pet = CreateFrame("Frame", "DiabolicUIPetBarAnchor", UICenter)
	Pet:SetSize(unpack(config.pet.size))
	Pet:SetPoint("RIGHT", Side, "LEFT", 0, 0)
	self:GetWidget("Controller: Pet").frame = Pet

	-- Stance: above the bottom rows
	local Stance = CreateFrame("Frame", "DiabolicUIStanceBarAnchor", UICenter)
	Stance:SetSize(unpack(config.stance.size))
	Stance:SetPoint("BOTTOM", Main, "TOP", 0, 91)
	self:GetWidget("Controller: Stance").frame = Stance
end

-------------------------------------------------------------------------------
-- Artwork
-------------------------------------------------------------------------------
Module.LoadArtwork = function(self)
	local config = self.config.visuals.artwork
	local Main = self:GetWidget("Controller: Main"):GetFrame()

	local background = CreateFrame("Frame", nil, Main)
	background:SetFrameStrata("BACKGROUND")
	background:SetFrameLevel(10) -- room for the xp bar below
	background:SetAllPoints()

	local overlay = CreateFrame("Frame", nil, Main)
	overlay:SetFrameStrata("MEDIUM")
	overlay:SetFrameLevel(10) -- above the orbs, below the buttons
	overlay:SetAllPoints()

	self.artworkFrames = { background, overlay }
	self.artwork = {}

	local new = function(parent, cfg)
		local t = parent:CreateTexture(nil, "ARTWORK")
		t:Hide()
		t:SetSize(unpack(cfg.size))
		t:SetTexture(cfg.texture)
		t:SetPoint(unpack(cfg.position))
		return t
	end
	for _, i in ipairs({ "1", "2", "3" }) do
		self.artwork["bar"..i] = new(background, config[i].center)
		self.artwork["bar"..i.."left"] = new(overlay, config[i].left)
		self.artwork["bar"..i.."right"] = new(overlay, config[i].right)
		self.artwork["bar"..i.."skull"] = new(overlay, config[i].skull)
		if config[i].centerxp then
			self.artwork["bar"..i.."xp"] = new(background, config[i].centerxp)
			self.artwork["bar"..i.."skullxp"] = new(overlay, config[i].skullxp)
		end
	end
end

Module.UpdateArtwork = function(self)
	if not self.artwork then
		self:LoadArtwork()
	end
	local shown = self.db.show_artwork ~= false
	for _, f in ipairs(self.artworkFrames) do
		if shown then f:Show() else f:Hide() end
	end

	local mode = tostring(self:GetNumBottomRows())
	local xp = self:IsXPEnabled() or (ParagonXPBarFrame and ParagonXPBarFrame:IsShown())
	for _, i in ipairs({ "1", "2", "3" }) do
		local a = self.artwork
		local active = (i == mode)
		local useXP = active and xp and a["bar"..i.."xp"]
		SetShown(a["bar"..i], active and not useXP)
		SetShown(a["bar"..i.."skull"], active and not useXP)
		if a["bar"..i.."xp"] then
			SetShown(a["bar"..i.."xp"], useXP and true or false)
			SetShown(a["bar"..i.."skullxp"], useXP and true or false)
		end
		SetShown(a["bar"..i.."left"], active)
		SetShown(a["bar"..i.."right"], active)
	end
end

-------------------------------------------------------------------------------
-- Bottom rows mode (1, 2 or 3 rows)
-------------------------------------------------------------------------------
Module.SetNumBottomRows = function(self, num, applyLayout)
	if InCombatLockdown() then
		print("|cff8a0707Diabolic|r|cffffffffUI|r: нельзя менять раскладку панелей в бою.")
		return
	end
	num = clamp(tonumber(num) or 1, 1, 3)
	self.db.num_bars = num
	local Main = self:GetWidget("Controller: Main"):GetFrame()
	Main:SetSize(unpack(self.config.structure.controllers.main.size[tostring(num)]))
	Main:SetAttribute("numbars", num) -- XP bar widget listens to this
	self:UpdateArtwork()
	if applyLayout ~= false then
		self:ApplyBottomRows()
	end
end

-------------------------------------------------------------------------------
-- DiabolicBars (Bartender) layout
-------------------------------------------------------------------------------
local function GetBT()
	local BT = _G.DiabolicBars
	if BT and BT.db then return BT end
end

-- LibWindow position: SetPoint(point, UIParent, point, x/scale, y/scale)
-- so x and y are plain UIParent units.
local function SetBarPosition(bar, point, x, y, scale)
	local pos = bar.config.position
	pos.point, pos.x, pos.y, pos.scale = point, x, y, scale
	pos.growVertical, pos.growHorizontal = "DOWN", "RIGHT"
end

-- DisableBar() only touches bars that were created, make sure the setting sticks
Module.DisableActionBar = function(self, AB, id)
	AB.db.profile.actionbars[id].enabled = false
	if AB.actionbars[id] then
		AB:DisableBar(id)
	end
end

local function ApplyBar(bar)
	if not bar or bar.disabled then return end
	bar:ApplyConfig()
	if bar.UpdateButtonLayout then bar:UpdateButtonLayout() end
end

-- Places bars 1/6/5 as the bottom rows for the current mode, disables the rest of them
Module.ApplyBottomRows = function(self)
	local BT = GetBT()
	if not BT or InCombatLockdown() then return end
	local AB = BT:GetModule("ActionBars", true)
	if not AB or not AB.actionbars then return end

	local rows = self:GetNumBottomRows()
	local px = BUTTON_PX[rows]
	local scale = px / BT_BUTTON
	local pad = BUTTON_PADDING_PX / scale

	for row, id in ipairs(BOTTOM_ROW_BARS) do
		if row <= rows then
			AB:EnableBar(id)
			local bar = AB.actionbars[id]
			bar.config.rows = 1
			bar.config.buttons = 12
			bar.config.padding = pad
			local y = BAR_INSET + (row - 1) * (px + BUTTON_PADDING_PX) - BT_MARGIN_BOTTOM * scale
			SetBarPosition(bar, "BOTTOM", 0, y, scale)
			ApplyBar(bar)
		else
			self:DisableActionBar(AB, id)
		end
	end
	self:UpdateArtwork()
	self:PositionStanceBar()
end

Module.PositionStanceBar = function(self)
	local BT = GetBT()
	local mod = BT and BT:GetModule("StanceBar", true)
	if not (mod and mod.bar and mod:IsEnabled()) then return end
	local rows = self:GetNumBottomRows()
	local px = BUTTON_PX[rows]
	local top = BAR_INSET + rows * px + (rows - 1) * BUTTON_PADDING_PX
	local scale = 0.9
	mod.db.profile.padding = 2
	SetBarPosition(mod.bar, "BOTTOM", 0, top + 28 - BT_MARGIN_BOTTOM * scale, scale)
	ApplyBar(mod.bar)
end

-- Full default layout (all bars). Used on first run and from the options menu.
Module.ApplyDefaultLayout = function(self)
	local BT = GetBT()
	if not BT then return end
	if InCombatLockdown() then
		self.pendingLayout = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
		return
	end
	local AB = BT:GetModule("ActionBars", true)
	if not AB or not AB.actionbars then return end

	-- global button settings
	local p = BT.db.profile
	p.outofrange = "button"
	p.snapping = true
	p.minimapIcon = p.minimapIcon or {}
	p.minimapIcon.hide = true

	-- bar 2 is page 2 of the main bar (not shown by the default UI either)
	self:DisableActionBar(AB, 2)

	-- bottom rows (1/6/5)
	self:ApplyBottomRows()

	-- right side bars: 3 (Blizzard right) and 4 (Blizzard right 2), vertical, 36px
	local sidePad = 2
	local colW = BT_BUTTON + sidePad
	local sideTop = -326 + BT_MARGIN_TOP
	for idx, id in ipairs({ 3, 4 }) do
		AB:EnableBar(id)
		local bar = AB.actionbars[id]
		bar.config.rows = 12
		bar.config.buttons = 12
		bar.config.padding = sidePad
		-- TOPRIGHT of the bar frame = 5px right of the buttons' right edge
		local x = -20 - (idx - 1) * colW + BT_MARGIN_LEFT
		SetBarPosition(bar, "TOPRIGHT", x, sideTop, 1)
		ApplyBar(bar)
	end

	-- extra stance pages are handled by bar 1 paging, keep 7-10 off
	for id = 7, 10 do self:DisableActionBar(AB, id) end

	-- pet bar: vertical column left of the side bars (same place as the old DiabolicUI pet bar)
	local pet = BT:GetModule("PetBar", true)
	if pet and pet.bar then
		pet.db.profile.rows = 10
		pet.db.profile.padding = 2
		SetBarPosition(pet.bar, "TOPRIGHT", -20 - 2 * colW - 2 + BT_MARGIN_LEFT, sideTop, 1)
		ApplyBar(pet.bar)
	end

	-- stance bar above the bottom rows
	self:PositionStanceBar()

	-- shaman totem bar: left of the stance bar
	local totems = BT:GetModule("MultiCast", true)
	if totems and totems.bar then
		local rows = self:GetNumBottomRows()
		local top = BAR_INSET + rows * BUTTON_PX[rows] + (rows - 1) * BUTTON_PADDING_PX
		SetBarPosition(totems.bar, "BOTTOM", -220, top + 28, 1)
		ApplyBar(totems.bar)
	end

	-- micro menu: bottom right, like the default UI. Includes the shop and transmog buttons.
	local micro = BT:GetModule("MicroMenu", true)
	if micro then
		micro.db.profile.enabled = true
		if not micro:IsEnabled() then micro:Enable() end
		if micro.bar then
			micro.db.profile.padding = -3
			micro.db.profile.rows = 1
			SetBarPosition(micro.bar, "BOTTOMRIGHT", -8, 2, 0.75)
			ApplyBar(micro.bar)
		end
	end

	-- bags: right above the micro menu
	local bags = BT:GetModule("BagBar", true)
	if bags then
		bags.db.profile.enabled = true
		if not bags:IsEnabled() then bags:Enable() end
		if bags.bar then
			bags.db.profile.padding = 0
			bags.db.profile.rows = 1
			SetBarPosition(bags.bar, "BOTTOMRIGHT", -8, 46, 0.8)
			ApplyBar(bags.bar)
		end
	end

	-- XP/Rep: DiabolicUI has its own XP bar (and the Diablo-WoW paragon bar), turn off Bartender's
	for _, name in ipairs({ "XPBar", "RepBar" }) do
		local m = BT:GetModule(name, true)
		if m and m.db and m.db.profile.enabled then
			m:ToggleModule(nil, false)
		end
	end

	p.diabolicLayout = LAYOUT_VERSION
	self:RaiseBars()
	print("|cff8a0707Diabolic|r|cffffffffUI|r: стандартная раскладка панелей применена. /dui — настройки.")
end

-- Micro menu and bags sit on top of the angel artwork, so keep them above it
Module.RaiseBars = function(self)
	local BT = GetBT()
	if not BT then return end
	for _, name in ipairs({ "MicroMenu", "BagBar" }) do
		local m = BT:GetModule(name, true)
		if m and m.bar then
			m.bar:SetFrameStrata("HIGH")
			if m.bar.buttons then
				for _, b in pairs(m.bar.buttons) do
					if b.SetFrameStrata then b:SetFrameStrata("HIGH") end
				end
			end
		end
	end
end

Module.OnRegenEnabled = function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
	if self.pendingLayout then
		self.pendingLayout = nil
		self:ApplyDefaultLayout()
	end
end

-- Called once the embedded DiabolicBars are fully up
Module.OnBarsReady = function(self)
	local BT = GetBT()
	if not BT then
		return
	end
	if (BT.db.profile.diabolicLayout or 0) < LAYOUT_VERSION then
		self:ApplyDefaultLayout()
	else
		self:RaiseBars()
	end
	self:UpdateArtwork()

	-- Talents/vehicles reparent the micro buttons back to the hidden Blizzard bar
	local micro = BT:GetModule("MicroMenu", true)
	if micro and MainMenuBar_ToPlayerArt then
		hooksecurefunc("MainMenuBar_ToPlayerArt", function()
			if micro:IsEnabled() and micro.RestoreButtons then
				micro:RestoreButtons()
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- Diablo-WoW: paragon bar lives in MainMenuBar, which is hidden by this UI.
-- Move it to the DiabolicUI XP bar slot.
-------------------------------------------------------------------------------
Module.AdoptParagonBar = function(self)
	local frame = _G.ParagonXPBarFrame
	if not frame or self.paragonAdopted then return end
	self.paragonAdopted = true

	local function place()
		local Main = self:GetWidget("Controller: Main"):GetFrame()
		local cfg = self.config.structure.controllers.xp
		local w = cfg.size[tostring(self:GetNumBottomRows())][1]
		frame:SetParent(Main)
		frame:ClearAllPoints()
		frame:SetPoint(unpack(cfg.position))
		frame:SetWidth(w)
		local bar = _G.ParagonXPBar
		if bar then bar:SetWidth(w) end
		frame:SetFrameStrata("BACKGROUND")
		self:UpdateArtwork()
	end
	place()
	hooksecurefunc(frame, "Show", place)
	frame:HookScript("OnHide", function() self:UpdateArtwork() end)
	self:GetWidget("Controller: Main"):GetFrame():HookScript("OnAttributeChanged", function(_, name)
		if name == "numbars" then place() end
	end)
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------
Module.OnInit = function(self, event, ...)
	self.config = self:GetStaticConfig("ActionBars") -- static config
	self.db = self:GetConfig("ActionBars", "character") -- per character settings

	self:CreateAnchors()
	self:GetWidget("Bar: XP"):Enable()
end

Module.OnEnable = function(self, event, ...)
	-- hide the Blizzard bars (DiabolicBars also does this, both are harmless together)
	local BlizzardUI = self:GetHandler("BlizzardUI")
	BlizzardUI:GetElement("ActionBars"):Disable()

	-- required at least once, or the pet bar/pet frame fail after a /reload
	SetActionBarToggles(nil, nil, nil, nil, nil)

	self:UpdateArtwork()
	for _, e in ipairs({ "PLAYER_ALIVE", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "PLAYER_FLAGS_CHANGED",
		"DISABLE_XP_GAIN", "ENABLE_XP_GAIN", "PLAYER_UPDATE_RESTING" }) do
		self:RegisterEvent(e, "UpdateArtwork")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
end

Module.OnEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
	self:AdoptParagonBar()
	self:OnBarsReady()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateArtwork")
end

-- slash helpers used by the options module
Module.OpenBarOptions = function(self)
	local BT = GetBT()
	if BT and BT.ChatCommand then BT:ChatCommand("") end
end

Module.ToggleBarLock = function(self)
	local BT = GetBT()
	if BT and BT.ToggleLock then BT:ToggleLock() end
end
