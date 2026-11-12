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
local LAYOUT_VERSION = 2

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

-- A Bartender bar frame is a 1x1 anchor that sits at the TOPLEFT corner of its
-- button grid (buttons grow RIGHT and DOWN from it), offset by (5,-3) bar units.
-- These helpers place the *grid* where we want it.
--   point        : anchor point on the parent (DiabolicUI frame), e.g. "BOTTOM", "TOPRIGHT"
--   left, top    : grid top-left corner, relative to that point, in parent units
--   scale        : bar scale
local function PlaceGrid(bar, point, left, top, scale)
	local hoff = bar.hpad_offset or 0
	local voff = bar.vpad_offset or 0
	local pos = bar.config.position
	pos.point = point
	pos.x = left - (BT_MARGIN_LEFT - hoff) * scale
	pos.y = top + (BT_MARGIN_TOP + voff) * scale
	pos.scale = scale
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

-- height of the bottom rows block for the current mode
Module.GetBottomRowsTop = function(self)
	local rows = self:GetNumBottomRows()
	return BAR_INSET + rows * BUTTON_PX[rows] + (rows - 1) * BUTTON_PADDING_PX
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
	local width = 12 * px + 11 * BUTTON_PADDING_PX

	for row, id in ipairs(BOTTOM_ROW_BARS) do
		if row <= rows then
			AB:EnableBar(id)
			local bar = AB.actionbars[id]
			bar.config.rows = 1
			bar.config.buttons = 12
			bar.config.padding = pad
			local top = BAR_INSET + (row - 1) * (px + BUTTON_PADDING_PX) + px
			PlaceGrid(bar, "BOTTOM", -width / 2, top, scale)
			ApplyBar(bar)
		else
			self:DisableActionBar(AB, id)
		end
	end
	self:UpdateArtwork()
	self:PositionStanceBar()
	self:PositionTotemBar()
end

Module.PositionStanceBar = function(self)
	local BT = GetBT()
	local mod = BT and BT:GetModule("StanceBar", true)
	if not (mod and mod.bar and mod:IsEnabled()) then return end
	local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
	if n < 1 then n = 1 end
	local scale = 1
	local pad = 2
	mod.db.profile.padding = pad
	mod.db.profile.rows = 1
	local width = (n * 30 + (n - 1) * pad) * scale
	PlaceGrid(mod.bar, "BOTTOM", -width / 2, self:GetBottomRowsTop() + 34 + 30 * scale, scale)
	ApplyBar(mod.bar)
end

Module.PositionTotemBar = function(self)
	local BT = GetBT()
	local totems = BT and BT:GetModule("MultiCast", true)
	if not (totems and totems.bar and totems:IsEnabled()) then return end
	-- 1x1 anchor, the Blizzard totem frame (230x40) hangs from its TOPLEFT (+3,+1)
	local rows = self:GetNumBottomRows()
	local left = -(12 * BUTTON_PX[rows] + 11 * BUTTON_PADDING_PX) / 2
	local top = self:GetBottomRowsTop() + 34 + 40
	local pos = totems.bar.config.position
	pos.point, pos.x, pos.y, pos.scale = "BOTTOM", left - 3, top - 1, 1
	pos.growVertical, pos.growHorizontal = "DOWN", "RIGHT"
	ApplyBar(totems.bar)
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

	local p = BT.db.profile
	p.outofrange = "button"
	p.snapping = true
	p.minimapIcon = p.minimapIcon or {}
	p.minimapIcon.hide = true

	-- bar 2 is page 2 of the main bar (not shown by the default UI either)
	self:DisableActionBar(AB, 2)
	for id = 7, 10 do self:DisableActionBar(AB, id) end

	-- bottom rows (1/6/5), stance and totem bars above them
	self:ApplyBottomRows()

	-- right side bars: 3 and 4, vertical columns at the right screen edge
	local sidePad = 2
	local right = -20
	for idx, id in ipairs({ 3, 4 }) do
		AB:EnableBar(id)
		local bar = AB.actionbars[id]
		bar.config.rows = 12
		bar.config.buttons = 12
		bar.config.padding = sidePad
		local left = right - idx * BT_BUTTON - (idx - 1) * sidePad
		PlaceGrid(bar, "TOPRIGHT", left, -326, 1)
		ApplyBar(bar)
	end

	-- pet bar: column left of the side bars
	local pet = BT:GetModule("PetBar", true)
	if pet then
		pet.db.profile.enabled = true
		if not pet:IsEnabled() then pet:Enable() end
		if pet.bar then
			pet.db.profile.rows = 10
			pet.db.profile.padding = 2
			local left = right - 2 * BT_BUTTON - sidePad - 6 - 30
			PlaceGrid(pet.bar, "TOPRIGHT", left, -326, 1)
			ApplyBar(pet.bar)
		end
	end

	-- micro menu: bottom right corner, like the default UI (Shop and Transmog included)
	local micro = BT:GetModule("MicroMenu", true)
	local microTop = 0
	if micro then
		micro.db.profile.enabled = true
		if not micro:IsEnabled() then micro:Enable() end
		if micro.bar then
			local m = 1
			local n = micro.bar.buttons and #micro.bar.buttons or 12
			micro.db.profile.padding = -3
			micro.db.profile.rows = 1
			local width = (n * (28 - 3) + 3) * m
			-- micro buttons are 58 tall with ~21 transparent px on top
			microTop = 58 * m
			PlaceGrid(micro.bar, "BOTTOMRIGHT", -8 - width, microTop - 2, m)
			ApplyBar(micro.bar)
		end
	end

	-- bags: right above the micro menu
	local bags = BT:GetModule("BagBar", true)
	if bags then
		bags.db.profile.enabled = true
		if not bags:IsEnabled() then bags:Enable() end
		if bags.bar then
			local b = 1
			local n = bags.bar.buttons and #bags.bar.buttons or 5
			bags.db.profile.padding = 2
			bags.db.profile.rows = 1
			local width = (n * 32 - 2) * b
			PlaceGrid(bags.bar, "BOTTOMRIGHT", -10 - width, microTop - 18 + 4 + 30 * b, b)
			ApplyBar(bags.bar)
		end
	end

	-- XP/Rep: DiabolicUI has its own XP bar (and the Diablo-WoW paragon bar)
	for _, name in ipairs({ "XPBar", "RepBar" }) do
		local m = BT:GetModule(name, true)
		if m and m.db and m.db.profile.enabled then
			m:ToggleModule(nil, false)
		end
	end

	p.diabolicLayout = LAYOUT_VERSION
	self:RaiseBars()
	print("|cff8a0707Diabolic|r|cffffffffUI|r: раскладка панелей по умолчанию применена. Настройки: /dui")
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
	self:WaitForBars()
end

Module.OnEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateArtwork")
end

-- On 3.3.5 the DiabolicUI engine may start after PLAYER_ENTERING_WORLD, so wait
-- actively until the player is in the world and the embedded bars exist.
Module.WaitForBars = function(self)
	local waiter = CreateFrame("Frame")
	local elapsed = 0
	waiter:SetScript("OnUpdate", function(f, e)
		elapsed = elapsed + e
		if elapsed < .25 then return end
		elapsed = 0
		local BT = GetBT()
		local AB = BT and BT:GetModule("ActionBars", true)
		if IsLoggedIn() and AB and AB.actionbars and AB.actionbars[1] then
			f:SetScript("OnUpdate", nil)
			self:AdoptParagonBar()
			self:OnBarsReady()
		end
	end)
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
