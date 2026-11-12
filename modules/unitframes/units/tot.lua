local Addon, Engine = ...
local Module = Engine:GetModule("UnitFrames")
local UnitFrameWidget = Module:SetWidget("Unit: ToT")

local UnitFrame = Engine:GetHandler("UnitFrame")
local StatusBar = Engine:GetHandler("StatusBar")

-- Lua API
local unpack, pairs = unpack, pairs

-- WoW API
local CreateFrame = CreateFrame

local UpdateLayers = function(self)
	if self:IsMouseOver() then
		self.BorderNormalHighlight:Show()
		self.BorderNormal:Hide()
	else
		self.BorderNormal:Show()
		self.BorderNormalHighlight:Hide()
	end
end

local Style = function(self, unit)
	local config = Module:GetStaticConfig("UnitFrames").visuals.units.tot
	local db = Module:GetConfig("UnitFrames") 

	
	self:Size(unpack(config.size))
	self:Place(unpack(config.position))


	-- Artwork
	-------------------------------------------------------------------
	local Backdrop = self:CreateTexture(nil, "BORDER")
	Backdrop:SetSize(unpack(config.backdrop.texture_size))
	Backdrop:SetPoint(unpack(config.backdrop.texture_position))
	Backdrop:SetTexture(config.backdrop.texture)

	-- border overlay frame
	local Border = CreateFrame("Frame", nil, self)
	Border:SetFrameLevel(self:GetFrameLevel() + 3)
	Border:SetAllPoints()
	
	local BorderNormal = Border:CreateTexture(nil, "BORDER")
	BorderNormal:SetSize(unpack(config.border.texture_size))
	BorderNormal:SetPoint(unpack(config.border.texture_position))
	BorderNormal:SetTexture(config.border.textures.normal)
	
	local BorderNormalHighlight = Border:CreateTexture(nil, "BORDER")
	BorderNormalHighlight:SetSize(unpack(config.border.texture_size))
	BorderNormalHighlight:SetPoint(unpack(config.border.texture_position))
	BorderNormalHighlight:SetTexture(config.border.textures.highlight)
	BorderNormalHighlight:Hide()

	-- Threat
	-------------------------------------------------------------------
	local Threat = self:CreateTexture(nil, "BACKGROUND")
	Threat:Hide()
	Threat:SetSize(unpack(config.border.texture_size))
	Threat:SetPoint(unpack(config.border.texture_position))
	Threat:SetTexture(config.border.textures.threat)
	

	-- Health
	-------------------------------------------------------------------
	local Health = StatusBar:New(self)
	Health:SetSize(unpack(config.health.size))
	Health:SetPoint(unpack(config.health.position))
	Health:SetStatusBarTexture(config.health.texture)
	Health.frequent = 1/120

	
	-- CastBar
	-------------------------------------------------------------------
	local CastBar = StatusBar:New(Health:GetScaffold())
	CastBar:Hide()
	CastBar:SetAllPoints()
	CastBar:SetStatusBarTexture(1, 1, 1, .25)
	CastBar:SetSize(Health:GetSize())
	--CastBar:SetSparkTexture(config.castbar.spark.texture)
	--CastBar:SetSparkSize(unpack(config.castbar.spark.size))
	--CastBar:SetSparkFlash(unpack(config.castbar.spark.flash))
	CastBar:DisableSmoothing(true)


	-- Portrait (Diablo-WoW): same frame as the focus/pet portraits, smaller
	-------------------------------------------------------------------
	local pconfig = Module:GetStaticConfig("UnitFrames").visuals.units.focus.portrait
	local PSIZE = 44
	local ratio = PSIZE / pconfig.size[1]
	local PortraitHolder = CreateFrame("Frame", nil, self)
	PortraitHolder:SetSize(PSIZE, PSIZE)
	PortraitHolder:SetPoint("RIGHT", self, "LEFT", 6, -4)

	local PortraitBackdrop = PortraitHolder:CreateTexture(nil, "BACKGROUND")
	PortraitBackdrop:SetSize(pconfig.texture_size[1] * ratio, pconfig.texture_size[2] * ratio)
	PortraitBackdrop:SetPoint("CENTER")
	PortraitBackdrop:SetTexture(pconfig.textures.backdrop)

	local Portrait = CreateFrame("PlayerModel", nil, PortraitHolder)
	Portrait:SetFrameLevel(self:GetFrameLevel() + 1)
	Portrait:SetAllPoints()

	local PortraitBorder = CreateFrame("Frame", nil, PortraitHolder)
	PortraitBorder:SetFrameLevel(self:GetFrameLevel() + 2)
	PortraitBorder:SetAllPoints()

	local PortraitBorderNormal = PortraitBorder:CreateTexture(nil, "ARTWORK")
	PortraitBorderNormal:SetSize(pconfig.texture_size[1] * ratio, pconfig.texture_size[2] * ratio)
	PortraitBorderNormal:SetPoint("CENTER")
	PortraitBorderNormal:SetTexture(pconfig.textures.border)

	self.Portrait = Portrait

	-- Texts
	-------------------------------------------------------------------
	local Name = Border:CreateFontString(nil, "OVERLAY")
	Name:SetFontObject(config.name.font_object)
	Name:SetPoint(unpack(config.name.position))
	Name:SetSize(unpack(config.name.size))
	Name:SetJustifyV("BOTTOM")
	Name:SetJustifyH("CENTER")
	Name:SetIndentedWordWrap(false)
	Name:SetWordWrap(true)
	Name:SetNonSpaceWrap(false)


	self.CastBar = CastBar
	self.Health = Health
	self.Name = Name
	self.Threat = Threat

	self.BorderNormal = BorderNormal
	self.BorderNormalHighlight = BorderNormalHighlight

	self:HookScript("OnEnter", UpdateLayers)
	self:HookScript("OnLeave", UpdateLayers)
	
	--self:SetAttribute("toggleForVehicle", true)

end

UnitFrameWidget.OnEnable = function(self)
	self.UnitFrame = UnitFrame:New("targettarget", Engine:GetFrame(), Style) 
end

UnitFrameWidget.GetFrame = function(self)
	return self.UnitFrame
end

