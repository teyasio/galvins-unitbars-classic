--
-- HealthPower.lua
--
-- Displays health and power bars.

-------------------------------------------------------------------------------
-- GUB   shared data table between all parts of the addon
-------------------------------------------------------------------------------
local MyAddon, GUB = ...

local Main = GUB.Main
local Bar = GUB.Bar
local TT = GUB.DefaultUB.TriggerTypes
local DUB = GUB.DefaultUB.Default.profile

local UnitBarsF = Main.UnitBarsF
local LSM = Main.LSM
local ConvertPowerType = Main.ConvertPowerType

-- localize some globals.
local _, _G =
      _, _G
local abs, mod, max, floor, ceil, mrad,     mcos,     msin,     sqrt,      mhuge =
      abs, mod, max, floor, ceil, math.rad, math.cos, math.sin, math.sqrt, math.huge
local strfind, strmatch, strsplit, strsub, strtrim, strupper, strlower, format, gsub, gmatch =
      strfind, strmatch, strsplit, strsub, strtrim, strupper, strlower, format, gsub, gmatch
local GetTime, ipairs, pairs, next, pcall, print, select, tonumber, tostring, tremove, tinsert, type, unpack, sort =
      GetTime, ipairs, pairs, next, pcall, print, select, tonumber, tostring, tremove, tinsert, type, unpack, sort

local GetSpellPowerCost, UnitHealth, UnitHealthMax, UnitLevel =
      GetSpellPowerCost, UnitHealth, UnitHealthMax, UnitLevel
local UnitName, UnitPowerType, UnitPower, UnitPowerMax =
      UnitName, UnitPowerType, UnitPower, UnitPowerMax

-------------------------------------------------------------------------------
-- Locals
--
-- UnitBarF = UnitBarsF[]
--
-- UnitBarF.PredictedSpellID   The current spell whos predicted cost is being shown.
-- UnitBarF.PredictedPower     Current predicted cost in progress
-------------------------------------------------------------------------------
local Display = false
local Update = false

local HapBox = 1
local HapTFrame = 1

local StatusBar = 10
local PredictedCostBar = 40

-- Powertype constants
local PowerMana = ConvertPowerType['MANA']
local PowerEnergy = ConvertPowerType['ENERGY']
local PowerFocus = ConvertPowerType['FOCUS']

local GF = { -- Get function data
  TT.TypeID_ClassColor,  TT.Type_ClassColor,
  TT.TypeID_PowerColor,  TT.Type_PowerColor,
  TT.TypeID_CombatColor, TT.Type_CombatColor,
  TT.TypeID_TaggedColor, TT.Type_TaggedColor,
}

local TD = { -- Trigger data
  { TT.TypeID_BackgroundBorder,      TT.Type_BackgroundBorder,             HapTFrame },
  { TT.TypeID_BackgroundBorderColor, TT.Type_BackgroundBorderColor,        HapTFrame,
    GF = GF },
  { TT.TypeID_BackgroundBackground,  TT.Type_BackgroundBackground,         HapTFrame },
  { TT.TypeID_BackgroundColor,       TT.Type_BackgroundColor,              HapTFrame,
    GF = GF },
  { TT.TypeID_BarTexture,            TT.Type_BarTexture,                   StatusBar },
  { TT.TypeID_BarColor,              TT.Type_BarColor,                     StatusBar,
    GF = GF },
  { TT.TypeID_BarTexture,            TT.Type_BarTexture .. ' (cost)', PredictedCostBar },
  { TT.TypeID_BarColor,              TT.Type_BarColor .. ' (cost)',   PredictedCostBar,
    GF = GF },
  { TT.TypeID_BarOffset,             TT.Type_BarOffset,                    HapTFrame },
  { TT.TypeID_TextFontColor,         TT.Type_TextFontColor,
    GF = GF },
  { TT.TypeID_TextFontOffset,        TT.Type_TextFontOffset },
  { TT.TypeID_TextFontSize,          TT.Type_TextFontSize },
  { TT.TypeID_TextFontType,          TT.Type_TextFontType },
  { TT.TypeID_TextFontStyle,         TT.Type_TextFontStyle },
  { TT.TypeID_Sound,                 TT.Type_Sound }
}

local HealthVTs = {'whole',   'Health',
                   'percent', 'Health (percent)',
                   'whole',   'Unit Level',
                   'auras',   'Auras'            }
local PowerVTs = {'whole',   'Power',
                  'percent', 'Power (percent)',
                  'whole',   'Predicted Cost',
                  'whole',   'Unit Level',
                  'auras',   'Auras'           }

local HealthGroups = { -- BoxNumber, Name, ValueTypes,
  {1, '', HealthVTs, TD}, -- 1
}
local PowerGroups = { -- BoxNumber, Name, ValueTypes,
  {1, '', PowerVTs, TD}, -- 1
}

-------------------------------------------------------------------------------
-- HapFunction
--
-- Assigns a function to all the health and power bars under one name.
--
-------------------------------------------------------------------------------
local function HapFunction(Name, Fn)
  for BarType, UBF in pairs(UnitBarsF) do
    if UBF.IsHealth or UBF.IsPower then
      UBF[Name] = Fn
    end
  end
end

-------------------------------------------------------------------------------
-- Statuscheck    UnitBarsF function
-------------------------------------------------------------------------------
HapFunction('StatusCheck', Main.StatusCheck)

--*****************************************************************************
--
-- health and Power - predicted cost and initialization
--
--*****************************************************************************

-------------------------------------------------------------------------------
-- Casting
--
-- Gets called when a spell is being cast.
--
-- UnitBarF     Bar thats tracking casts
-- SpellID      Spell that is being cast
-- Message      See Main.lua for list of messages
-------------------------------------------------------------------------------
local function Casting(UnitBarF, SpellID, Message)
  UnitBarF.PredictedSpellID = 0
  UnitBarF.PredictedCost = 0

  if Message == 'start' then
    local BarPowerType = nil

    if UnitBarF.BarType == 'ManaPower' then
      BarPowerType = PowerMana
    else
      BarPowerType = Main.PlayerPowerType
    end

    if UnitBarF.UnitBar.Layout.PredictedCost then
      local CostTable = GetSpellPowerCost(SpellID)

      for _, CostInfo in pairs(CostTable) do
        if CostInfo.type == BarPowerType then
          UnitBarF.PredictedCost = CostInfo.cost
          break
        end
      end
    end
  end

  UnitBarF:Update()
end

-------------------------------------------------------------------------------
-- SetPredictedCost
--
-- Turns on predicted cost.  This will show how much resource a spell will cost
-- that has a cast time.
--
-- Usage: SetPredictedCost(UnitBarF, true or false)
--
-- UnitBarF   Tracks cost just for this bar.
-- true       Turn on predicted cost otherwise turn it off.
-------------------------------------------------------------------------------
local function SetPredictedCost(UnitBarF, Action)
  if Action then
    Main:SetCastTracker(UnitBarF, 'fn', Casting)
  else
    Main:SetCastTracker(UnitBarF, 'off')
    UnitBarF.PredictedCost = 0
  end
end

--*****************************************************************************
--
-- Health and Power bar display
--
--*****************************************************************************

-------------------------------------------------------------------------------
-- UpdateHealthBar
--
-- Updates the health of the current player or target
--
-- self         UnitBarF contains the health bar to display.
-- Event        Event that called this function.  If nil then it wasn't called by an event.
--              True by passes visible and isactive flags.
-- Unit         Unit can be 'target', 'player', 'pet', etc.
-------------------------------------------------------------------------------
local function UpdateHealthBar(self, Event, Unit)

  -- Check if bar is not visible or has active flag waiting for activity.
  if Event ~= true and not self.Visible and self.IsActive ~= 0 then
    return
  end

  local BBar = self.BBar
  local UB = self.UnitBar
  local Layout = UB.Layout
  local Bar = UB.Bar

  local CurrValue = UnitHealth(Unit)
  local MaxValue = UnitHealthMax(Unit)
  local Level = UnitLevel(Unit)

  local Name, Realm = UnitName(Unit)
  Name = Name or ''

  if Main.UnitBars.Testing then
    local TestMode = UB.TestMode

    self.Testing = true

    MaxValue = MaxValue > 10000 and MaxValue or 10000
    CurrValue = floor(MaxValue * TestMode.Value)

    Level = TestMode.UnitLevel

  -- Just switched out of test mode do a clean up.
  elseif self.Testing then
    self.Testing = false
  end

  local ClassColor = Layout.ClassColor or false
  local CombatColor = Layout.CombatColor or false
  local TaggedColor = Layout.TaggedColor or false
  local BarColor = Bar.Color
  local r, g, b, a = BarColor.r, BarColor.g, BarColor.b, BarColor.a

  -- Get class color
  if ClassColor then
    r, g, b, a = Main:GetClassColor(Unit, nil, nil, nil, r, g, b, a)

  -- Get faction color
  elseif CombatColor then
    r, g, b, a = Main:GetCombatColor(Unit, nil, nil, nil, r, g, b, a)
  end

  -- Get tagged color
  if TaggedColor then
    r, g, b, a = Main:GetTaggedColor(Unit, nil, nil, nil, r, g, b, a)
  end

  local Value = 0
  local Clip = false

  if MaxValue > 0 then
    Value = CurrValue / MaxValue
  end

  -- Set the color and display the value.
  BBar:SetColorTexture(HapBox, StatusBar, r, g, b, a)
  BBar:SetFillTexture(HapBox, StatusBar, Value)

  if not UB.Layout.HideText then
    BBar:SetValueFont(HapBox, 'current', CurrValue, 'maximum', MaxValue, 'level', Level, 'name', Name, Realm)
  end

  -- Check triggers
  if UB.Layout.EnableTriggers then
    BBar:SetTriggers(1, 'health', CurrValue)
    BBar:SetTriggers(1, 'health (percent)', CurrValue, MaxValue)
    BBar:SetTriggers(1, 'unit level', Level)
    BBar:DoTriggers()
  end

  -- Set the IsActive flag.
  self.IsActive = CurrValue < MaxValue

  -- Do a status check.
  self:StatusCheck()
end

function Main.UnitBarsF.PlayerHealth:Update(Event)
  UpdateHealthBar(self, Event, 'player')
end

function Main.UnitBarsF.TargetHealth:Update(Event)
  UpdateHealthBar(self, Event, 'target')
end

function Main.UnitBarsF.PetHealth:Update(Event)
  UpdateHealthBar(self, Event, 'pet')
end

-------------------------------------------------------------------------------
-- UpdatePowerBar
--
-- Updates the power of the unit.
--
-- self          UnitBarF contains the power bar to display.
-- Event         Event that called this function.  If nil then it wasn't called by an event.
--               True bypasses visible and isactive flags.
-- Unit          Unit name 'player' ,'target', etc
-- PowerType2    PowerType from server or when PowerMana update is called.
--               If nil then the unit's powertype is used if nots a ManaPower bar.
-------------------------------------------------------------------------------
local function UpdatePowerBar(self, Event, Unit, PowerType2)

  -- Check if bar is not visible or has active flag waiting for activity.
  if Event ~= true and not self.Visible and self.IsActive ~= 0 then
    return
  end

  -- Convert string powertype into number.
  PowerType2 = ConvertPowerType[PowerType2]

  local BarType = self.BarType
  local PowerType = nil

  if BarType ~= 'ManaPower' then
    PowerType = UnitPowerType(Unit)
    if PowerType2 ~= nil and PowerType ~= PowerType2 then

      -- Return, not correct power type.
      return
    end

  -- ManaPower bar can only be a mana powertype.
  elseif PowerType2 == PowerMana then
    PowerType = PowerMana
  else

    -- Return, not correct power type.
    return
  end

  local BBar = self.BBar
  local UB = self.UnitBar
  local Bar = UB.Bar
  local Layout = UB.Layout
  local DLayout = DUB[BarType].Layout

  local CurrValue = UnitPower(Unit, PowerType)
  local MaxValue = UnitPowerMax(Unit, PowerType)
  local Level = UnitLevel(Unit)

  local PredictedCost = self.PredictedCost or 0

  local Name, Realm = UnitName(Unit)
  Name = Name or ''

  local UseBarColor = Layout.UseBarColor or false
  local r, g, b, a = 1, 1, 1, 1

  if UseBarColor then
    local Color = Bar.Color
    r, g, b, a = Color.r, Color.g, Color.b, Color.a
  else
    r, g, b, a = Main:GetPowerColor(Unit, PowerType, nil, nil, r, g, b, a)
  end

  if Main.UnitBars.Testing then
    local TestMode = UB.TestMode
    local TestPredictedCost = Layout.PredictedCost and TestMode.PredictedCost or 0

    self.Testing = true

    MaxValue = MaxValue > 10000 and MaxValue or 10000
    CurrValue = floor(MaxValue * TestMode.Value)
    PredictedCost = floor(MaxValue * TestPredictedCost)

    Level = TestMode.UnitLevel

  -- Just switched out of test mode do a clean up.
  elseif self.Testing then
    self.Testing = false

    self.PredictedCost = 0
    PredictedCost = 0

    if MaxValue == 0 then
      BBar:SetFillTexture(HapBox, PredictedCostBar, 0)
    end
  end

  local Value = 0

  if MaxValue > 0 then
    Value = CurrValue / MaxValue
  end

  if MaxValue > 0 then

    -- Do predicted cost
    if self.LastPredictedCost ~= PredictedCost then
      BBar:SetFillLengthTexture(HapBox, PredictedCostBar, PredictedCost / MaxValue)
      self.LastPredictedCost = PredictedCost
    end
  end

  BBar:SetColorTexture(HapBox, StatusBar, r, g, b, a)
  BBar:SetFillTexture(HapBox, StatusBar, Value)

  if not UB.Layout.HideText then
    if PredictedCost > 0 then
      BBar:SetValueFont(HapBox, 'current', CurrValue, 'maximum', MaxValue, 'predictedcost', PredictedCost, 'level', Level, 'name', Name, Realm)
    else
      BBar:SetValueFont(HapBox, 'current', CurrValue, 'maximum', MaxValue, 'level', Level, 'name', Name, Realm)
    end
  end

  -- Check triggers
  if UB.Layout.EnableTriggers then
    BBar:SetTriggers(1, 'power', CurrValue)
    BBar:SetTriggers(1, 'power (percent)', CurrValue, MaxValue)
    BBar:SetTriggers(1, 'predicted cost', PredictedCost)
    BBar:SetTriggers(1, 'unit level', Level)
    BBar:DoTriggers()
  end

  -- Set the IsActive flag.
  local IsActive = false
  if PowerType == PowerMana or PowerType == PowerEnergy or PowerType == PowerFocus then
    if CurrValue < MaxValue then
      IsActive = true
    end
  else
    if CurrValue > 0 then
      IsActive = true
    end
  end

  self.IsActive = IsActive

  -- Do a status check.
  self:StatusCheck()
end

function Main.UnitBarsF.PlayerPower:Update(Event)
  UpdatePowerBar(self, Event, 'player')
end

function Main.UnitBarsF.TargetPower:Update(Event)
  UpdatePowerBar(self, Event, 'target')
end

function Main.UnitBarsF.PetPower:Update(Event)
  UpdatePowerBar(self, Event, 'pet')
end

function Main.UnitBarsF.ManaPower:Update(Event)
  UpdatePowerBar(self, Event, 'player', 'MANA')
end

--*****************************************************************************
--
-- Health and Power bar creation/setting
--
--*****************************************************************************

------------------------------------------------------------------------------
-- EnableMouseClicks
--
-- This will enable or disbale mouse clicks for the rune icons.
-------------------------------------------------------------------------------
HapFunction('EnableMouseClicks', function(self, Enable)
  self.BBar:EnableMouseClicks(HapBox, nil, Enable)
end)

-------------------------------------------------------------------------------
-- SetAttr
--
-- Sets different parts of the health and power bars.
-------------------------------------------------------------------------------
HapFunction('SetAttr', function(self, TableName, KeyName)
  local BBar = self.BBar
  local BarType = self.BarType
  local UB = self.UnitBar
  local UBD = DUB[BarType]
  local Layout = UB.Layout
  local DLayout = UBD.Layout
  local DBar = UBD.Bar

  if not BBar:OptionsSet() then
    BBar:SO('Text', '_Font', function() BBar:UpdateFont(1) Update = true end)

    BBar:SO('Attributes', '_', function() Main:UnitBarSetAttr(self) end)

    BBar:SO('Layout', 'EnableTriggers', function(v)
      if strfind(BarType, 'Power') then
        BBar:EnableTriggers(v, PowerGroups)
      else
        BBar:EnableTriggers(v, HealthGroups)
      end
      Update = true
    end)
    BBar:SO('Layout', 'ReverseFill',     function(v) BBar:SetFillReverseTexture(HapBox, StatusBar, v) Update = true end)
    BBar:SO('Layout', 'HideText',        function(v)
      if v then
        BBar:SetValueRawFont(1, '')
      else
        Update = true
      end
    end)
    BBar:SO('Layout', 'SmoothFillMaxTime', function(v) BBar:SetSmoothFillMaxTime(HapBox, StatusBar, v) end)
    BBar:SO('Layout', 'SmoothFillSpeed',   function(v) BBar:SetFillSpeedTexture(HapBox, StatusBar, v) end)

    if DLayout then
      -- More layout
      if DLayout.UseBarColor ~= nil then
        BBar:SO('Layout', 'UseBarColor', function(v) Update = true end)
      end

      if DLayout.ClassColor ~= nil then
        BBar:SO('Layout', 'ClassColor', function(v) Update = true end)
      end

      if DLayout.CombatColor ~= nil then
        BBar:SO('Layout', 'CombatColor', function(v) Update = true end)
      end

      if DLayout.TaggedColor ~= nil then
        BBar:SO('Layout', 'TaggedColor', function(v) Update = true end)
      end
    end

    -- More layout
    if DLayout.PredictedCost ~= nil then
      BBar:SO('Layout', 'PredictedCost', function(v)
        BBar:SetHiddenTexture(HapBox, PredictedCostBar, not v)
        SetPredictedCost(self, v)
        Update = true
      end)
    end

    BBar:SO('Background', 'BgTexture',     function(v) BBar:SetBackdrop(HapBox, HapTFrame, v) end)
    BBar:SO('Background', 'BorderTexture', function(v) BBar:SetBackdropBorder(HapBox, HapTFrame, v) end)
    BBar:SO('Background', 'BgTile',        function(v) BBar:SetBackdropTile(HapBox, HapTFrame, v) end)
    BBar:SO('Background', 'BgTileSize',    function(v) BBar:SetBackdropTileSize(HapBox, HapTFrame, v) end)
    BBar:SO('Background', 'BorderSize',    function(v) BBar:SetBackdropBorderSize(HapBox, HapTFrame, v) end)
    BBar:SO('Background', 'Padding',       function(v) BBar:SetBackdropPadding(HapBox, HapTFrame, v.Left, v.Right, v.Top, v.Bottom) end)
    BBar:SO('Background', 'Color',         function(v) BBar:SetBackdropColor(HapBox, HapTFrame, v.r, v.g, v.b, v.a) end)
    BBar:SO('Background', 'BorderColor',   function(v, UB)
      if UB.Background.EnableBorderColor then
        BBar:SetBackdropBorderColor(HapBox, HapTFrame, v.r, v.g, v.b, v.a)
      else
        BBar:SetBackdropBorderColor(HapBox, HapTFrame, nil)
      end
    end)

    BBar:SO('Bar', 'StatusBarTexture',    function(v) BBar:SetTexture(HapBox, StatusBar, v) end)
    BBar:SO('Bar', 'SyncFillDirection',   function(v) BBar:SyncFillDirectionTexture(HapBox, StatusBar, v) Update = true end)
    BBar:SO('Bar', 'Clipping',            function(v) BBar:SetClippingTexture(HapBox, StatusBar, v) Update = true end)
    BBar:SO('Bar', 'FillDirection',       function(v) BBar:SetFillDirectionTexture(HapBox, StatusBar, v) Update = true end)
    BBar:SO('Bar', 'RotateTexture',       function(v)


    BBar:SetRotationTexture(HapBox, StatusBar, v) end)

    if DBar.PredictedCostColor ~= nil then
      BBar:SO('Bar', 'PredictedCostBarTexture', function(v) BBar:SetTexture(HapBox, PredictedCostBar, v) end)
      BBar:SO('Bar', 'PredictedCostColor',      function(v) BBar:SetColorTexture(HapBox, PredictedCostBar, v.r, v.g, v.b, v.a) end)
    end

    if DBar.Color ~= nil then
      BBar:SO('Bar', 'Color',               function(v) Update = true end)
    end
    BBar:SO('Bar', 'TaggedColor',           function(v, UB) Update = true end)

    BBar:SO('Bar', '_Size',                 function(v) BBar:SetSizeTextureFrame(HapBox, HapTFrame, v.Width, v.Height) Display = true end)
    BBar:SO('Bar', 'Padding',               function(v) BBar:SetPaddingTextureFrame(HapBox, HapTFrame, v.Left, v.Right, v.Top, v.Bottom) Display = true end)
  end

  -- Do the option.  This will call one of the options above or all.
  BBar:DoOption(TableName, KeyName)

  if Update or Main.UnitBars.Testing then
    self:Update()
    Update = false
    Display = true
  end

  if Display then
    BBar:Display()
    Display = false
  end
end)

-------------------------------------------------------------------------------
-- CreateBar
--
-- UnitBarF     The unitbar frame which will contain the health and power bar.
-- UB           Unitbar data.
-- Anchor       Unitbar's anchor.
-- ScaleFrame   ScaleFrame which the unitbar must be a child of for scaling.
-------------------------------------------------------------------------------
function GUB.HapBar:CreateBar(UnitBarF, UB, ScaleFrame)
  local BBar = Bar:CreateBar(UnitBarF, ScaleFrame, 1)

  -- Create the health and predicted cost bar
  BBar:CreateTextureFrame(HapBox, HapTFrame, 1)
    BBar:CreateTexture(HapBox, HapTFrame, StatusBar, 'statusbar')
    BBar:CreateTexture(HapBox, HapTFrame, PredictedCostBar)

  -- Create font text for the box frame.
  BBar:CreateFont('Text', HapBox)

  -- Enable tooltip
  BBar:SetTooltip(HapBox, nil, UB.Name)

  -- Show the bar.
  BBar:SetHidden(HapBox, HapTFrame, false)
  BBar:SetHiddenTexture(HapBox, StatusBar, false)
  BBar:SetHiddenTexture(HapBox, PredictedCostBar, false)

  BBar:SetFillTexture(HapBox, StatusBar, 0)
  BBar:SetFillTexture(HapBox, PredictedCostBar, 1)

  -- Set this for trigger bar offsets
  BBar:SetOffsetTextureFrame(HapBox, HapTFrame, 0, 0, 0, 0)

  -- Set the tagged bars
  BBar:TagTexture(HapBox, StatusBar, PredictedCostBar)

  BBar:SetFillLengthTexture(HapBox, PredictedCostBar, 0)
  BBar:TagLeftTexture(HapBox, PredictedCostBar, true)

  UnitBarF.BBar = BBar
end

--*****************************************************************************
--
-- Health and Power bar Enable/Disable functions
--
--*****************************************************************************

local function RegEventHealth(Enable, UnitBarF, ...)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_HEALTH_FREQUENT',            UpdateHealthBar, ...)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_MAXHEALTH',                  UpdateHealthBar, ...)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_FACTION',                    UpdateHealthBar, ...)
end

local function RegEventPower(Enable, UnitBarF, ...)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_POWER_FREQUENT', UpdatePowerBar, ...)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_MAXPOWER',       UpdatePowerBar, ...)
end

function Main.UnitBarsF.PlayerHealth:Enable(Enable)
  RegEventHealth(Enable, self, 'player')
end

function Main.UnitBarsF.TargetHealth:Enable(Enable)
  RegEventHealth(Enable, self, 'target')
end

function Main.UnitBarsF.PetHealth:Enable(Enable)
  RegEventHealth(Enable, self, 'pet')
end

function Main.UnitBarsF.PlayerPower:Enable(Enable)
  RegEventPower(Enable, self, 'player')
end

function Main.UnitBarsF.TargetPower:Enable(Enable)
  RegEventPower(Enable, self, 'target')
end

function Main.UnitBarsF.PetPower:Enable(Enable)
  RegEventPower(Enable, self, 'pet')
end

function Main.UnitBarsF.ManaPower:Enable(Enable)
  RegEventPower(Enable, self, 'player')
end
