-- DiabolicUI/modules/options/minimap_button.lua
-- Кнопка у миникарты для доступа к меню и быстрому включению Move Mode

local Addon, Engine = ...

-- Saved in the same DB
DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or { perChar = {}, profiles = {} }
local realm = GetRealmName() or "DefaultRealm"
local char  = UnitName("player") or "Player"
local perCharKey = realm .. " - " .. char
DiabolicUI_OptionsDB.perChar[perCharKey] = DiabolicUI_OptionsDB.perChar[perCharKey] or {}
local PCHAR = DiabolicUI_OptionsDB.perChar[perCharKey]
PCHAR.minimapButton = PCHAR.minimapButton or { angle = 210, radius = 78, locked = false, hide = false }

local function Minimap_UpdateButtonPos(btn)
	local angle = math.rad(PCHAR.minimapButton.angle or 210)
	local x = math.cos(angle) * (PCHAR.minimapButton.radius or 78)
	local y = math.sin(angle) * (PCHAR.minimapButton.radius or 78)
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function ToggleInterfaceOptions()
	InterfaceOptionsFrame_OpenToCategory(DiabolicUI_OptionsPanel)
	InterfaceOptionsFrame_OpenToCategory(DiabolicUI_OptionsPanel)
end

local function ToggleMoveMode()
	if Engine and Engine:GetModule("Options", true) and Engine:GetModule("Options", true).ToggleMove then
		Engine:GetModule("Options", true):ToggleMove()
	else
		SlashCmdList["DIO_MOVE"]()
	end
end

local btn = CreateFrame("Button", "DiabolicUI_MinimapButton", Minimap)
btn:SetSize(31,31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)

-- background & icon
local overlay = btn:CreateTexture(nil, "OVERLAY")
overlay:SetSize(54,54); overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(20,20); icon:SetTexture("Interface\\AddOns\\DiabolicUI\\media\\textures\\cogs") -- замените на вашу текстуру, если нужно
icon:SetPoint("CENTER", 0, 0)

btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

btn:RegisterForClicks("AnyUp")
btn:SetScript("OnClick", function(self, button)
	if button == "LeftButton" then
		ToggleInterfaceOptions()
	else
		ToggleMoveMode()
	end
end)

btn:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("|cffffcc00DiabolicUI|r")
	GameTooltip:AddLine("ЛКМ: открыть настройки", 0, .8, 0)
	GameTooltip:AddLine("ПКМ: режим перемещения", 0, .8, 0)
	GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Drag to move around minimap
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", function(self)
	if PCHAR.minimapButton.locked then return end
	self:StartMoving()
end)
btn:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	-- вычисляем угол
	local mx, my = Minimap:GetCenter()
	local bx, by = self:GetCenter()
	local scale = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
	mx, my, bx, by = mx*scale, my*scale, bx*scale, by*scale
	local angle = math.deg(math.atan2(by - my, bx - mx))
	if angle < 0 then angle = angle + 360 end
	PCHAR.minimapButton.angle = math.floor(angle + 0.5)
	Minimap_UpdateButtonPos(self)
end)

-- Init
btn:SetScript("OnShow", function(self) Minimap_UpdateButtonPos(self) end)
Minimap_UpdateButtonPos(btn)
if PCHAR.minimapButton.hide then btn:Hide() end

-- Slash helper
SLASH_DIO_MINIBUTTON1="/diomb"
SlashCmdList["DIO_MINIBUTTON"]=function()
	if btn:IsShown() then btn:Hide(); PCHAR.minimapButton.hide=true
	else btn:Show(); PCHAR.minimapButton.hide=false; Minimap_UpdateButtonPos(btn) end
end
