--[[
	DiabolicUI button skin for the embedded DiabolicBars (Bartender4).

	Puts the DiabolicUI slot + border frame around every action, pet and stance button.
	The texture set (36/44/50 px) is picked from the button's on-screen size, so the
	frame stays sharp whatever scale the bar uses.
]]
local ADDON, Engine = ...
local BT = _G.DiabolicBars
if not BT then return end

local path = ([[Interface\AddOns\%s\media\textures\]]):format(ADDON)

local pairs, ipairs, unpack = pairs, ipairs, unpack
local math_abs = math.abs
local _G = _G

-- geometry of the original DiabolicUI buttons, in screen pixels
local STYLES = {
	[36] = { inset = 4, frame = 64, offset = 14 },
	[44] = { inset = 6, frame = 64, offset = 10 },
	[50] = { inset = 5, frame = 64, offset = 7 },
}
for px, s in pairs(STYLES) do
	local p = path .. ("DiabolicUI_Button_%dx%d_"):format(px, px)
	s.slot = p .. "BackdropWeapon.tga"
	s.border = p .. "Border.tga"
	s.highlight = p .. "BorderHighlight.tga"
	s.checked = p .. "Checked.tga"
	s.checkedHighlight = p .. "CheckedHighlight.tga"
end

local function PickStyle(px)
	local best, diff
	for size in pairs(STYLES) do
		local d = math_abs(size - px)
		if not diff or d < diff then best, diff = size, d end
	end
	return best
end

local function UpdateBorderState(button)
	local s = button.__dui
	if not s then return end
	local checked = button:GetChecked()
	local over = s.mouseover
	s.border:SetTexture(checked and (over and s.style.checkedHighlight or s.style.checked) or (over and s.style.highlight or s.style.border))
end

local function SetupButton(button)
	if button.__dui then return button.__dui end
	local name = button:GetName()
	local s = {}
	button.__dui = s

	s.icon = button.icon or (name and _G[name .. "Icon"])
	s.cooldown = button.cooldown or (name and _G[name .. "Cooldown"])
	s.flash = button.flash or (name and _G[name .. "Flash"])
	s.equipped = button.border or (name and _G[name .. "Border"])
	s.hotkey = button.hotkey or (name and _G[name .. "HotKey"])
	s.count = button.count or (name and _G[name .. "Count"])
	s.macro = button.macroName or (name and _G[name .. "Name"])
	s.autocast = name and _G[name .. "AutoCastable"]

	-- slot backdrop behind the icon
	s.slot = button:CreateTexture(nil, "BACKGROUND")

	-- border lives in a child frame so it is drawn above the icon and cooldown
	s.frame = CreateFrame("Frame", nil, button)
	s.frame:SetAllPoints()
	s.frame:SetFrameLevel(button:GetFrameLevel() + 3)
	s.border = s.frame:CreateTexture(nil, "ARTWORK")

	-- texts above the border
	for _, fs in ipairs({ s.hotkey, s.count, s.macro }) do
		if fs then
			if fs.SetParent then pcall(fs.SetParent, fs, s.frame) end
			if fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY") end
		end
	end
	if s.hotkey then
		s.hotkey:SetFontObject(_G.DiabolicKeybind or NumberFontNormalSmallGray)
	end
	if s.count then
		s.count:SetFontObject(_G.DiabolicKeybind or NumberFontNormal)
	end

	-- the default glossy frame, highlight and checked textures are replaced by ours
	local nt = button.normalTexture or button:GetNormalTexture()
	if nt then nt:SetAlpha(0) end
	local ht = button:GetHighlightTexture()
	if ht then ht:SetAlpha(0) end
	local ct = button:GetCheckedTexture()
	if ct then ct:SetAlpha(0) end

	button:HookScript("OnEnter", function(self) self.__dui.mouseover = true; UpdateBorderState(self) end)
	button:HookScript("OnLeave", function(self) self.__dui.mouseover = nil; UpdateBorderState(self) end)
	hooksecurefunc(button, "SetChecked", UpdateBorderState)
	return s
end

local function StyleButton(button, scale)
	local s = SetupButton(button)
	local width = button:GetWidth()
	if not width or width <= 0 then width = 36 end
	local px = width * (scale or 1)
	local stylePx = PickStyle(px)
	local style = STYLES[stylePx]
	local k = width / stylePx -- button units per style pixel
	s.style = style

	local inset = style.inset * k
	if s.icon then
		s.icon:ClearAllPoints()
		s.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
		s.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
		s.icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	end
	if s.cooldown then
		s.cooldown:ClearAllPoints()
		s.cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
		s.cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
	end
	for _, t in ipairs({ s.flash, s.equipped, button:GetPushedTexture() }) do
		if t then
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
			t:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
		end
	end

	local size, off = style.frame * k, style.offset * k
	s.slot:ClearAllPoints()
	s.slot:SetSize(size, size)
	s.slot:SetPoint("TOPLEFT", button, "TOPLEFT", -off, off)
	s.slot:SetTexture(style.slot)

	s.border:ClearAllPoints()
	s.border:SetSize(size, size)
	s.border:SetPoint("TOPLEFT", button, "TOPLEFT", -off, off)

	if s.hotkey then
		s.hotkey:ClearAllPoints()
		s.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -(inset + 1), -(inset))
	end
	if s.count then
		s.count:ClearAllPoints()
		s.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -(inset + 1), inset)
	end
	UpdateBorderState(button)
end

local function SkinBar(bar)
	if not bar or not bar.buttons then return end
	-- micro menu, bag and vehicle buttons keep their own look
	if bar.id == "MicroMenu" or bar.id == "BagBar" or bar.id == "Vehicle" or bar.id == "MultiCast" then return end
	local scale = bar.config and bar.config.position and bar.config.position.scale or bar:GetScale() or 1
	for _, button in pairs(bar.buttons) do
		if type(button) == "table" and button.GetObjectType then
			StyleButton(button, scale)
		end
	end
end

-- every ButtonBar (action, pet, stance, vehicle...) goes through UpdateButtonLayout
local ButtonBar = BT.ButtonBar and BT.ButtonBar.prototype
if ButtonBar then
	hooksecurefunc(ButtonBar, "UpdateButtonLayout", SkinBar)
end
local Bar = BT.Bar and BT.Bar.prototype
if Bar and Bar.SetConfigScale then
	hooksecurefunc(Bar, "SetConfigScale", function(bar) SkinBar(bar) end)
end

-- re-check the border state when the action changes (checked/current action)
if ActionButton_UpdateState then
	hooksecurefunc("ActionButton_UpdateState", function(button)
		if button and button.__dui then UpdateBorderState(button) end
	end)
end

Engine.SkinActionButton = StyleButton
