-- DiabolicUI/modules/options/movers.lua
local Addon, Engine = ...
local Movers = Engine:NewModule("Movers")

-- публичный реестр перемещаемых фреймов
local REG = {} -- { [key] = { title=..., get = function() return frame(s) end } }
-- вызов из модулей: DiabolicUI_RegisterMovable("ActionBars","Bar: 1","Панель 1", function() return frame end)
function _G.DiabolicUI_RegisterMovable(moduleName, widgetName, title, getter)
  local key = moduleName.."||"..(widgetName or "MODULE")
  REG[key] = REG[key] or {}
  table.insert(REG[key], { title = title or key, get = getter })
end

-- персонажная БД
local function DB() _G.DiabolicUI_CharDB = _G.DiabolicUI_CharDB or { profile="Default", profiles={} }
  local p = _G.DiabolicUI_CharDB.profile or "Default"
  _G.DiabolicUI_CharDB.profiles[p] = _G.DiabolicUI_CharDB.profiles[p] or { grid={enabled=false,size=8,show=false}, frames={} }
  local prof = _G.DiabolicUI_CharDB.profiles[p]
  prof.grid.size = prof.grid.size or 8
  return _G.DiabolicUI_CharDB, prof
end

local function RoundStep(v, step)
  if not step or step <= 1 then return v end
  local h = step/2
  if v >= 0 then return math.floor((v+h)/step)*step else return math.ceil((v-h)/step)*step end
end

-- сетка
local Grid = { f=nil, V={}, H={} }
local function UpdateGrid()
  local _, prof = DB()
  if not prof.grid.show then if Grid.f then Grid.f:Hide() end return end
  local size = prof.grid.size or 8
  if not Grid.f then Grid.f = CreateFrame("Frame", "DiabolicUI_MoveGrid", UIParent)
    Grid.f:SetAllPoints(UIParent) Grid.f:SetFrameStrata("TOOLTIP") end
  local w,h = UIParent:GetWidth(), UIParent:GetHeight()
  local needV, needH = math.floor(w/size), math.floor(h/size)
  -- V
  for i=1,needV do
    if not Grid.V[i] then
      local t = Grid.f:CreateTexture(nil, "ARTWORK")
      t:SetTexture("Interface\\Buttons\\WHITE8x8") t:SetVertexColor(1,1,1,.08)
      Grid.V[i] = t
    end
    local x = i*size
    local t = Grid.V[i]; t:ClearAllPoints()
    t:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
    t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
    t:SetWidth(1); t:Show()
  end
  for i=needV+1,#Grid.V do if Grid.V[i] then Grid.V[i]:Hide() end end
  -- H
  for i=1,needH do
    if not Grid.H[i] then
      local t = Grid.f:CreateTexture(nil, "ARTWORK")
      t:SetTexture("Interface\\Buttons\\WHITE8x8") t:SetVertexColor(1,1,1,.08)
      Grid.H[i] = t
    end
    local y = -i*size
    local t = Grid.H[i]; t:ClearAllPoints()
    t:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, y)
    t:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, y)
    t:SetHeight(1); t:Show()
  end
  for i=needH+1,#Grid.H do if Grid.H[i] then Grid.H[i]:Hide() end end
  Grid.f:Show()
end
Movers.UpdateGrid = UpdateGrid

-- применение конфига
local function ApplyFrame(frame, cfg)
  if not frame or not frame.SetPoint then return end
  if cfg.scale and frame.SetScale then frame:SetScale(cfg.scale) end
  if cfg.point and cfg.rel and cfg.relPoint then
    frame:ClearAllPoints()
    local rel = _G[cfg.rel] or UIParent
    local x,y = cfg.x or 0, cfg.y or 0
    local _, prof = DB()
    if prof.grid.enabled then local step=prof.grid.size or 8; x=RoundStep(x,step); y=RoundStep(y,step) end
    frame:SetPoint(cfg.point, rel, cfg.relPoint, x, y)
  end
  if cfg.locked then
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.SetMovable then frame:SetMovable(false) end
    if frame.RegisterForDrag then frame:RegisterForDrag() end
  else
    if frame.EnableMouse then frame:EnableMouse(true) end
    if frame.SetMovable then frame:SetMovable(true) end
    if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
    frame:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local p, rel, rp, x, y = self:GetPoint()
      local db, prof = DB()
      if prof.grid.enabled then local step=prof.grid.size or 8; x=RoundStep(x or 0,step); y=RoundStep(y or 0,step) end
      cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p, (rel and rel:GetName()) or "UIParent", rp, x or 0, y or 0
      -- сохраняем и сразу применяем (чтобы “не отпрыгивал”)
      ApplyFrame(self, cfg)
    end)
  end
end
Movers.ApplyFrame = ApplyFrame

-- ручки‑оверлеи
local MoveMode, Handles = false, {}
local function NewHandle(target, title, onDrop)
  local h = CreateFrame("Frame", nil, UIParent)
  h:SetFrameStrata("TOOLTIP")
  local w = (target.GetWidth and target:GetWidth() or 100) * (target.GetScale and target:GetScale() or 1)
  local ht= (target.GetHeight and target:GetHeight() or 40) * (target.GetScale and target:GetScale() or 1)
  h:SetSize(math.max(40,w), math.max(20,ht))
  h:SetPoint("CENTER", target, "CENTER")
  local bg=h:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\WHITE8x8"); bg:SetVertexColor(1,1,1,.08)
  local br=h:CreateTexture(nil,"BORDER"); br:SetAllPoints(); br:SetTexture("Interface\\Buttons\\WHITE8x8"); br:SetVertexColor(1,.82,0,.35); br:SetBlendMode("ADD")
  local t=h:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); t:SetText(title or ""); t:SetPoint("TOP",0,-2)
  h:EnableMouse(true); h:SetMovable(true); h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function(self) self:StartMoving() end)
  h:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); if onDrop then onDrop(self) end; self:ClearAllPoints(); self:SetPoint("CENTER", target, "CENTER") end)
  return h
end

local function ReadPoint(f) local p,rel,rp,x,y=f:GetPoint() return p or "CENTER",(rel and rel:GetName()) or "UIParent", rp or "CENTER", x or 0, y or 0 end

local function BuildHandles()
  for k,list in pairs(Handles) do for _,h in ipairs(list) do if h then h:Hide() end end end
  if not MoveMode then return end
  local db, prof = DB()
  for key,entries in pairs(REG) do
    Handles[key] = {}
    for idx,entry in ipairs(entries) do
      local frames = { entry.get() }
      for i,f in ipairs(frames) do
        if f then
          local cfgKey = key.."||"..i
          prof.frames[cfgKey] = prof.frames[cfgKey] or {}
          local cfg = prof.frames[cfgKey]
          if not cfg.point then local p,rn,rp,x,y=ReadPoint(f); cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p,rn,rp,x,y; cfg.scale = cfg.scale or (f.GetScale and f:GetScale() or 1) end
          ApplyFrame(f, cfg)
          local title = (entry.title or key).." ["..i.."]"
          local h = NewHandle(f, title, function()
            local p, rel, rp, x, y = f:GetPoint()
            if prof.grid.enabled then local step=prof.grid.size or 8; x=RoundStep(x or 0,step); y=RoundStep(y or 0,step) end
            cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p,(rel and rel:GetName()) or "UIParent", rp, x or 0, y or 0
            ApplyFrame(f, cfg)
          end)
          table.insert(Handles[key], h)
        end
      end
    end
  end
end

SLASH_DIO_MOVE1 = "/diomove"
SlashCmdList.DIO_MOVE = function()
  MoveMode = not MoveMode
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DiabolicUI:|r Move Mode " .. (MoveMode and "|cffffff00ON|r" or "|cffff0000OFF|r"))
  BuildHandles() UpdateGrid()
end

Movers.ToggleMove = function() SlashCmdList.DIO_MOVE() end

Movers.SetGridEnabled = function(on) local _,p=DB(); p.grid.enabled = not not on end
Movers.SetGridShown   = function(on) local _,p=DB(); p.grid.show    = not not on; UpdateGrid() end
Movers.SetGridSize    = function(sz) local _,p=DB(); p.grid.size    = math.max(2, math.floor(sz or 8)); UpdateGrid() end

Movers.GetProfile = function()
  local db,p=DB(); return p
end

local ev=CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local _, p = DB()
  -- автоприменение позиций
  for key, entries in pairs(REG) do
    for idx,entry in ipairs(entries) do
      local frames = { entry.get() }
      for i,f in ipairs(frames) do
        if f then
          local cfg = p.frames[key.."||"..i]
          if cfg then ApplyFrame(f, cfg) end
        end
      end
    end
  end
  UpdateGrid()
end)

-- экспортируем модуль
Engine.Movers = Movers
