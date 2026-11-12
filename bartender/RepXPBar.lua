--[[
	Copyright (c) 2009, Hendrik "Nevcairiel" Leppkes < h.leppkes at gmail dot com >
	All rights reserved.
]]
local L = LibStub("AceLocale-3.0"):GetLocale("DiabolicBars")

-- fetch upvalues
local Bar = DiabolicBars.Bar.prototype

local table_insert = table.insert

local defaults = { profile = DiabolicBars:Merge({
	enabled = false,
}, DiabolicBars.Bar.defaults) }

-- register module
local RepBarMod = DiabolicBars:NewModule("RepBar")

-- create prototype information
local RepBar = setmetatable({}, {__index = Bar})

function RepBarMod:OnInitialize()
	self.db = DiabolicBars.db:RegisterNamespace("RepBar", defaults)
	self:SetEnabledState(self.db.profile.enabled)
end

function RepBarMod:OnEnable()
	if not self.bar then
		self.bar = setmetatable(DiabolicBars.Bar:Create("Rep", self.db.profile, L["Reputation Bar"]), {__index = RepBar})
		self.bar.content = ReputationWatchBar

		hooksecurefunc("ReputationWatchBar_Update",  function() self.bar:PerformLayout() end)

		self.bar.content:SetParent(self.bar)
		self.bar.content:Show()
		self.bar.content:SetFrameLevel(self.bar:GetFrameLevel() + 1)
	end
	self.bar:Enable()
	self:ToggleOptions()
	self:ApplyConfig()
end

function RepBarMod:ApplyConfig()
	self.bar:ApplyConfig(self.db.profile)
end

function RepBar:ApplyConfig(config)
	Bar.ApplyConfig(self, config)

	self:PerformLayout()
end

function RepBar:PerformLayout()
	self:SetSize(1032, 21)
	local bar = self.content
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -3)
end

RepBar.ClickThroughSupport = true
function RepBar:ControlClickThrough()
	self.content:EnableMouse(not self.config.clickthrough)
end


-- register module
local XPBarMod = DiabolicBars:NewModule("XPBar")

-- create prototype information
local XPBar = setmetatable({}, {__index = Bar})

function XPBarMod:OnInitialize()
	self.db = DiabolicBars.db:RegisterNamespace("XPBar", defaults)
	self:SetEnabledState(self.db.profile.enabled)
end

function XPBarMod:OnEnable()
	if not self.bar then
		self.bar = setmetatable(DiabolicBars.Bar:Create("XP", self.db.profile, L["XP Bar"]), {__index = XPBar})
		self.bar.content = MainMenuExpBar

		self.bar.content:SetParent(self.bar)
		self.bar.content:Show()
		self.bar.content:SetFrameLevel(self.bar:GetFrameLevel() + 1)
	end
	self.bar:Enable()
	self:ToggleOptions()
	self:ApplyConfig()
end

XPBarMod.ApplyConfig = RepBarMod.ApplyConfig
XPBar.ApplyConfig = RepBar.ApplyConfig
XPBar.PerformLayout = RepBar.PerformLayout

XPBar.ClickThroughSupport = true
XPBar.ControlClickThrough = RepBar.ControlClickThrough
