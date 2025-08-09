-- DiabolicUI/modules/options/options.lua
-- Полное меню настроек (LK 3.3.5a):
--  * Настройки по персонажу (perChar)
--  * Режим переноса фреймов (со снапом к сетке)
--  * Прокручиваемый список элементов
--  * Вкладки: "Основные" и "Дополнительно"
--  * Кнопка у миникарты (иконка аддона)
--  * Импорт/Экспорт профиля

local Addon, Engine = ...
local Options = Engine:NewModule("Options")

------------------------------------------------------------
-- SavedVariables (общая БД с мапой perChar -> активный профиль)
------------------------------------------------------------
DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or { version=1, profiles={}, perChar={} }

local function PerCharKey()
	local realm = GetRealmName() or "DefaultRealm"
	local name  = UnitName("player") or "Player"
	return realm.." - "..name
end

local function ActiveProfileName()
	local key = PerCharKey()
	local pc  = DiabolicUI_OptionsDB.perChar
	pc[key] = pc[key] or { activeProfile = "Default" }
	return pc[key].activeProfile or "Default"
end

local function EnsureProfile(name)
	local db = DiabolicUI_OptionsDB
	db.profiles[name] = db.profiles[name] or {
		frames  = {},                 -- позиции/масштабы/замки
		modules = {},                 -- вкл/выкл модулей
		grid    = { enabled=false, size=8, show=false } -- сетка
	}
	local p = db.profiles[name]
	p.grid.size    = p.grid.size or 8
	p.grid.enabled = not not p.grid.enabled
	p.grid.show    = not not p.grid.show
	return p
end

local function P() return EnsureProfile(ActiveProfileName()) end

------------------------------------------------------------
-- Реестр управляемых модулей/виджетов
------------------------------------------------------------
local Registry = {
	Modules = {
		"ActionBars","Minimap","UnitFrames","Buffs","CastBars",
		"NamePlates","Objectives","Tooltips","Chat","Bags"
	},
	Widgets = {
		-- ActionBars
		{ module="ActionBars", widget="Controller: Main",  title="Контроллер: Main"  },
		{ module="ActionBars", widget="Controller: Side",  title="Контроллер: Side"  },
		{ module="ActionBars", widget="Bar: 1",  title="Панель 1" },
		{ module="ActionBars", widget="Bar: 2",  title="Панель 2" },
		{ module="ActionBars", widget="Bar: 3",  title="Панель 3" },
		{ module="ActionBars", widget="Bar: 4",  title="Панель 4" },
		{ module="ActionBars", widget="Bar: 5",  title="Панель 5" },
		{ module="ActionBars", widget="Bar: XP", title="Панель опыта" },
		{ module="ActionBars", widget="Bar: Pet",     title="Панель питомца" },
		{ module="ActionBars", widget="Bar: Stance",  title="Панель стоек" },
		{ module="ActionBars", widget="Bar: Vehicle", title="Панель транспорта" },

		-- Minimap
		{ module="Minimap", widget=nil, title="Миникарта", get=function(mod)
			local f = mod.GetFrame and mod:GetFrame()
			return f and { f } or {}
		end },

		-- UnitFrames
		{ module="UnitFrames", widget="Unit: Player", title="Фрейм игрока" },
		{ module="UnitFrames", widget="Unit: Target", title="Фрейм цели"  },
		{ module="UnitFrames", widget="Unit: Focus",  title="Фрейм фокуса"},
		{ module="UnitFrames", widget="Unit: ToT",    title="Цель цели"   },
		{ module="UnitFrames", widget="Unit: Pet",    title="Фрейм питомца"},
	}
}

-- Публичное API для регистрации дополнительных виджетов
_G.DiabolicUI_RegisterOptionsWidget = function(moduleName, title, getFramesFunc, widgetName)
	table.insert(Registry.Widgets, { module=moduleName, title=title, get=getFramesFunc, widget=widgetName })
end

------------------------------------------------------------
-- Утилиты
------------------------------------------------------------
local function call(obj, method, ...)
	if obj and obj[method] then return obj[method](obj, ...) end
end

local function GetWidgetFrames(moduleName, widgetName, customGet)
	local mod = Engine:GetModule(moduleName, true)
	if not mod then return {} end

	if customGet then
		local ok, frames = pcall(customGet, mod)
		if ok and type(frames)=="table" then
			local out={} ; for _,f in ipairs(frames) do if f then table.insert(out, f) end end
			return out
		end
		return {}
	end

	if not widgetName then
		local f = call(mod,"GetFrame"); return f and {f} or {}
	end
	local w = call(mod,"GetWidget", widgetName); if not w then return {} end
	if w.GetFrame then
		local a,b,c = w:GetFrame(); local t={}
		if a then t[#t+1]=a end; if b then t[#t+1]=b end; if c then t[#t+1]=c end
		return t
	end
	return {}
end

local function ReadPoint(f)
	local p, rel, rp, x, y = f:GetPoint()
	return p or "CENTER", (rel and rel:GetName()) or "UIParent", rp or "CENTER", x or 0, y or 0
end

-- snap helpers
local function roundToStep(val, step)
	if not step or step<=1 then return val end
	local half = step*0.5
	if val>=0 then return math.floor((val+half)/step)*step
	else return math.ceil((val-half)/step)*step end
end

------------------------------------------------------------
-- Сетка
------------------------------------------------------------
local Grid = { frame=nil, V={}, H={} }

local function UpdateGridOverlay()
	local profile=P()
	if not profile.grid.show then if Grid.frame then Grid.frame:Hide() end; return end
	local size = profile.grid.size or 8
	if not Grid.frame then
		Grid.frame = CreateFrame("Frame","DiabolicUI_GridOverlay",UIParent)
		Grid.frame:SetFrameStrata("TOOLTIP")
		Grid.frame:SetAllPoints()
	end
	local w,h = UIParent:GetWidth(), UIParent:GetHeight()
	local needV, needH = math.floor(w/size), math.floor(h/size)

	for i=1,needV do
		if not Grid.V[i] then
			local t=Grid.frame:CreateTexture(nil,"ARTWORK")
			t:SetTexture("Interface\\Buttons\\WHITE8x8")
			t:SetVertexColor(1,1,1,0.08)
			Grid.V[i]=t
		end
		local x=i*size
		local line=Grid.V[i]
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
		line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
		line:SetWidth(1); line:Show()
	end
	for i=needV+1,#Grid.V do if Grid.V[i] then Grid.V[i]:Hide() end end

	for i=1,needH do
		if not Grid.H[i] then
			local t=Grid.frame:CreateTexture(nil,"ARTWORK")
			t:SetTexture("Interface\\Buttons\\WHITE8x8")
			t:SetVertexColor(1,1,1,0.08)
			Grid.H[i]=t
		end
		local y=-i*size
		local line=Grid.H[i]
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, y)
		line:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, y)
		line:SetHeight(1); line:Show()
	end
	for i=needH+1,#Grid.H do if Grid.H[i] then Grid.H[i]:Hide() end end
	Grid.frame:Show()
end

------------------------------------------------------------
-- Применение конфигов к фрейму
------------------------------------------------------------
local function ApplyFrameConfig(f, cfg)
	if not (f and f.SetPoint) then return end
	if cfg.scale and f.SetScale then f:SetScale(cfg.scale) end
	if cfg.point and cfg.rel and cfg.relPoint then
		f:ClearAllPoints()
		local rel = _G[cfg.rel] or UIParent
		local x,y = cfg.x or 0, cfg.y or 0
		if P().grid.enabled then
			local step=P().grid.size or 8
			x=roundToStep(x,step); y=roundToStep(y,step)
			cfg.x, cfg.y = x,y
		end
		f:SetPoint(cfg.point, rel, cfg.relPoint, x, y)
	end
	if cfg.locked then
		if f.EnableMouse then f:EnableMouse(false) end
		if f.SetMovable then f:SetMovable(false) end
		if f.RegisterForDrag then f:RegisterForDrag() end
	else
		if f.EnableMouse then f:EnableMouse(true) end
		if f.SetMovable then f:SetMovable(true) end
		if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
		f:SetScript("OnDragStart", function(self) if not cfg.locked then self:StartMoving() end end)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local p, rel, rp, x, y = self:GetPoint()
			if P().grid.enabled then
				local step=P().grid.size or 8
				x=roundToStep(x or 0, step); y=roundToStep(y or 0, step)
			end
			cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p,(rel and rel:GetName()) or "UIParent", rp, x or 0, y or 0
			ApplyFrameConfig(self, cfg) -- моментально применяем, чтобы не "отпрыгивал"
		end)
	end
end

------------------------------------------------------------
-- Режим перемещения (оверлеи)
------------------------------------------------------------
local MoveMode = false
local Handles = {}

local function CreateHandle(targetFrame, title, onDrop)
  local h = CreateFrame("Frame", nil, UIParent)
  h:SetFrameStrata("TOOLTIP")

  local w  = (targetFrame.GetWidth and targetFrame:GetWidth() or 100) * (targetFrame.GetScale and targetFrame:GetScale() or 1)
  local ht = (targetFrame.GetHeight and targetFrame:GetHeight() or 40) * (targetFrame.GetScale and targetFrame:GetScale() or 1)
  h:SetSize(math.max(40,w), math.max(20,ht))
  h:SetPoint("CENTER", targetFrame, "CENTER")

  local bg=h:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\WHITE8x8"); bg:SetVertexColor(1,1,1,0.08)
  local br=h:CreateTexture(nil,"BORDER"); br:SetAllPoints(); br:SetTexture("Interface\\Buttons\\WHITE8x8"); br:SetVertexColor(1,0.82,0,0.35); br:SetBlendMode("ADD")
  local t=h:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); t:SetText(title or ""); t:SetPoint("TOP",0,-2)

  -- гарантируем, что таргет можно двигать мышью
  if targetFrame.SetMovable then targetFrame:SetMovable(true) end
  if targetFrame.EnableMouse then targetFrame:EnableMouse(true) end
  if targetFrame.SetClampedToScreen then targetFrame:SetClampedToScreen(true) end

  h:EnableMouse(true); h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    -- двигаем именно цель
    if targetFrame.StartMoving then targetFrame:StartMoving() end
  end)

  h:SetScript("OnDragStop", function(self)
    if targetFrame.StopMovingOrSizing then targetFrame:StopMovingOrSizing() end
    if onDrop then onDrop(self) end
    self:ClearAllPoints()
    self:SetPoint("CENTER", targetFrame, "CENTER")
  end)

  h:Show()
  return h
end

local function UpdateHandles()
	for _,list in pairs(Handles) do for _,h in ipairs(list) do if h then h:Hide() end end end
	if not MoveMode then return end
	for _, item in ipairs(Registry.Widgets) do
		local frames = GetWidgetFrames(item.module, item.widget, item.get)
		if #frames>0 then
			local key = item.module.."|"..(item.widget or "MODULE")
			Handles[key]=Handles[key] or {}
			for i=#Handles[key],1,-1 do Handles[key][i]:Hide(); Handles[key][i]=nil end
			for idx,f in ipairs(frames) do
				local cfgKey=item.module.."||"..(item.widget or "MODULE").."||"..idx
				local cfg=P().frames[cfgKey] or {}; P().frames[cfgKey]=cfg
				if not cfg.point then
					local p,rn,rp,x,y=ReadPoint(f)
					cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p,rn,rp,x,y
					cfg.scale=cfg.scale or (call(f,"GetScale") or 1.0)
					cfg.locked = not not cfg.locked
				end
				ApplyFrameConfig(f,cfg)
				local title=(item.title or (item.module.." / "..(item.widget or "Module"))).." ["..idx.."]"
				local handle=CreateHandle(f,title,function()
					local p, rel, rp, x, y = f:GetPoint()
					if P().grid.enabled then local step=P().grid.size or 8; x=roundToStep(x or 0,step); y=roundToStep(y or 0,step) end
					cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p,(rel and rel:GetName()) or "UIParent", rp, x or 0, y or 0
					ApplyFrameConfig(f,cfg)
				end)
				table.insert(Handles[key], handle)
			end
		end
	end
end

SLASH_DIO_MOVE1="/diomove"
SlashCmdList["DIO_MOVE"]=function()
  if InCombatLockdown() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DiabolicUI:|r Нельзя включить режим переноса в бою.")
    return
  end
  MoveMode = not MoveMode
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DiabolicUI:|r Move Mode " .. (MoveMode and "|cffffff00ON|r" or "|cffff0000OFF|r"))
  UpdateHandles()
  UpdateGridOverlay()
end

local combatEv = CreateFrame("Frame")
combatEv:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEv:SetScript("OnEvent", function()
  if MoveMode then
    UpdateHandles()
    UpdateGridOverlay()
  end
end)

------------------------------------------------------------
-- GUI: панель в Интерфейсе (с вкладками и прокруткой)
------------------------------------------------------------
local function MakeButton(parent,text,cb,w,h)
	local b=CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetText(text or ""); b:SetWidth(w or 140); b:SetHeight(h or 22)
	if cb then b:SetScript("OnClick", cb) end
	return b
end

local function MakeCheck(parent,label,onClick)
	local b=CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	local name=b:GetName(); local txt=name and _G[name.."Text"]
	if not txt then txt=parent:CreateFontString(nil,"ARTWORK","GameFontHighlight"); txt:SetPoint("LEFT", b, "RIGHT", 2, 0) end
	b.text=txt; b.text:SetText(label or "")
	if onClick then b:SetScript("OnClick", function(self) onClick(self:GetChecked()) end) end
	return b
end

local function MakeSlider(parent,label,minV,maxV,step,onVal)
	local s=CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	s:SetWidth(220)
	local Lbl=parent:CreateFontString(nil,"ARTWORK","GameFontNormal"); Lbl:SetText(label or ""); Lbl:SetPoint("BOTTOM", s, "TOP", 0, 2); s.label=Lbl
	s:SetMinMaxValues(minV or 0, maxV or 100); if s.SetValueStep then s:SetValueStep(step or 1) end
	local snapping=false
	s:SetScript("OnValueChanged", function(self,val)
		local mn,mx=self:GetMinMaxValues(); local st=step or 1
		local snap=mn+math.floor(((val-mn)/st)+0.5)*st; if snap<mn then snap=mn elseif snap>mx then snap=mx end
		if snap~=val then if not snapping then snapping=true; self:SetValue(snap); snapping=false end; val=snap end
		if onVal then onVal(val) end
	end)
	return s
end

-- сама панель
local Panel=CreateFrame("Frame","DiabolicUI_OptionsPanel",UIParent)
Panel.name="DiabolicUI"
InterfaceOptions_AddCategory(Panel)

-- Вкладки
local Tabs = CreateFrame("Frame", nil, Panel)
Tabs:SetPoint("TOPLEFT", 16, -16)
Tabs:SetSize(400, 24)

local TabMain = CreateFrame("Button", nil, Tabs, "UIPanelButtonTemplate")
TabMain:SetText("Основные"); TabMain:SetSize(120, 22)
TabMain:SetPoint("TOPLEFT")

local TabAdv  = CreateFrame("Button", nil, Tabs, "UIPanelButtonTemplate")
TabAdv:SetText("Дополнительно"); TabAdv:SetSize(140, 22)
TabAdv:SetPoint("LEFT", TabMain, "RIGHT", 6, 0)

-- Подстраницы
local PageMain = CreateFrame("Frame", nil, Panel)
PageMain:SetPoint("TOPLEFT", 16, -48)
PageMain:SetPoint("BOTTOMRIGHT", -36, 16)

local PageAdv  = CreateFrame("Frame", nil, Panel)
PageAdv:SetPoint("TOPLEFT", 16, -48)
PageAdv:SetPoint("BOTTOMRIGHT", -36, 16)
PageAdv:Hide()

-- Прокрутка на обеих страницах
local function MakeScroll(parent, globalName)
  if not globalName then
    local base = (parent:GetName() or "DiabolicUI") .. "_Scroll"
    local i=1
    while _G[base..i] do i=i+1 end
    globalName = base..i
  end
  local sf = CreateFrame("ScrollFrame", globalName, parent, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", 0, 0)
  local content = CreateFrame("Frame", globalName.."_Content", sf)
  content:SetSize(1,1)
  sf:SetScrollChild(content)
  return sf, content
end

local SMain, CMain = MakeScroll(PageMain, "DiabolicUI_OptionsMainScroll")
local SAdv,  CAdv  = MakeScroll(PageAdv,  "DiabolicUI_OptionsAdvScroll")

-- переключение вкладок
local function ShowMain() PageMain:Show(); PageAdv:Hide() end
local function ShowAdv()  PageMain:Hide(); PageAdv:Show() end
TabMain:SetScript("OnClick", ShowMain)
TabAdv:SetScript("OnClick",  ShowAdv)

-- --------- Содержимое "Основные"
local y = 6

local title=CMain:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
title:SetPoint("TOPLEFT",6,-y); title:SetText("DiabolicUI — Настройки")
y = y + 24

local btnMove=MakeButton(CMain,"Режим перемещения (/diomove)", function() SlashCmdList["DIO_MOVE"]() end, 240)
btnMove:SetPoint("TOPLEFT", 6, -y)

local btnApply=MakeButton(CMain,"Применить", function()
	for _, item in ipairs(Registry.Widgets) do
		local frames=GetWidgetFrames(item.module,item.widget,item.get)
		for idx,f in ipairs(frames) do
			local key=item.module.."||"..(item.widget or "MODULE").."||"..idx
			local cfg=P().frames[key]; if cfg then ApplyFrameConfig(f,cfg) end
		end
	end
	UpdateHandles(); UpdateGridOverlay()
end, 120)
btnApply:SetPoint("LEFT", btnMove, "RIGHT", 8, 0)

local btnReset=MakeButton(CMain,"Сброс профиля", function()
	local name=ActiveProfileName()
	DiabolicUI_OptionsDB.profiles[name]={ frames={}, modules={}, grid={enabled=false,size=8,show=false} }
	UpdateGridOverlay()
end, 140)
btnReset:SetPoint("LEFT", btnApply, "RIGHT", 8, 0)
y = y + 30

-- Профили
local profLabel=CMain:CreateFontString(nil,"ARTWORK","GameFontNormal")
profLabel:SetPoint("TOPLEFT", 6, -y); profLabel:SetText("Профили")
y = y + 22

local profEdit=CreateFrame("EditBox", nil, CMain, "InputBoxTemplate")
profEdit:SetAutoFocus(false); profEdit:SetSize(180,20); profEdit:SetPoint("TOPLEFT", 6, -y)

local btnProfSet=MakeButton(CMain,"Создать/Активировать", function()
	local name=profEdit:GetText(); if not name or name=="" then return end
	EnsureProfile(name)
	DiabolicUI_OptionsDB.perChar[PerCharKey()] = DiabolicUI_OptionsDB.perChar[PerCharKey()] or {}
	DiabolicUI_OptionsDB.perChar[PerCharKey()].activeProfile=name
	UpdateGridOverlay()
end, 180)
btnProfSet:SetPoint("LEFT", profEdit, "RIGHT", 6, 0)

local btnProfDel=MakeButton(CMain,"Удалить", function()
	local name=profEdit:GetText(); if not name or name=="" then return end
	if name==ActiveProfileName() then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Нельзя удалить активный профиль|r"); return end
	DiabolicUI_OptionsDB.profiles[name]=nil
end, 100)
btnProfDel:SetPoint("LEFT", btnProfSet, "RIGHT", 6, 0)
y = y + 36

-- Импорт/Экспорт
local ieLabel=CMain:CreateFontString(nil,"ARTWORK","GameFontNormal")
ieLabel:SetPoint("TOPLEFT", 6, -y); ieLabel:SetText("Импорт / Экспорт:")
y = y + 18

local box=CreateFrame("Frame", nil, CMain, "OptionsBoxTemplate")
box:SetPoint("TOPLEFT", 6, -y); box:SetSize(520, 120)

local scrollIE = CreateFrame("ScrollFrame", "DiabolicUI_OptionsIE_Scroll", box, "UIPanelScrollFrameTemplate")
scrollIE:SetPoint("TOPLEFT",4,-6); scrollIE:SetPoint("BOTTOMRIGHT",-28,6)
local ieEdit   = CreateFrame("EditBox", "DiabolicUI_OptionsIE_Edit", scrollIE)
ieEdit:SetMultiLine(true); ieEdit:SetAutoFocus(false); ieEdit:SetFontObject(ChatFontNormal); ieEdit:SetWidth(480)
scrollIE:SetScrollChild(ieEdit)

local function Serialize(tbl, indent)
	indent=indent or ""; local out={"{"}; local first=true
	for k,v in pairs(tbl) do
		if not first then table.insert(out,",") end; first=false
		local key=(type(k)=="string" and k:match("^[%a_][%w_]*$")) and k or ("["..string.format("%q",k).."]")
		local vt=type(v); local val
		if vt=="table" then val=Serialize(v, indent.."  ")
		elseif vt=="string" then val=string.format("%q", v)
		elseif vt=="number" or vt=="boolean" then val=tostring(v)
		else val="nil" end
		table.insert(out, "\n"..indent.."  "..key.."="..val)
	end
	table.insert(out, "\n"..indent.."}"); return table.concat(out,"")
end
local function Deserialize(str)
	if not str or str=="" then return nil,"empty" end
	local chunk,err=loadstring("return "..str); if not chunk then return nil,err end
	local ok,tbl=pcall(chunk); if not ok then return nil,tbl end
	if type(tbl)~="table" then return nil,"not a table" end
	return tbl
end

local btnExport=MakeButton(CMain,"Экспорт", function() ieEdit:SetText(Serialize(P())); ieEdit:HighlightText() end)
btnExport:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)

local btnImport=MakeButton(CMain,"Импорт (заменить активный)", function()
	local tbl,err=Deserialize(ieEdit:GetText())
	if not tbl then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Импорт не удался:|r "..tostring(err)); return end
	DiabolicUI_OptionsDB.profiles[ActiveProfileName()] = tbl; UpdateGridOverlay()
end)
btnImport:SetPoint("LEFT", btnExport, "RIGHT", 8, 0)
y = y + 120 + 12 + 26

-- Модули (вкл/выкл)
local modLabel=CMain:CreateFontString(nil,"ARTWORK","GameFontNormal")
modLabel:SetPoint("TOPLEFT", 6, -y); modLabel:SetText("Модули:")
y = y + 22

local xOff = 6
for _, modName in ipairs(Registry.Modules) do
	local mod=Engine:GetModule(modName, true)
	if mod then
		local chk=MakeCheck(CMain, modName, function(val)
			local prof=P(); prof.modules[modName]=not not val
			if val then mod:Enable() else mod:Disable() end
		end)
		chk:SetPoint("TOPLEFT", xOff, -y)
		local initial=P().modules[modName]; if initial==nil then initial=true end
		chk:SetChecked(initial)

		xOff = xOff + 160
		if xOff > 480 then xOff=6; y=y+26 end
	end
end
y = y + 30

-- Список элементов с прокруткой
local elemsLabel=CMain:CreateFontString(nil,"ARTWORK","GameFontNormal")
elemsLabel:SetPoint("TOPLEFT", 6, -y); elemsLabel:SetText("Элементы (позиция/масштаб/замок):")
y = y + 20

local ListBox = CreateFrame("Frame", "DiabolicUI_OptionsMain_ListBox", CMain, "OptionsBoxTemplate")
ListBox:SetPoint("TOPLEFT", 6, -y); ListBox:SetSize(620, 220)

local ListScroll = CreateFrame("ScrollFrame", "DiabolicUI_OptionsMain_ListScroll", ListBox, "UIPanelScrollFrameTemplate")
ListScroll:SetPoint("TOPLEFT", 4, -6); ListScroll:SetPoint("BOTTOMRIGHT", -28, 6)

local ListContent = CreateFrame("Frame", "DiabolicUI_OptionsMain_ListScrollContent", ListScroll)
ListContent:SetSize(1,1)
ListScroll:SetScrollChild(ListContent)

local function stepForNudge() return P().grid.enabled and (P().grid.size or 8) or 1 end

local function DrawRows(parent)
	local oy=0
	for _,item in ipairs(Registry.Widgets) do
		local frames=GetWidgetFrames(item.module, item.widget, item.get)
		if #frames>0 then
			for idx,f in ipairs(frames) do
				local row=CreateFrame("Frame", nil, parent); row:SetSize(580,48)
				row:SetPoint("TOPLEFT", 0, -oy); oy = oy + 50

				local name=(item.title or (item.module.." / "..(item.widget or "Module"))).." ["..idx.."]"
				local label=row:CreateFontString(nil,"ARTWORK","GameFontHighlight")
				label:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2); label:SetText(name)

				local key=item.module.."||"..(item.widget or "MODULE").."||"..idx
				local cfg=P().frames[key] or {}; P().frames[key]=cfg
				if not cfg.point then
					local p,rn,rp,x,y=ReadPoint(f)
					cfg.point,cfg.rel,cfg.relPoint,cfg.x,cfg.y=p,rn,rp,x,y
					cfg.scale=cfg.scale or (call(f,"GetScale") or 1.0)
					cfg.locked = not not cfg.locked
				end

				local chk=MakeCheck(row,"Lock", function(v) cfg.locked=not not v; ApplyFrameConfig(f,cfg) end)
				chk:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, -2); chk:SetChecked(cfg.locked)

				local s=MakeSlider(row, "Scale", 0.5, 2.0, 0.01, function(v)
					cfg.scale=tonumber(string.format("%.2f",v)) or 1.0; ApplyFrameConfig(f,cfg)
				end)
				s:SetPoint("TOPLEFT", chk, "BOTTOMLEFT", 0, -8); s:SetValue(cfg.scale or 1.0)

				local bU=MakeButton(row,"▲", function() local st=stepForNudge(); cfg.y=(cfg.y or 0)+st; ApplyFrameConfig(f,cfg) end, 24, 20)
				bU:SetPoint("LEFT", s, "RIGHT", 8, 0)
				local bD=MakeButton(row,"▼", function() local st=stepForNudge(); cfg.y=(cfg.y or 0)-st; ApplyFrameConfig(f,cfg) end, 24, 20)
				bD:SetPoint("LEFT", bU, "RIGHT", 2, 0)
				local bL=MakeButton(row,"◄", function() local st=stepForNudge(); cfg.x=(cfg.x or 0)-st; ApplyFrameConfig(f,cfg) end, 24, 20)
				bL:SetPoint("LEFT", bD, "RIGHT", 2, 0)
				local bR=MakeButton(row,"►", function() local st=stepForNudge(); cfg.x=(cfg.x or 0)+st; ApplyFrameConfig(f,cfg) end, 24, 20)
				bR:SetPoint("LEFT", bL, "RIGHT", 2, 0)
			end
		end
	end
	parent:SetHeight(oy+6)
end

DrawRows(ListContent)
y = y + 220 + 16
CMain:SetHeight(y)

-- --------- Содержимое "Дополнительно" (сетка)
local yy = 6
local gridTitle=CAdv:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
gridTitle:SetPoint("TOPLEFT",6,-yy); gridTitle:SetText("Дополнительно")
yy = yy + 26

local gridLabel=CAdv:CreateFontString(nil,"ARTWORK","GameFontNormal")
gridLabel:SetPoint("TOPLEFT", 6, -yy); gridLabel:SetText("Сетка (snap‑to‑grid)")
yy = yy + 20

local chkSnap=MakeCheck(CAdv,"Snap to grid", function(v) P().grid.enabled = not not v end)
chkSnap:SetPoint("TOPLEFT", 6, -yy)

local sGrid=MakeSlider(CAdv,"Размер сетки (px)",2,64,1, function(val)
	P().grid.size = math.floor(val+0.5); UpdateGridOverlay()
end)
sGrid:SetPoint("TOPLEFT", chkSnap, "BOTTOMLEFT", 0, -12)

local chkShowGrid=MakeCheck(CAdv,"Показывать сетку", function(v) P().grid.show = not not v; UpdateGridOverlay() end)
chkShowGrid:SetPoint("LEFT", sGrid, "RIGHT", 16, -12)
yy = yy + 80

local note=CAdv:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
note:SetPoint("TOPLEFT", 6, -yy)
note:SetText("Примечание: сетка влияет только на сохранение позиции при отпускании фрейма.\nРежим переноса: /diomove или кнопка у миникарты (ПКМ).")
yy = yy + 36

CAdv:SetHeight(yy)

-- Заполнение актуальными значениями при открытии панели
Panel:SetScript("OnShow", function()
	for _,mName in ipairs(Registry.Modules) do
		local m=Engine:GetModule(mName, true)
		if m then
			local st=P().modules[mName]; if st==nil then st=true end
			if st then m:Enable() else m:Disable() end
		end
	end
	chkSnap:SetChecked(P().grid.enabled)
	sGrid:SetValue(P().grid.size or 8)
	chkShowGrid:SetChecked(P().grid.show)
	UpdateGridOverlay()
end)

-- Открытие панели слэшем
SLASH_DIO_UI1="/dioui"
SlashCmdList["DIO_UI"]=function()
	InterfaceOptionsFrame_OpenToCategory(Panel)
	InterfaceOptionsFrame_OpenToCategory(Panel) -- LK баг
end

-- Автоприменение позиций после входа
local ev=CreateFrame("Frame"); ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	for _, item in ipairs(Registry.Widgets) do
		local frames=GetWidgetFrames(item.module,item.widget,item.get)
		for idx,f in ipairs(frames) do
			local key=item.module.."||"..(item.widget or "MODULE").."||"..idx
			local cfg=P().frames[key]; if cfg then ApplyFrameConfig(f,cfg) end
		end
	end
	UpdateGridOverlay()
end)

------------------------------------------------------------
-- Кнопка у миникарты (иконка аддона) — с защитой от дублей
------------------------------------------------------------
do
	-- per-char мини‑настройки
	local pc = DiabolicUI_OptionsDB.perChar
	local key= PerCharKey()
	pc[key] = pc[key] or {}
	pc[key].mini = pc[key].mini or { angle = 210, radius = 78, hide = false }
	local C = pc[key].mini

	-- либо переиспользуем существующую, либо создаём
	local btn = _G.DiabolicUI_MinimapButton
	if not btn then
		btn = CreateFrame("Button", "DiabolicUI_MinimapButton", Minimap)
		btn:SetSize(31,31) btn:SetFrameStrata("MEDIUM") btn:SetFrameLevel(8)

		local border = btn:CreateTexture(nil,"OVERLAY")
		border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		border:SetSize(54,54) border:SetPoint("TOPLEFT")

		local icon = btn:CreateTexture(nil,"ARTWORK")
		icon:SetTexture("Interface\\AddOns\\DiabolicUI\\media\\textures\\cogs")
		icon:SetSize(20,20) icon:SetPoint("CENTER")

		btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	end

	local function Place(b)
		local a = math.rad(C.angle or 210)
		local x = math.cos(a) * (C.radius or 78)
		local y = math.sin(a) * (C.radius or 78)
		b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	btn:RegisterForClicks("AnyUp")
	btn:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			InterfaceOptionsFrame_OpenToCategory(Panel)
			InterfaceOptionsFrame_OpenToCategory(Panel)
		else
			SlashCmdList["DIO_MOVE"]()
		end
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cffffcc00DiabolicUI|r")
		GameTooltip:AddLine("ЛКМ: открыть настройки", 0,.8,0)
		GameTooltip:AddLine("ПКМ: режим перемещения", 0,.8,0)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- перетаскивание по окружности
	btn:SetMovable(true) btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnDragStart", function(self) self:StartMoving() end)
	btn:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local mx,my = Minimap:GetCenter()
	 local bx,by = self:GetCenter()
	 local s = Minimap:GetEffectiveScale()/UIParent:GetEffectiveScale()
		mx,my,bx,by = mx*s,my*s,bx*s,by*s
		local ang = math.deg(math.atan2(by - my, bx - mx)); if ang < 0 then ang = ang + 360 end
		C.angle = math.floor(ang + 0.5)
		Place(self)
	end)

	btn:SetScript("OnShow", function(self) Place(self) end)
	if C.hide then btn:Hide() else Place(btn) end

	SLASH_DIO_MB1="/diomb"
	SlashCmdList.DIO_MB=function()
		if btn:IsShown() then C.hide=true; btn:Hide() else C.hide=false; btn:Show(); Place(btn) end
	end
end

------------------------------------------------------------
-- Экспорт полезных функций
------------------------------------------------------------
Options.GetProfile   = P
Options.ApplyFrame   = ApplyFrameConfig
Options.UpdateGrid   = UpdateGridOverlay
Options.ToggleMove   = function() SlashCmdList["DIO_MOVE"]() end
Options.ActiveProfileName = ActiveProfileName
