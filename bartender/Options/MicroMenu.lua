--[[
	Copyright (c) 2009, Hendrik "Nevcairiel" Leppkes < h.leppkes at gmail dot com >
	All rights reserved.
]]
local L = LibStub("AceLocale-3.0"):GetLocale("DiabolicBars")

local MicroMenuMod = DiabolicBars:GetModule("MicroMenu")

-- fetch upvalues
local ButtonBar = DiabolicBars.ButtonBar.prototype

function MicroMenuMod:SetupOptions()
	if not self.options then
		self.optionobject = ButtonBar:GetOptionObject()
		self.optionobject.table.general.args.rows.max = self.button_count
		local enabled = {
			type = "toggle",
			order = 1,
			name = L["Enabled"],
			desc = L["Enable the Micro Menu"],
			get = function() return self.db.profile.enabled end,
			set = "ToggleModule",
			handler = self,
		}
		self.optionobject:AddElement("general", "enabled", enabled)

		self.disabledoptions = {
			general = {
				type = "group",
				name = L["General Settings"],
				cmdInline = true,
				order = 1,
				args = {
					enabled = enabled,
				}
			}
		}
		self.options = {
			order = 30,
			type = "group",
			name = L["Micro Menu"],
			desc = L["Configure the Micro Menu"],
			childGroups = "tab",
		}
		self.optionobject.table.general.args.padding.min = -30
		DiabolicBars:RegisterBarOptions("MicroMenu", self.options)
	end
	self.options.args = self:IsEnabled() and self.optionobject.table or self.disabledoptions
end
