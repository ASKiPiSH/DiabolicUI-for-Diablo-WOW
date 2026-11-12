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
	enemyMode = "normal",  -- "top" = classic top frame only, "normal" = plates for ordinary enemies, "all" = plates for every enemy
	showEnemyPlates = true, -- turn the client nameplates on at login
	showDebuffs = true,
	scale = 1,
}

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
	plate.Name:SetPoint("BOTTOM", healthBar, "TOP", 0, 6)
	plate.Name:SetWidth(W + 60)
	plate.Name:SetWordWrap(false)

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
	raidIcon:SetSize(24, 24)
	raidIcon:SetPoint("BOTTOM", plate.Name, "TOP", 0, 2)

	-- cast bar under the health bar
	castBar:ClearAllPoints()
	castBar:SetPoint("TOP", healthBar, "BOTTOM", 0, -6)
	castBar:SetSize(W, CAST_H)
	castBar:SetStatusBarTexture(BAR_TEXTURE)
	plate.CastBack = castBar:CreateTexture(nil, "BACKGROUND")
	plate.CastBack:SetPoint("TOPLEFT", -1, 1)
	plate.CastBack:SetPoint("BOTTOMRIGHT", 1, -1)
	plate.CastBack:SetTexture(0, 0, 0, .75)
	plate.CastBorder = plate.CastBack

	plate.SpellIconFrame = CreateFrame("Frame", nil, castBar)
	plate.SpellIconFrame:SetSize(H + CAST_H + 6, H + CAST_H + 6)
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
	plate:SetScale(self.db.scale or 1)
	UpdateCastBar(plate)
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
	local mode = self.db.enemyMode
	if mode ~= "top" and UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsPlayer("target") then
		if mode == "all" then
			hide = true
		else
			local c = UnitClassification("target")
			hide = (c == "normal" or c == "trivial" or c == "minus")
		end
	end
	frame:SetAlpha(hide and 0 or 1)
end

Module.ApplyPlateCVars = function(self)
	if InCombatLockdown() then return end
	if self.db.showEnemyPlates and self.db.enemyMode ~= "top" then
		SetCVar("nameplateShowEnemies", "1")
		if ShowNameplates then ShowNameplates() end
	end
end

-------------------------------------------------------------------------------
-- module
-------------------------------------------------------------------------------
Module.GetDB = function(self)
	DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or {}
	local db = DiabolicUI_OptionsDB
	db.nameplates = db.nameplates or {}
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
	self.db.enemyMode = mode
	self:ApplyPlateCVars()
	self:UpdateTopTargetFrame()
end
