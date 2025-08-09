-- DiabolicUI/modules/moveframes/moveframes.lua
-- Универсальный менеджер перемещения фреймов (Wrath 3.3.5a)

local Addon, Engine = ...
local M = {}
Engine.MoveFrames = M

-- ========= SavedVariables =========
DiabolicUI_OptionsDB = DiabolicUI_OptionsDB or { version=1, profiles={}, perChar={} }

local function PerCharKey()
  local realm = GetRealmName() or "DefaultRealm"
  local name  = UnitName("player") or "Player"
  return realm.." - "..name
end

local function ActiveProfileName()
  local pc = DiabolicUI_OptionsDB.perChar
  local key = PerCharKey()
  pc[key] = pc[key] or { activeProfile = "Default" }
  return pc[key].activeProfile or "Default"
end

local function EnsureProfile(name)
  local db = DiabolicUI_OptionsDB
  db.profiles[name] = db.profiles[name] or {
    frames  = {},                  -- сохранённые точки/масштаб/замок
    modules = {},
    grid    = { enabled=false, size=8, show=false }
  }
  local p = db.profiles[name]
  p.grid.size    = p.grid.size or 8
  p.grid.enabled = not not p.grid.enabled
  p.grid.show    = not not p.grid.show
  return p
end

local function P() return EnsureProfile(ActiveProfileName()) end

-- ========= Реестр виджетов =========
-- Базовый набор (можно дополнять из модулей)
local Registry = {
  Widgets = {
    -- ActionBars
    { module="ActionBars", widget="Controller: Main",  title="Контроллер: Main"  },
    { module="ActionBars", widget="Controller: Side",  title="Контроллер: Side"  },
    { module="ActionBars", widget="Bar: 1", title="Панель 1" },
    { module="ActionBars", widget="Bar: 2", title="Панель 2" },
    { module="ActionBars", widget="Bar: 3", title="Панель 3" },
    { module="ActionBars", widget="Bar: 4", title="Панель 4" },
    { module="ActionBars", widget="Bar: 5", title="Панель 5" },
    { module="ActionBars", widget="Bar: XP", title="Панель опыта" },
    { module="ActionBars", widget="Bar: Pet", title="Панель питомца" },
    { module="ActionBars", widget="Bar: Stance", title="Панель стоек" },
    { module="ActionBars", widget="Bar: Vehicle", title="Панель транспорта" },

    -- Minimap
    { module="Minimap", widget=nil, title="Миникарта", get=function(mod)
        local f = mod.GetFrame and mod:GetFrame(); return f and { f } or {}
      end },

    -- UnitFrames
    { module="UnitFrames", widget="Unit: Player", title="Фрейм игрока" },
    { module="UnitFrames", widget="Unit: Target", title="Фрейм цели"  },
    { module="UnitFrames", widget="Unit: Focus",  title="Фрейм фокуса"},
    { module="UnitFrames", widget="Unit: ToT",    title="Цель цели"   },
    { module="UnitFrames", widget="Unit: Pet",    title="Фрейм питомца"},
  }
}

-- Публичное API для регистрации ДОП. якорей из любых модулей:
-- DiabolicUI_RegisterMovable("CastBars", "Игрок: полоса каста", function(mod) return mod:GetWidget("CastBar: Player"):GetFrame() end, "CastBar: Player")
_G.DiabolicUI_RegisterMovable = function(moduleName, title, getFramesFunc, widgetName)
  table.insert(Registry.Widgets, { module=moduleName, title=title, get=getFramesFunc, widget=widgetName })
end

-- ========= Утилиты =========
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
    local f = call(mod, "GetFrame"); return f and { f } or {}
  end

  local w = call(mod, "GetWidget", widgetName); if not w then return {} end
  if w.GetFrame then
    local a,b,c = w:GetFrame(); local t={}
    if a then t[#t+1]=a end; if b then t[#t+1]=b end; if c then t[#t+1]=c end
    return t
  end
  return {}
end

local function readPoint(f)
  local p, rel, rp, x, y = f:GetPoint()
  return p or "CENTER", (rel and rel:GetName()) or "UIParent", rp or "CENTER", x or 0, y or 0
end

local function roundStep(v, step)
  if not step or step<=1 then return v end
  local h = step*0.5
  if v>=0 then return math.floor((v+h)/step)*step else return math.ceil((v-h)/step)*step end
end

-- ========= Сетка =========
local Grid = { frame=nil, V={}, H={} }

local function UpdateGrid()
  local prof=P()
  if not prof.grid.show then if Grid.frame then Grid.frame:Hide() end; return end
  local size = prof.grid.size or 8
  if not Grid.frame then
    Grid.frame = CreateFrame("Frame","DiabolicUI_MoveGrid",UIParent)
    Grid.frame:SetFrameStrata("TOOLTIP")
    Grid.frame:SetAllPoints()
  end
  local w,h = UIParent:GetWidth(), UIParent:GetHeight()
  local needV, needH = math.floor(w/size), math.floor(h/size)

  for i=1,needV do
    if not Grid.V[i] then
      local t=Grid.frame:CreateTexture(nil,"ARTWORK")
      t:SetTexture("Interface\\Buttons\\WHITE8x8")
      t:SetVertexColor(1,1,1,.08)
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
      t:SetVertexColor(1,1,1,.08)
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

-- ========= Применение конфигурации к фрейму =========
local function ApplyFrame(f, cfg)
  if not (f and f.SetPoint) then return end
  if cfg.scale and f.SetScale then f:SetScale(cfg.scale) end
  if cfg.point and cfg.rel and cfg.relPoint then
    f:ClearAllPoints()
    local rel = _G[cfg.rel] or UIParent
    local x,y = cfg.x or 0, cfg.y or 0
    if P().grid.enabled then
      local step=P().grid.size or 8
      x=roundStep(x,step); y=roundStep(y,step)
      cfg.x, cfg.y = x,y
    end
    f:SetPoint(cfg.point, rel, cfg.relPoint, x, y)
    if f.SetUserPlaced then f:SetUserPlaced(true) end
  end

  if cfg.locked then
    if f.EnableMouse then f:EnableMouse(false) end
    if f.SetMovable then f:SetMovable(false) end
    if f.RegisterForDrag then f:RegisterForDrag() end
  else
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetMovable then f:SetMovable(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
  end
end

-- ========= Ручки (оверлеи) =========
local MoveMode = false
local Handles  = {}  -- [key] = { handle1, handle2, ... }

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

  -- двигаем ЦЕЛЬ
  if targetFrame.SetMovable then targetFrame:SetMovable(true) end
  if targetFrame.EnableMouse then targetFrame:EnableMouse(true) end
  if targetFrame.SetClampedToScreen then targetFrame:SetClampedToScreen(true) end

  h:EnableMouse(true); h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    if targetFrame.StartMoving then targetFrame:StartMoving() end
  end)
  h:SetScript("OnDragStop", function(self)
    if targetFrame.StopMovingOrSizing then targetFrame:StopMovingOrSizing() end
    if onDrop then onDrop(self) end
    self:ClearAllPoints(); self:SetPoint("CENTER", targetFrame, "CENTER")
  end)

  h:Show()
  return h
end

local function UpdateHandles()
  -- скрыть/очистить старые
  for _,list in pairs(Handles) do for _,h in ipairs(list) do if h then h:Hide() end end end
  Handles = {}

  if not MoveMode or InCombatLockdown() then return end

  for _, item in ipairs(Registry.Widgets) do
    local frames = GetWidgetFrames(item.module, item.widget, item.get)
    if #frames>0 then
      local key = item.module.."|"..(item.widget or "MODULE")
      Handles[key] = {}
      for idx,f in ipairs(frames) do
        if f and f.GetPoint then
          local cfgKey = item.module.."||"..(item.widget or "MODULE").."||"..idx
          local cfg = P().frames[cfgKey] or {}; P().frames[cfgKey] = cfg
          if not cfg.point then
            local p,rn,rp,x,y = readPoint(f)
            cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p,rn,rp,x,y
            cfg.scale = cfg.scale or (call(f,"GetScale") or 1.0)
            cfg.locked = not not cfg.locked
          end
          ApplyFrame(f, cfg)

          local title = (item.title or (item.module.." / "..(item.widget or "Module"))).." ["..idx.."]"
          local handle = CreateHandle(f, title, function()
            local p, rel, rp, x, y = f:GetPoint()
            if P().grid.enabled then local step=P().grid.size or 8; x=roundStep(x or 0,step); y=roundStep(y or 0,step) end
            cfg.point, cfg.rel, cfg.relPoint, cfg.x, cfg.y = p, (rel and rel:GetName()) or "UIParent", rp, x or 0, y or 0
            ApplyFrame(f, cfg)
          end)
          table.insert(Handles[key], handle)
        end
      end
    end
  end
end

-- ========= События и API =========
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e)
  if e=="PLAYER_ENTERING_WORLD" then
    -- применить сохранённые позиции
    for _, item in ipairs(Registry.Widgets) do
      local frames = GetWidgetFrames(item.module, item.widget, item.get)
      for idx,f in ipairs(frames) do
        local key=item.module.."||"..(item.widget or "MODULE").."||"..idx
        local cfg=P().frames[key]; if cfg then ApplyFrame(f,cfg) end
      end
    end
    UpdateGrid()
    if MoveMode then UpdateHandles() end
  elseif e=="PLAYER_REGEN_ENABLED" then
    if MoveMode then UpdateHandles() end
  end
end)

-- Публичное управление для options.lua
function M.Toggle()
  if InCombatLockdown() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DiabolicUI:|r Нельзя включить режим переноса в бою.")
    return
  end
  MoveMode = not MoveMode
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DiabolicUI:|r Move Mode "..(MoveMode and "|cffffff00ON|r" or "|cffff0000OFF|r"))
  UpdateHandles()
  UpdateGrid()
end

function M.IsEnabled() return MoveMode end
function M.Rebuild() if not InCombatLockdown() and MoveMode then UpdateHandles() end end
function M.SetGridEnabled(v) P().grid.enabled = not not v end
function M.SetGridShown(v)   P().grid.show    = not not v; UpdateGrid() end
function M.SetGridSize(sz)   P().grid.size    = math.max(2, math.floor(sz or 8)); UpdateGrid() end
function M.GetProfile() return P() end

-- Совместимость со старым слэшем /diomove
SLASH_DIO_MOVE1="/diomove"
SlashCmdList["DIO_MOVE"] = function() M.Toggle() end
