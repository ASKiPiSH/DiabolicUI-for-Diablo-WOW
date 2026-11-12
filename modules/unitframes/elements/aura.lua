--[[
	Auras element (Diablo-WoW). The original DiabolicUI only had an empty stub here,
	so the target frame never showed any buffs or debuffs.

	Usage in a unit style function:
		local Auras = CreateFrame("Frame", nil, self)
		Auras:SetPoint(...)
		Auras.size, Auras.spacing, Auras.perRow, Auras.max = 26, 4, 8, 16
		self.Auras = Auras

	Hostile unit: debuffs first (your own first), then buffs (stealable highlighted).
	Friendly unit: buffs first, then debuffs.
]]
local ADDON, Engine = ...
local Handler = Engine:GetHandler("UnitFrame")
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists
local GetTime = GetTime
local floor = math.floor
local tinsert, tsort, wipe = table.insert, table.sort, table.wipe

local BLANK = [[Interface\ChatFrame\ChatFrameBackground]]
local GLOW = path .. [[textures\DiabolicUI_GlowBorder_128x16.tga]]

local DebuffTypeColor = DebuffTypeColor or {}
local colorNone = { r = .8, g = 0, b = 0 }
local colorBuff = { r = .35, g = .3, b = .2 }
local colorSteal = { r = 1, g = .82, b = 0 }

local formatTime = function(t)
	if t >= 3600 then return ("%dч"):format(floor(t/3600 + .5)) end
	if t >= 60 then return ("%dм"):format(floor(t/60 + .5)) end
	if t >= 10 then return ("%d"):format(floor(t + .5)) end
	return ("%.1f"):format(t)
end

local Button_OnUpdate = function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < .1 then return end
	self.elapsed = 0
	if self.expires and self.expires > 0 then
		local left = self.expires - GetTime()
		if left > 0 then
			self.Time:SetText(formatTime(left))
			return
		end
	end
	self.Time:SetText("")
end

local Button_OnEnter = function(self)
	if not self.unit or not self.index then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, -4)
	GameTooltip:SetUnitAura(self.unit, self.index, self.filter)
	GameTooltip:Show()
end

local Button_OnLeave = function(self)
	GameTooltip:Hide()
end

local CreateButton = function(Auras, i)
	local size = Auras.size or 26
	local b = CreateFrame("Frame", nil, Auras)
	b:SetSize(size, size)
	b:EnableMouse(true)
	b:SetScript("OnEnter", Button_OnEnter)
	b:SetScript("OnLeave", Button_OnLeave)
	b:SetScript("OnUpdate", Button_OnUpdate)

	b:SetBackdrop({ bgFile = BLANK, edgeFile = GLOW, edgeSize = 4, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
	b:SetBackdropColor(0, 0, 0, 1)

	local Icon = b:CreateTexture(nil, "ARTWORK")
	Icon:SetPoint("TOPLEFT", 3, -3)
	Icon:SetPoint("BOTTOMRIGHT", -3, 3)
	Icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	b.Icon = Icon

	local Cooldown = CreateFrame("Cooldown", nil, b)
	Cooldown:SetAllPoints(Icon)
	Cooldown:SetReverse(true)
	Cooldown.noCooldownCount = true -- OmniCC: we draw our own timer
	b.Cooldown = Cooldown

	local Overlay = CreateFrame("Frame", nil, b)
	Overlay:SetAllPoints()
	Overlay:SetFrameLevel(Cooldown:GetFrameLevel() + 1)

	local Count = Overlay:CreateFontString(nil, "OVERLAY")
	Count:SetFontObject(_G.DiabolicKeybind or NumberFontNormalSmall)
	Count:SetPoint("BOTTOMRIGHT", -1, 2)
	b.Count = Count

	local Time = Overlay:CreateFontString(nil, "OVERLAY")
	Time:SetFontObject(_G.DiabolicKeybind or NumberFontNormalSmall)
	Time:SetPoint("TOP", b, "BOTTOM", 0, -1)
	Time:SetTextColor(.9, .9, .9)
	b.Time = Time

	Auras[i] = b
	return b
end

local list = {}
local function collect(unit, filter, mine_first)
	local i = 1
	while true do
		local name, rank, icon, count, dtype, duration, expires, caster, stealable = UnitAura(unit, i, filter)
		if not name then break end
		tinsert(list, {
			index = i, filter = filter, icon = icon, count = count, dtype = dtype,
			duration = duration, expires = expires, stealable = stealable,
			mine = (caster == "player" or caster == "pet" or caster == "vehicle"),
			order = #list
		})
		i = i + 1
	end
end

local sortMineFirst = function(a, b)
	if a.filter ~= b.filter then return a.group < b.group end
	if a.mine ~= b.mine then return a.mine end
	return a.order < b.order
end

local Update = function(self, event, arg1)
	local Auras = self.Auras
	if not Auras then return end
	local unit = self.unit
	if event == "UNIT_AURA" and arg1 ~= unit then return end
	if Auras.disabled or not UnitExists(unit) then
		for i = 1, #Auras do Auras[i]:Hide() end
		return
	end

	wipe(list)
	local hostile = UnitCanAttack("player", unit)
	if hostile then
		collect(unit, "HARMFUL")
		collect(unit, "HELPFUL")
	else
		collect(unit, "HELPFUL")
		collect(unit, "HARMFUL")
	end
	local first = hostile and "HARMFUL" or "HELPFUL"
	for _, a in ipairs(list) do a.group = (a.filter == first) and 1 or 2 end
	tsort(list, sortMineFirst)

	local size, spacing, perRow = Auras.size or 26, Auras.spacing or 4, Auras.perRow or 8
	local max = Auras.max or 16
	local shown = 0
	for _, a in ipairs(list) do
		if shown >= max then break end
		-- on enemies, only your own debuffs plus every buff; on friends everything
		if not (hostile and a.filter == "HARMFUL" and Auras.onlyMine and not a.mine) then
			shown = shown + 1
			local b = Auras[shown] or CreateButton(Auras, shown)
			b.unit, b.index, b.filter, b.expires = unit, a.index, a.filter, a.expires
			b.Icon:SetTexture(a.icon)
			b.Count:SetText((a.count and a.count > 1) and a.count or "")
			if a.duration and a.duration > 0 and a.expires then
				b.Cooldown:SetCooldown(a.expires - a.duration, a.duration)
				b.Cooldown:Show()
			else
				b.Cooldown:Hide()
			end
			local c
			if a.filter == "HARMFUL" then
				c = DebuffTypeColor[a.dtype or "none"] or colorNone
			elseif a.stealable and hostile then
				c = colorSteal
			else
				c = colorBuff
			end
			b:SetBackdropBorderColor(c.r, c.g, c.b, 1)
			-- dim debuffs from other players on enemies so yours stand out
			b.Icon:SetAlpha((hostile and a.filter == "HARMFUL" and not a.mine) and .6 or 1)

			local row = floor((shown - 1) / perRow)
			local col = (shown - 1) % perRow
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", Auras, "TOPLEFT", col * (size + spacing), -row * (size + spacing + 10))
			b:Show()
		end
	end
	for i = shown + 1, #Auras do Auras[i]:Hide() end
end

local Enable = function(self)
	local Auras = self.Auras
	if Auras then
		self:RegisterEvent("UNIT_AURA", Update)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", Update)
		self:RegisterEvent("PLAYER_FOCUS_CHANGED", Update)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
	end
end

local Disable = function(self)
	local Auras = self.Auras
	if Auras then
		self:UnregisterEvent("UNIT_AURA", Update)
		self:UnregisterEvent("PLAYER_TARGET_CHANGED", Update)
		self:UnregisterEvent("PLAYER_FOCUS_CHANGED", Update)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Update)
	end
end

Handler:RegisterElement("Auras", Enable, Disable, Update)
