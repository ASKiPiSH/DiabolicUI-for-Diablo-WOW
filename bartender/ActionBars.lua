--[[
	Copyright (c) 2009, Hendrik "Nevcairiel" Leppkes < h.leppkes at gmail dot com >
	All rights reserved.
]]
local L = LibStub("AceLocale-3.0"):GetLocale("DiabolicBars")
local DBTActionBars = DiabolicBars:NewModule("ActionBars", "AceEvent-3.0")

local ActionBar, ActionBar_MT

local abdefaults = {
	['**'] = DiabolicBars:Merge({
		enabled = true,
		buttons = 12,
		hidemacrotext = false,
		showgrid = false,
	}, DiabolicBars.StateBar.defaults),
	[1] = {
		states = {
			enabled = true,
			possess = true,
			actionbar = true,
			stance = {
				DRUID = { bear = 9, cat = 7, prowl = 8 },
				WARRIOR = { battle = 7, def = 8, berserker = 9 },
				ROGUE = { stealth = 7, shadowdance = 7 }
			},
		},
		visibility = {
			vehicleui = false,
		},
	},
	[7] = {
		enabled = false,
	},
	[8] = {
		enabled = false,
	},
	[9] = {
		enabled = false,
	},
	[10] = {
		enabled = false,
	},
}

local defaults = {
	profile = {
		actionbars = abdefaults,
	}
}

function DBTActionBars:OnInitialize()
	self.db = DiabolicBars.db:RegisterNamespace("ActionBars", defaults)

	-- fetch the prototype information
	ActionBar = DiabolicBars.ActionBar
	ActionBar_MT = {__index = ActionBar}
end


local LBF = LibStub("LibButtonFacade", true)

-- setup the 10 actionbars
local first = true
function DBTActionBars:OnEnable()
	if first then
		self.playerclass = select(2, UnitClass("player"))
		self.actionbars = {}

		for i=1,10 do
			local config = self.db.profile.actionbars[i]
			if config.enabled then
				self.actionbars[i] = self:Create(i, config)
			else
				self:CreateBarOption(i, self.disabledoptions)
			end
		end

		first = nil
	end

	self:RegisterEvent("UPDATE_BINDINGS", "ReassignBindings")
	self:ReassignBindings()
end

function DBTActionBars:SetupOptions()
	if not self.options then
		-- empty table to hold the bar options
		self.options = {}

		-- template for disabled bars
		self.disabledoptions = {
			general = {
				type = "group",
				name = L["General Settings"],
				cmdInline = true,
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = L["Enabled"],
						desc = L["Enable/Disable the bar."],
						set = function(info, v) if v then DBTActionBars:EnableBar(info[2]) end end,
						get = function() return false end,
					}
				}
			}
		}

		-- iterate over bars and create their option tables
		for i=1,10 do
			local config = self.db.profile.actionbars[i]
			if config.enabled then
				self:CreateBarOption(i)
			else
				self:CreateBarOption(i, self.disabledoptions)
			end
		end
	end
end

-- Applys the config in the current profile to all active Bars
function DBTActionBars:ApplyConfig()
	for i=1,10 do
		local config = self.db.profile.actionbars[i]
		-- make sure the bar has its current config object if it exists already
		if self.actionbars[i] then
			self.actionbars[i].config = config
		end
		if config.enabled then
			self:EnableBar(i)
		else
			self:DisableBar(i)
		end
	end
end

-- we do not allow to disable the actionbars module
function DBTActionBars:ToggleModule()
	return
end

function DBTActionBars:UpdateButtons(force)
	for i,v in ipairs(self.actionbars) do
		for j,button in ipairs(v.buttons) do
			button:UpdateAction(force)
		end
	end
end

function DBTActionBars:ReassignBindings()
	if InCombatLockdown() then return end
	if not self.actionbars or not self.actionbars[1] then return end
	local frame = self.actionbars[1]
	ClearOverrideBindings(frame)
	for i = 1,min(#frame.buttons, 12) do
		local button, real_button = ("ACTIONBUTTON%d"):format(i), ("DBTButton%d"):format(i)
		for k=1, select('#', GetBindingKey(button)) do
			local key = select(k, GetBindingKey(button))
			SetOverrideBindingClick(frame, false, key, real_button)
		end
	end

	for i = 1, 120 do
		-- rename old bindings from <buttonname>Secure to only <buttonname>
		local button, real_button = ("CLICK DBTButton%dSecure:LeftButton"):format(i), ("DBTButton%d"):format(i)

		for k=1, select('#', GetBindingKey(button)) do
			local key = select(k, GetBindingKey(button))
			if key and key ~= "" then
				SetBindingClick(key, real_button, "LeftButton")
			end
		end
	end
	SaveBindings(GetCurrentBindingSet() or 1)
end

-- Creates a new bar object based on the id and the specified config
function DBTActionBars:Create(id, config)
	local id = tostring(id)
	local bar = setmetatable(DiabolicBars.StateBar:Create(id, config, (L["Bar %s"]):format(id)), ActionBar_MT)
	bar.module = self

	self:CreateBarOption(id)

	bar:ApplyConfig()

	return bar
end

function DBTActionBars:DisableBar(id)
	id = tonumber(id)
	local bar = self.actionbars[id]
	if not bar then return end

	bar.config.enabled = false
	bar:Disable()
	self:CreateBarOption(id, self.disabledoptions)
end

function DBTActionBars:EnableBar(id)
	id = tonumber(id)
	local bar = self.actionbars[id]
	local config = self.db.profile.actionbars[id]
	config.enabled = true
	if not bar then
		bar = self:Create(id, config)
		self.actionbars[id] = bar
	else
		bar.disabled = nil
		self:CreateBarOption(id)
		bar:ApplyConfig(config)
	end
	if not DiabolicBars.Locked then
		bar:Unlock()
	end
end

function DBTActionBars:GetAll()
	return pairs(self.actionbars)
end

function DBTActionBars:ForAll(method, ...)
	for _, bar in self:GetAll() do
		local func = bar[method]
		if func then
			func(bar, ...)
		end
	end
end

function DBTActionBars:ForAllButtons(...)
	self:ForAll("ForAll", ...)
end
