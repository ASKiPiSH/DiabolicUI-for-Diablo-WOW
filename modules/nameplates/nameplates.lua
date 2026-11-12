--[[
	DiabolicUI nameplates (Diablo-WoW, WotLK 3.3.5a)

	Health bars above the units' heads, in the DiabolicUI style (114x15 frame set).
	With the "enemy bars above the model" option the big top target frame is
	hidden for ordinary enemies (bosses, elites, rares and players keep it), and
	the enemy target is shown here instead: highlighted frame, cast bar and your
	debuffs on it.

	3.3.5 plates are nameless children of WorldFrame:
	  children: healthBar, castBar
	  regions : threatGlow, border, castBorder, castShield, spellIcon, highlight,
	            name, level, bossIcon, raidIcon, eliteIcon
]]
local ADDON, Engine = ...
local Module = Engine:NewModule("NamePlates")
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)

-- Lua API
local select, pairs, ipairs, floor, tonumber = select, pairs, ipairs, math.floor, tonumber
local wipe = table.wipe

-- WoW API
local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local UnitExists = UnitExists
local UnitName = UnitName
local UnitDebuff = UnitDebuff
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local GetTime = GetTime

local PLATE_BORDER = [[Interface\Tooltips\Nameplate-Border]]
local BAR_TEXTURE = path .. [[statusbars\DiabolicUI_StatusBar_512x64_Dark_Warcraft.tga]]
local T = path .. [[textures\]]
local TEX = {
	backdrop = T .. "DiabolicUI_Target_114x15_Backdrop.tga",
	border = T .. "DiabolicUI_Target_114x15_Border.tga",
	highlight = T .. "DiabolicUI_Target_114x15_Highlight.tga",
	glow = T .. "DiabolicUI_Target_114x15_Glow.tga",
	raidicons = T .. "DiabolicUI_Texture_256x256_RaidTargetingIcons.tga",
}

-- geometry (the 114x15 textures are 256x64, health bar sits at 71,25 inside)
local W, H = 114, 15
local CAST_H = 8
local ART_W, ART_H, ART_X, ART_Y = 256, 64, -71, 25

local plates = {}      -- [blizzPlate] = our plate
local numChildren = -1

local defaults = {
	enabled = true,
	-- "plates": target shown above the model (bosses, elites and rares keep the top frame)
	-- "enemies": only ordinary enemies above the model, everything else on top
	-- "top": classic top frame only
	targetMode = "plates",
	showEnemyPlates = true,   -- turn the client enemy nameplates on at login
	showFriendlyPlates = true, -- friendly players/NPCs get bars above the model too
	showDebuffs = true,
	showHealthText = true,
	scale = .8,               -- 1 = the size the DiabolicUI textures were drawn for
}

local function ShortValue(v)
	if not v then return "" end
	if v >= 1e6 then return ("%.1fm"):format(v / 1e6) end
	if v >= 1e4 then return ("%.1fk"):format(v / 1e3) end
	return tostring(floor(v + .5))
end

-- pixel-perfect scale for the plate art, times the user's size setting
local function PlateScale(db)
	local res = ({ GetScreenResolutions() })[GetCurrentResolution()]
	local h = res and tonumber(res:match("%d+x(%d+)")) or 768
	return (768 / h) * (db.scale or 1)
end

-------------------------------------------------------------------------------
-- helpers
-------------------------------------------------------------------------------
local function IsPlate(frame)
	if frame:GetName() then return end
	local overlay = select(2, frame:GetRegions())
	return overlay and overlay.GetObjectType and overlay:GetObjectType() == "Texture" and overlay:GetTexture() == PLATE_BORDER
end

local function Kill(region)
	if not region then return end
	if region.SetTexture then region:SetTexture(nil) end
	if region.SetAlpha then region:SetAlpha(0) end
end

local function NewArt(parent, layer, texture)
	local t = parent:CreateTexture(nil, layer)
	t:SetSize(ART_W, ART_H)
	t:SetTexture(texture)
	return t
end

-------------------------------------------------------------------------------
-- plate construction
-------------------------------------------------------------------------------
local function UpdateCastBar(plate)
	local cb = plate.blizz.castBar
	if cb:IsShown() then
		plate.CastBack:Show()
		plate.SpellIconFrame:Show()
		local shielded = plate.blizz.castShield and plate.blizz.castShield:IsShown()
		plate.CastBorder:SetVertexColor(shielded and .6 or 1, shielded and .6 or 1, shielded and .6 or 1)
	else
		plate.CastBack:Hide()
		plate.SpellIconFrame:Hide()
	end
end

local function CreatePlate(blizz)
	local healthBar, castBar = blizz:GetChildren()
	local threat, border, castBorder, castShield, spellIcon, highlight, name, level, bossIcon, raidIcon, eliteIcon = blizz:GetRegions()

	local plate = CreateFrame("Frame", nil, blizz)
	plate:SetAllPoints()
	plate:SetFrameLevel(blizz:GetFrameLevel())
	plate.blizz = {
		frame = blizz, healthBar = healthBar, castBar = castBar, threat = threat,
		castShield = castShield, spellIcon = spellIcon, highlight = highlight,
		name = name, level = level, bossIcon = bossIcon, raidIcon = raidIcon, eliteIcon = eliteIcon
	}

	-- hide the Blizzard art (keep the regions alive, we read their state)
	Kill(border); Kill(castBorder); Kill(highlight); Kill(eliteIcon)
	threat:SetTexCoord(0, 0, 0, 0)
	name:Hide(); name:SetAlpha(0)
	level:SetAlpha(0)
	bossIcon:SetAlpha(0)

	-- health bar: the client keeps updating its value and reaction color
	healthBar:ClearAllPoints()
	healthBar:SetPoint("CENTER", blizz, "CENTER", 0, 4)
	healthBar:SetSize(W, H)
	healthBar:SetStatusBarTexture(BAR_TEXTURE)
	healthBar:SetScale(PlateScale(Module.db))

	local art = CreateFrame("Frame", nil, healthBar)
	art:SetAllPoints()
	art:SetFrameLevel(healthBar:GetFrameLevel() + 2)

	local back = healthBar:CreateTexture(nil, "BACKGROUND")
	back:SetSize(ART_W, ART_H)
	back:SetPoint("TOPLEFT", healthBar, "TOPLEFT", ART_X, ART_Y)
	back:SetTexture(TEX.backdrop)

	plate.Border = NewArt(art, "ARTWORK", TEX.border)
	plate.Border:SetPoint("TOPLEFT", healthBar, "TOPLEFT", ART_X, ART_Y)
	plate.Highlight = NewArt(art, "OVERLAY", TEX.highlight)
	plate.Highlight:SetPoint("TOPLEFT", healthBar, "TOPLEFT", ART_X, ART_Y)
	plate.Highlight:Hide()
	plate.Glow = NewArt(healthBar, "BACKGROUND", TEX.glow)
	plate.Glow:SetPoint("TOPLEFT", healthBar, "TOPLEFT", ART_X, ART_Y)
	plate.Glow:Hide()

	plate.Name = art:CreateFontString(nil, "OVERLAY")
	plate.Name:SetFontObject(_G.DiabolicUnitFrameNormal or GameFontNormalSmall)
	plate.Name:SetPoint("BOTTOM", healthBar, "TOP", 0, 8)
	plate.Name:SetWidth(ART_W + 60)
	plate.Name:SetWordWrap(false)

	plate.HealthText = art:CreateFontString(nil, "OVERLAY")
	plate.HealthText:SetFontObject(_G.DiabolicUnitFrameNumberNormal or NumberFontNormalSmall)
	plate.HealthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
	plate.HealthText:SetTextColor(.94, .94, .94)
	healthBar:HookScript("OnValueChanged", function() Module:UpdateHealthText(plate) end)

	-- power bar, only for the current target (3.3.5 plates have no unit token)
	plate.Power = CreateFrame("StatusBar", nil, healthBar)
	plate.Power:SetSize(W - 8, 4)
	plate.Power:SetPoint("TOP", healthBar, "BOTTOM", 0, -2)
	plate.Power:SetStatusBarTexture(BAR_TEXTURE)
	plate.Power:SetFrameLevel(healthBar:GetFrameLevel() + 1)
	plate.Power.bg = plate.Power:CreateTexture(nil, "BACKGROUND")
	plate.Power.bg:SetAllPoints()
	plate.Power.bg:SetTexture(0, 0, 0, .8)
	plate.Power.Text = art:CreateFontString(nil, "OVERLAY")
	plate.Power.Text:SetFontObject(_G.DiabolicUnitFrameNumberNormal or NumberFontNormalSmall)
	plate.Power.Text:SetPoint("TOP", plate.Power, "BOTTOM", 0, -2)
	plate.Power:Hide()

	plate.Level = art:CreateFontString(nil, "OVERLAY")
	plate.Level:SetFontObject(_G.DiabolicUnitFrameNumberNormal or NumberFontNormalSmall)
	plate.Level:SetPoint("LEFT", healthBar, "RIGHT", 6, 0)

	plate.Skull = art:CreateTexture(nil, "OVERLAY")
	plate.Skull:SetSize(16, 16)
	plate.Skull:SetPoint("LEFT", healthBar, "RIGHT", 4, 0)
	plate.Skull:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Skull]])
	plate.Skull:Hide()

	plate.Elite = art:CreateFontString(nil, "OVERLAY")
	plate.Elite:SetFontObject(_G.DiabolicUnitFrameNormal or GameFontNormalSmall)
	plate.Elite:SetPoint("RIGHT", healthBar, "LEFT", -4, 0)

	raidIcon:ClearAllPoints()
	raidIcon:SetSize(24 * PlateScale(Module.db), 24 * PlateScale(Module.db))
	raidIcon:SetPoint("BOTTOM", plate.Name, "TOP", 0, 2)

	-- cast bar under the health bar
	castBar:ClearAllPoints()
	castBar:SetScale(PlateScale(Module.db))
	castBar:SetPoint("TOP", healthBar, "BOTTOM", 0, -18)
	castBar:SetSize(W, CAST_H)
	castBar:SetStatusBarTexture(BAR_TEXTURE)
	plate.CastBack = castBar:CreateTexture(nil, "BACKGROUND")
	plate.CastBack:SetPoint("TOPLEFT", -1, 1)
	plate.CastBack:SetPoint("BOTTOMRIGHT", 1, -1)
	plate.CastBack:SetTexture(0, 0, 0, .75)
	plate.CastBorder = plate.CastBack

	plate.SpellIconFrame = CreateFrame("Frame", nil, castBar)
	plate.SpellIconFrame:SetSize(H + CAST_H + 10, H + CAST_H + 10)
	plate.SpellIconFrame:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMLEFT", -6, 0)
	plate.SpellIconFrame:SetBackdrop({ edgeFile = T .. "DiabolicUI_GlowBorder_128x16.tga", edgeSize = 4, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
	plate.SpellIconFrame:SetBackdropBorderColor(.6, .5, .3, 1)
	spellIcon:ClearAllPoints()
	spellIcon:SetPoint("TOPLEFT", plate.SpellIconFrame, "TOPLEFT", 3, -3)
	spellIcon:SetPoint("BOTTOMRIGHT", plate.SpellIconFrame, "BOTTOMRIGHT", -3, 3)
	spellIcon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	castBar:HookScript("OnShow", function() UpdateCastBar(plate) end)
	castBar:HookScript("OnHide", function() UpdateCastBar(plate) end)
	castBar:HookScript("OnValueChanged", function() UpdateCastBar(plate) end)

	-- target debuffs (only on the current target, 3.3.5 has no unit tokens for plates)
	plate.Debuffs = {}

	blizz:HookScript("OnShow", function() Module:OnPlateShow(plate) end)
	blizz:HookScript("OnHide", function() plate.isTarget = nil; Module:HideDebuffs(plate) end)

	plates[blizz] = plate
	Module:OnPlateShow(plate)
	return plate
end

-------------------------------------------------------------------------------
-- updates
-------------------------------------------------------------------------------
Module.OnPlateShow = function(self, plate)
	local b = plate.blizz
	plate.Name:SetText(b.name:GetText())
	local lvl = b.level:GetText()
	if b.bossIcon:IsShown() then
		plate.Level:SetText("")
		plate.Skull:Show()
	else
		plate.Skull:Hide()
		plate.Level:SetText(lvl or "")
		plate.Level:SetTextColor(b.level:GetTextColor())
	end
	plate.Elite:SetText((b.eliteIcon and b.eliteIcon:IsShown()) and "|cffffd100+|r" or "")
	self:UpdateHealthText(plate)
	UpdateCastBar(plate)
end

Module.UpdateHealthText = function(self, plate)
	if not self.db.showHealthText then return plate.HealthText:SetText("") end
	local bar = plate.blizz.healthBar
	local min, max = bar:GetMinMaxValues()
	local v = bar:GetValue()
	if not max or max <= 0 then return plate.HealthText:SetText("") end
	if max <= 100 then
		-- some units only give a percentage
		plate.HealthText:SetText(("%d%%"):format(floor(v / max * 100 + .5)))
	else
		plate.HealthText:SetText(ShortValue(v) .. " / " .. ShortValue(max))
	end
end

Module.UpdatePower = function(self, plate)
	local max = UnitPowerMax("target")
	if not plate.isTarget or not max or max <= 0 then
		plate.Power:Hide(); plate.Power.Text:SetText("")
		return
	end
	local _, token = UnitPowerType("target")
	local c = PowerBarColor and PowerBarColor[token or "MANA"] or { r = 0, g = 0, b = 1 }
	plate.Power:SetStatusBarColor(c.r, c.g, c.b)
	plate.Power:SetMinMaxValues(0, max)
	local v = UnitPower("target")
	plate.Power:SetValue(v)
	plate.Power.Text:SetText(ShortValue(v) .. " / " .. ShortValue(max))
	plate.Power:Show()
end

-- re-apply the size setting to every plate
Module.UpdateScale = function(self)
	local s = PlateScale(self.db)
	for _, plate in pairs(plates) do
		plate.blizz.healthBar:SetScale(s)
		plate.blizz.castBar:SetScale(s)
		plate.blizz.raidIcon:SetSize(24 * s, 24 * s)
	end
end

local ICON = 20
Module.HideDebuffs = function(self, plate)
	for _, d in ipairs(plate.Debuffs) do d:Hide() end
end

Module.UpdateDebuffs = function(self, plate)
	if not self.db.showDebuffs then return self:HideDebuffs(plate) end
	local shown = 0
	for i = 1, 40 do
		local name, _, icon, count, _, duration, expires, caster = UnitDebuff("target", i)
		if not name then break end
		if caster == "player" or caster == "pet" or caster == "vehicle" then
			shown = shown + 1
			if shown > 5 then break end
			local d = plate.Debuffs[shown]
			if not d then
				d = CreateFrame("Frame", nil, plate.blizz.healthBar)
				d:SetSize(ICON, ICON)
				d:SetBackdrop({ bgFile = [[Interface\ChatFrame\ChatFrameBackground]], edgeFile = T .. "DiabolicUI_GlowBorder_128x16.tga", edgeSize = 3, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
				d:SetBackdropColor(0, 0, 0, 1)
				d:SetBackdropBorderColor(.8, 0, 0, 1)
				d.Icon = d:CreateTexture(nil, "ARTWORK")
				d.Icon:SetPoint("TOPLEFT", 2, -2)
				d.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
				d.Icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
				d.Time = d:CreateFontString(nil, "OVERLAY")
				d.Time:SetFontObject(_G.DiabolicKeybind or NumberFontNormalSmall)
				d.Time:SetPoint("TOP", d, "BOTTOM", 0, -1)
				d.Count = d:CreateFontString(nil, "OVERLAY")
				d.Count:SetFontObject(_G.DiabolicKeybind or NumberFontNormalSmall)
				d.Count:SetPoint("BOTTOMRIGHT", 0, 1)
				plate.Debuffs[shown] = d
			end
			d:ClearAllPoints()
			-- centered row above the name
			d:SetPoint("BOTTOMLEFT", plate.Name, "TOP", (shown - 1) * (ICON + 3) - floor(((ICON + 3) * 5 - 3) / 2), 22)
			d.Icon:SetTexture(icon)
			d.Count:SetText((count and count > 1) and count or "")
			d.expires = expires
			local left = (expires and expires > 0) and (expires - GetTime()) or 0
			d.Time:SetText(left > 0 and (left >= 60 and ("%dм"):format(floor(left/60 + .5)) or ("%d"):format(floor(left + .5))) or "")
			d:Show()
		end
	end
	for i = shown + 1, #plate.Debuffs do plate.Debuffs[i]:Hide() end
end

-- runs ~10 times a second: discovery, target and threat state
local elapsedTotal = 0
Module.OnUpdate = function(self, elapsed)
	elapsedTotal = elapsedTotal + elapsed
	if elapsedTotal < .1 then return end
	elapsedTotal = 0

	local n = WorldFrame:GetNumChildren()
	if n ~= numChildren then
		numChildren = n
		for i = 1, n do
			local f = select(i, WorldFrame:GetChildren())
			if not plates[f] and IsPlate(f) then
				CreatePlate(f)
			end
		end
	end

	local hasTarget = UnitExists("target")
	local targetName = hasTarget and UnitName("target")
	for blizz, plate in pairs(plates) do
		if blizz:IsShown() then
			-- the current target is the only plate at full alpha while a target exists
			local isTarget = hasTarget and blizz:GetAlpha() == 1 and plate.blizz.name:GetText() == targetName
			if isTarget ~= plate.isTarget then
				plate.isTarget = isTarget
				if isTarget then plate.Highlight:Show() else plate.Highlight:Hide() end
				if not isTarget then self:HideDebuffs(plate) end
			end
			if isTarget then self:UpdateDebuffs(plate) end
			self:UpdatePower(plate)

			-- threat: the client shows its glow region when we have aggro/threat
			local threat = plate.blizz.threat
			if threat:IsShown() then
				plate.Glow:SetVertexColor(threat:GetVertexColor())
				plate.Glow:Show()
			else
				plate.Glow:Hide()
			end
		end
	end
end

-------------------------------------------------------------------------------
-- top target frame for enemies
-------------------------------------------------------------------------------
-- Only alpha is changed, so it is safe in combat. (Show/Hide on the secure
-- target frame is not allowed in combat.)
Module.UpdateTopTargetFrame = function(self)
	local UF = Engine:GetModule("UnitFrames", true)
	local w = UF and UF:GetWidget("Unit: Target")
	local frame = w and w.GetFrame and w:GetFrame()
	if not frame then return end
	local hide = false
	local mode = self.db.targetMode
	if mode ~= "top" and self.db.enabled and UnitExists("target") and not UnitIsUnit("target", "player") then
		local c = UnitClassification("target")
		local special = (c == "worldboss" or c == "elite" or c == "rareelite" or c == "rare")
		local hostile = UnitCanAttack("player", "target")
		if mode == "plates" then
			-- friendly targets need friendly plates turned on, or there would be nothing to show
			hide = not special and (hostile or self.db.showFriendlyPlates)
		elseif mode == "enemies" then
			hide = hostile and not special and not UnitIsPlayer("target")
		end
	end
	frame:SetAlpha(hide and 0 or 1)
end

Module.ApplyPlateCVars = function(self)
	if InCombatLockdown() or not self.db.enabled then return end
	if self.db.targetMode ~= "top" then
		if self.db.showEnemyPlates then
			SetCVar("nameplateShowEnemies", "1")
			if ShowNameplates then ShowNameplates() end
		end
		SetCVar("nameplateShowFriends", self.db.showFriendlyPlates and "1" or "0")
		if self.db.showFriendlyPlates and ShowFriendNameplates then ShowFriendNameplates() end
	end
end

-------------------------------------------------------------------------------
-- module
-------------------------------------------------------------------------------
Module.GetDB = function(self)
	DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or {}
	local db = DiabolicUI_OptionsDB
	db.nameplates = db.nameplates or {}
	if db.nameplates.enemyMode and not db.nameplates.targetMode then
		db.nameplates.enemyMode = nil
	end
	for k, v in pairs(defaults) do
		if db.nameplates[k] == nil then db.nameplates[k] = v end
	end
	return db.nameplates
end

Module.OnInit = function(self)
	self.db = self:GetDB()
end

Module.OnEnable = function(self)
	self.db = self:GetDB()
	if self.db.enabled then
		self.updater = self.updater or CreateFrame("Frame")
		self.updater:SetScript("OnUpdate", function(_, e) self:OnUpdate(e) end)
	end
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateTopTargetFrame")
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", "UpdateTopTargetFrame")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
end

Module.OnEnteringWorld = function(self)
	self:ApplyPlateCVars()
	self:UpdateTopTargetFrame()
end

Module.SetEnemyMode = function(self, mode)
	self.db.targetMode = mode
	self:ApplyPlateCVars()
	self:UpdateTopTargetFrame()
end
