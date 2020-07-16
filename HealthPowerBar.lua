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
local OT = Bar.TriggerObjectTypes
local DUB = GUB.DefaultUB.Default.profile

local UnitBarsF = Main.UnitBarsF
local ConvertPowerType = Main.ConvertPowerType

-- localize some globals.
local _, _G =
      _, _G
local floor, strfind, pairs, print =
      floor, strfind, pairs, print
local GetSpellPowerCost, UnitHealth, UnitHealthMax, UnitLevel =
      GetSpellPowerCost, UnitHealth, UnitHealthMax, UnitLevel
local UnitExists, UnitName, UnitPowerType, UnitPower, UnitPowerMax =
      UnitExists, UnitName, UnitPowerType, UnitPower, UnitPowerMax

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
local MaxTickerSize = 0.20

local HapBox = 1
local HapTFrame = 1

local StatusBar = 10
local TickerMoverBar = 20
local TickerBar = 21
local PredictedCostBar = 40

-- Powertype constants
local PowerMana = ConvertPowerType['MANA']
local PowerEnergy = ConvertPowerType['ENERGY']
local PowerFocus = ConvertPowerType['FOCUS']

local ObjectsInfo = { -- type, id, additional menu text, textures
  { OT.BackgroundBorder,      1,  '',        HapTFrame        },
  { OT.BackgroundBorderColor, 2,  '',        HapTFrame        },
  { OT.BackgroundBackground,  3,  '',        HapTFrame        },
  { OT.BackgroundColor,       4,  '',        HapTFrame        },
  { OT.BarTexture,            5,  '',        StatusBar        },
  { OT.BarColor,              6,  '',        StatusBar        },
  { OT.BarTexture,            7,  ' (cost)', PredictedCostBar },
  { OT.BarColor,              8,  ' (cost)', PredictedCostBar },
  { OT.BarOffset,             9,  '',        HapTFrame        },
  { OT.TextFontColor,         10, '',                         },
  { OT.TextFontOffset,        11, '',                         },
  { OT.TextFontSize,          12, '',                         },
  { OT.TextFontType,          13, '',                         },
  { OT.TextFontStyle,         14, '',                         },
  { OT.Sound,                 15, ''                          }
}

local ObjectInfoTicker = { -- type, id, additional menu text, textures
  {OT.BackgroundBorder,      1,  '',        HapTFrame        },
  {OT.BackgroundBorderColor, 2,  '',        HapTFrame        },
  {OT.BackgroundBackground,  3,  '',        HapTFrame        },
  {OT.BackgroundColor,       4,  '',        HapTFrame        },
  {OT.BarTexture,            5,  '',        StatusBar        },
  {OT.BarColor,              6,  '',        StatusBar        },
  {OT.BarTexture,            7,  ' (cost)', PredictedCostBar },
  {OT.BarColor,              8,  ' (cost)', PredictedCostBar },
  {OT.BarOffset,             9,  '',        HapTFrame        },
  {OT.BarTexture,            10, '',        TickerBar        },
  {OT.BarColor,              11, '',        TickerBar        },
  {OT.TextFontColor,         12, '',                         },
  {OT.TextFontOffset,        13, '',                         },
  {OT.TextFontSize,          14, '',                         },
  {OT.TextFontType,          15, '',                         },
  {OT.TextFontStyle,         16, '',                         },
  {OT.Sound,                 17, ''                          },
}

local GroupsInfoHealth = { -- BoxNumber, Name, ValueTypes
  ValueNames = {
    'whole',   'Health',
    'percent', 'Health (percent)',
    'whole',   'Unit Level',
  },
  {1, 'Health', ObjectsInfo}, -- 1
}

local GroupsInfoPower = { -- BoxNumber, Name, ValueTypes
  ValueNames = {
    'whole',   'Power',
    'percent', 'Power (percent)',
    'whole',   'Predicted Cost',
    'whole',   'Unit Level',
  },
  {1, 'Power', ObjectsInfo}, -- 1
}

local GroupsInfoPowerTicker = { -- BoxNumber, Name, ValueTypes
  ValueNames = {
    'whole',   'Power',
    'percent', 'Power (percent)',
    'whole',   'Predicted Cost',
    'whole',   'Unit Level',
    'decimal', 'Ticker (time)',
    'state',   'Ticker (FSR)',
  },
  {1, 'Power', ObjectInfoTicker}, -- 1
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
-- health and Power - predicted cost, print, ticker and initialization
--
--*****************************************************************************

-------------------------------------------------------------------------------
-- PrintValues
--
-- Displays the values for power bars
-------------------------------------------------------------------------------
local function PrintValues(UnitBarF, BD)
  local BBar = UnitBarF.BBar

  if not UnitBarF.UnitBar.Layout.HideText then
    if BD.PredictedCost > 0 then
      if BD.Time then
        BBar:SetValueFont(HapBox, 'current', BD.CurrValue, 'maximum', BD.MaxValue, 'predictedcost', BD.PredictedCost, 'time', BD.Time, 'level', BD.Level, 'name', BD.Name, BD.Realm)
      else
        BBar:SetValueFont(HapBox, 'current', BD.CurrValue, 'maximum', BD.MaxValue, 'predictedcost', BD.PredictedCost, 'level', BD.Level, 'name', BD.Name, BD.Realm)
      end
    else
      if BD.Time then
        BBar:SetValueFont(HapBox, 'current', BD.CurrValue, 'maximum', BD.MaxValue, 'time', BD.Time, 'level', BD.Level, 'name', BD.Name, BD.Realm)
      else
        BBar:SetValueFont(HapBox, 'current', BD.CurrValue, 'maximum', BD.MaxValue, 'level', BD.Level, 'name', BD.Name, BD.Realm)
      end
    end
  end
end

-------------------------------------------------------------------------------
-- SetTickerColor
--
-- Sets color of ticker based off test mode or normal mode
-------------------------------------------------------------------------------
local function SetTickerColor(UnitBarF, PowerType)
  local Bar = UnitBarF.UnitBar.Bar
  local Color

  if PowerType == PowerMana then
    Color = Bar.TickerColorMana
  else
    Color = Bar.TickerColorEnergy
  end
  UnitBarF.BBar:SetColorTexture(HapBox, TickerBar, Color.r, Color.g, Color.b, Color.a)
end

-------------------------------------------------------------------------------
-- DoTickerTime
--
-- Gets called during a ticker
--
-- BBar           Current bar being used.
-- BoxNumber      Current box the call back happened on
-- Time           Current time
-- Done           If true then the timer is finished
-------------------------------------------------------------------------------
local function DoTickerTime(UnitBarF, BBar, BoxNumber, Time, Done)
  if not Done then
    local Layout = UnitBarF.UnitBar.Layout

    if Layout.EnableTriggers then
      BBar:SetTriggers('Ticker (time)', Time)
      BBar:SetTriggers('Ticker (FSR)', UnitBarF.BarData.Message == 'fsr')
      BBar:DoTriggers()
    end
    UnitBarF.BarData.Time = Time
  else
    BBar:SetHiddenTexture(HapBox, TickerBar, true)
    UnitBarF.BarData.Time = false
  end
  PrintValues(UnitBarF, UnitBarF.BarData)
end

-------------------------------------------------------------------------------
-- Ticker
--
-- Gets called when energy or mana is ticking or five second rule
-------------------------------------------------------------------------------
local function Ticker(UnitBarF, Message, PowerType, Duration)
  local BarType = UnitBarF.BarType
  local BBar = UnitBarF.BBar
  local UB = UnitBarF.UnitBar
  local Layout = UB.Layout

  if Main.UnitBars.Testing then
    return
  end

  -- Check for stop
  if Message == 'stop' then
    BBar:SetValueTime(HapBox, DoTickerTime)
    return
  end

  if BarType == 'ManaPower' and PowerType ~= PowerMana or
     BarType == 'PlayerPower' and PowerType ~= UnitPowerType('player') then
    return
  end

  if Message == 'fsr' and not Layout.TickerFSR or
     Message == 'tick' and not Layout.TickerTwoSeconds then
    return
  end

  SetTickerColor(UnitBarF, PowerType)

  -- Set message for triggers in DoTickerTime
  UnitBarF.BarData.Message = Message

  BBar:SetFillTimeTexture(HapBox, TickerMoverBar, nil, Duration, 0, 1)

  BBar:SetValueTime(HapBox, DoTickerTime)
  BBar:SetHiddenTexture(HapBox, TickerBar, false)
  BBar:SetValueTime(HapBox, nil, Duration, 1, DoTickerTime)
end

-------------------------------------------------------------------------------
-- SetTicker
--
-- Turns on the power ticker for energy or mana. Also shows 5 second rule
--
-- Usage: SetTicker(UnitBarF, true or false)
--
-- UnitBarF   Tracks ticker just for this bar.
-- true       Turn on ticker other wise turn it off
-------------------------------------------------------------------------------
local function SetTicker(UnitBarF, Action)
  local BarType = UnitBarF.BarType
  local Command

  if Action then
    Main:SetTickerTracker(UnitBarF, 'fn', Ticker)
    Command = 'pt'
  else
    Command = 'off'
  end

  if BarType == 'PlayerPower' then
    Main:SetTickerTracker(UnitBarF, Command, PowerMana, PowerEnergy)
  elseif BarType == 'ManaPower' then
    Main:SetTickerTracker(UnitBarF, Command, PowerMana)
  end
end

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
    local BarPowerType

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
  UnitBarF.BBar:SetHiddenTexture(HapBox, PredictedCostBar, not Action)

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
-- Unit         Ignored just here for reference
-------------------------------------------------------------------------------
local function UpdateHealthBar(self, Event, Unit)

  ---------------
  -- Set IsActive
  ---------------
  local UB = self.UnitBar
  Unit = UB.UnitType

  local CurrValue
  local MaxValue

  CurrValue = UnitHealth(Unit)
  MaxValue = UnitHealthMax(Unit)

  self.IsActive = CurrValue < MaxValue

  --------
  -- Check
  --------
  local LastHidden = self.Hidden
  self:StatusCheck()
  local Hidden = self.Hidden

  -- If not called by an event and Hidden is true then return
  if Event == nil and Hidden or LastHidden and Hidden then
    return
  end

  ------------
  -- Test Mode
  ------------
  local UB = self.UnitBar
  local Bar = UB.Bar

  local Level = UnitLevel(Unit)

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

  -------
  -- Draw
  -------
  local BBar = self.BBar
  local Layout = UB.Layout
  local Name, Realm = UnitName(Unit)
  Name = Name or ''

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
    BBar:SetTriggers('Health', CurrValue)
    BBar:SetTriggers('Health (percent)', CurrValue, MaxValue)
    BBar:SetTriggers('Unit Level', Level)
    BBar:DoTriggers()
  end
end

Main.UnitBarsF.PlayerHealth.Update = UpdateHealthBar
Main.UnitBarsF.TargetHealth.Update = UpdateHealthBar
Main.UnitBarsF.PetHealth.Update    = UpdateHealthBar

-------------------------------------------------------------------------------
-- UpdatePowerBar
--
-- Updates the power of the unit.
--
-- self          UnitBarF contains the power bar to display.
-- Event         Event that called this function.  If nil then it wasn't called by an event.
-- Unit          Ignored just here for reference
-- PowerToken    String: PowerType in caps: MANA RAGE, etc
--               If nil then the units powertype is used instead
-------------------------------------------------------------------------------
local function UpdatePowerBar(self, Event, Unit, PowerToken)

  -------------------
  -- Check Power Type
  -------------------
  local UB = self.UnitBar
  local BarType = self.BarType
  Unit = UB.UnitType

  local PowerType
  Unit = UB.UnitType
  PowerToken = ConvertPowerType[PowerToken]

  if BarType ~= 'ManaPower' then
    PowerType = UnitPowerType(Unit)

    -- Return if power types doesn't match that of the powerbar
    if PowerToken ~= nil and PowerToken ~= PowerType then
      return
    end
  elseif PowerToken == nil or PowerToken == PowerMana then
    PowerType = PowerMana
  else
    -- Return, not correct power type
    return
  end

  ---------------
  -- Set IsActive
  ---------------
  local CurrValue = UnitPower(Unit, PowerType)
  local MaxValue = UnitPowerMax(Unit, PowerType)
  local Level = UnitLevel(Unit)

  local PredictedCost = self.PredictedCost or 0

  local IsActive = false
  if UnitExists(Unit) then
    if PowerType == PowerMana or PowerType == PowerEnergy or PowerType == PowerFocus then
      if CurrValue < MaxValue or PredictedCost > 0 then
        IsActive = true
      end
    else
      IsActive = CurrValue > 0
    end
  end
  self.IsActive = IsActive

  --------
  -- Check
  --------
  local LastHidden = self.Hidden
  self:StatusCheck()
  local Hidden = self.Hidden

  -- If not called by an event and Hidden is true then return
  if Event == nil and Hidden or LastHidden and Hidden then
    return
  end

  ------------
  -- Test Mode
  ------------
  local BBar = self.BBar
  local Layout = UB.Layout
  local BD = self.BarData

  if Main.UnitBars.Testing then
    local TestMode = UB.TestMode
    local TestPredictedCost = Layout.PredictedCost and TestMode.PredictedCost or 0

    self.Testing = true

    MaxValue = MaxValue > 10000 and MaxValue or 10000
    CurrValue = floor(MaxValue * TestMode.Value)
    PredictedCost = floor(MaxValue * TestPredictedCost)

    Level = TestMode.UnitLevel

    -- Ticker
    if TestMode.Ticker ~= nil then
      local TickerEnabled = Layout.TickerEnabled

      if TestMode.TickerFSR then
        BD.Message = 'fsr'
      else
        BD.Message = false
      end

      BBar:SetHiddenTexture(HapBox, TickerBar, not TickerEnabled)
      DoTickerTime(self, BBar, HapBox, TestMode.Ticker, not TickerEnabled)

      if TickerEnabled then
        if BarType == 'ManaPower' or TestMode.TickerMana then
          SetTickerColor(self, PowerMana)
        elseif BarType ~= 'ManaPower'  then
          SetTickerColor(self, TestMode.TickerMana and PowerMana or TestMode.TickerEnergy and PowerEnergy or PowerMana)
        end
        BBar:SetFillTexture(HapBox, TickerMoverBar, 1 / 6 * TestMode.Ticker)
      end
    end

  -- Just switched out of test mode do a clean up.
  elseif self.Testing then
    self.Testing = false

    self.PredictedCost = 0
    PredictedCost = 0

    if MaxValue == 0 then
      BBar:SetFillTexture(HapBox, PredictedCostBar, 0)
    end

    if UB.TestMode.Ticker ~= nil then
      BD.Message = false
      DoTickerTime(self, BBar, HapBox, nil, true)
    end
  end

  -------
  -- Draw
  -------
  local Bar = UB.Bar
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

  BD.CurrValue     = CurrValue
  BD.MaxValue      = MaxValue
  BD.PredictedCost = PredictedCost
  BD.Level         = Level
  BD.Name          = Name
  BD.Realm         = Realm

  PrintValues(self, BD)

  -- Check triggers
  if UB.Layout.EnableTriggers then
    BBar:SetTriggers('Power', CurrValue)
    BBar:SetTriggers('Power (percent)', CurrValue, MaxValue)
    BBar:SetTriggers('Predicted Cost', PredictedCost)
    BBar:SetTriggers('Unit Level', Level)
    BBar:DoTriggers()
  end
end

Main.UnitBarsF.PlayerPower.Update = UpdatePowerBar
Main.UnitBarsF.TargetPower.Update = UpdatePowerBar
Main.UnitBarsF.PetPower.Update    = UpdatePowerBar
Main.UnitBarsF.ManaPower.Update   = UpdatePowerBar

--*****************************************************************************
--
-- Health and Power bar creation/setting
--
--*****************************************************************************

-------------------------------------------------------------------------------
-- SetAttr
--
-- Sets different parts of the health and power bars.
-------------------------------------------------------------------------------
HapFunction('SetAttr', function(self, TableName, KeyName)
  local BBar = self.BBar
  local BarType = self.BarType
  local UBD = DUB[BarType]
  local DLayout = UBD.Layout
  local DBar = UBD.Bar

  if not BBar:OptionsSet() then
    BBar:SO('Text', '_Font', function() BBar:UpdateFont(1) Update = true end)

    BBar:SO('Attributes', '_', function() Main:UnitBarSetAttr(self) end)

    BBar:SO('Layout', 'EnableTriggers', function(v)
      if strfind(BarType, 'Power') then
        if BarType == 'PlayerPower' or BarType == 'ManaPower' then
          BBar:EnableTriggers(v, GroupsInfoPowerTicker)
        else
          BBar:EnableTriggers(v, GroupsInfoPower)
        end
      else
        BBar:EnableTriggers(v, GroupsInfoHealth)
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
      BBar:SO('Layout', 'PredictedCost', function(v) SetPredictedCost(self, v) Update = true end)
    end

    if DLayout.TickerEnabled ~= nil then
      BBar:SO('Layout', 'TickerEnabled', function(v) SetTicker(self, v) Update = true end)
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
    BBar:SO('Bar', 'SyncFillDirection',   function(v)
      BBar:SyncFillDirectionTexture(HapBox, StatusBar, v)
      if DBar.TickerColor ~= nil then
        BBar:SyncFillDirectionTexture(HapBox, TickerMoverBar, v)
      end
      Update = true
    end)
    BBar:SO('Bar', 'Clipping',            function(v)
      BBar:SetClippingTexture(HapBox, StatusBar, v)
      if DBar.TickerColor ~= nil then
        BBar:SetClippingTexture(HapBox, TickerMoverBar, v)
      end
      Update = true
    end)
    BBar:SO('Bar', 'FillDirection',       function(v)
      BBar:SetFillDirectionTexture(HapBox, StatusBar, v)
      if DBar.TickerColor ~= nil then
        BBar:SetFillDirectionTexture(HapBox, TickerMoverBar, v)
      end
      Update = true
    end)
    BBar:SO('Bar', 'RotateTexture',       function(v)
      BBar:SetRotationTexture(HapBox, StatusBar, v)
      if DBar.TickerColor ~= nil then
        BBar:SetRotationTexture(HapBox, TickerMoverBar, v)
      end
    end)
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

    if DBar.TickerStatusBarTexture ~= nil then
      BBar:SO('Bar', 'TickerStatusBarTexture', function(v) BBar:SetTexture(HapBox, TickerBar, v) end)
      BBar:SO('Bar', 'TickerColor',            function(v) BBar:SetColorTexture(HapBox, TickerBar, v.r, v.g, v.b, v.a) end)
      BBar:SO('Bar', 'TickerSize',             function(v) BBar:SetFillLengthTexture(HapBox, TickerBar, MaxTickerSize * v) end)
    end
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

    -- Create ticker
    BBar:CreateTexture(HapBox, HapTFrame, TickerMoverBar)
    BBar:CreateTexture(HapBox, HapTFrame, TickerBar)


  -- Create font text for the box frame.
  BBar:CreateFont('Text', HapBox)

  -- Enable tooltip
  BBar:SetTooltipBox(HapBox, UB.Name)

  -- Show the bar.
  BBar:SetHidden(HapBox, HapTFrame, false)
  BBar:SetHiddenTexture(HapBox, StatusBar, false)
  BBar:SetHiddenTexture(HapBox, PredictedCostBar, false)

  BBar:SetFillTexture(HapBox, StatusBar, 0)
  BBar:SetFillTexture(HapBox, PredictedCostBar, 1)

  -- ticker
  BBar:SetFillTexture(HapBox, TickerMoverBar, 0)
  BBar:SetFillTexture(HapBox, TickerBar, 1)

  -- Set this for trigger bar offsets
  BBar:SetOffsetTextureFrame(HapBox, HapTFrame, 0, 0, 0, 0)

  -- Set the tagged bars
  BBar:TagTexture(HapBox, StatusBar, PredictedCostBar)
  BBar:TagTexture(HapBox, TickerMoverBar, TickerBar)

  BBar:SetFillLengthTexture(HapBox, PredictedCostBar, 0.25)
  BBar:SetFillLengthTexture(HapBox, TickerBar, MaxTickerSize)
  BBar:TagLeftTexture(HapBox, PredictedCostBar, true)

  local BD = {}
  UnitBarF.BarData = BD
  BD.CurrValue     = 0
  BD.MaxValue      = 0
  BD.PredictedCost = 0
  BD.Level         = 0
  BD.Name          = 0
  BD.Realm         = 0
  BD.Time          = false

  UnitBarF.BBar = BBar
end

--*****************************************************************************
--
-- Health and Power bar Enable/Disable functions
--
--*****************************************************************************
local function RegEventHealth(Enable, UnitBarF, Unit)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_HEALTH_FREQUENT',            UpdateHealthBar, Unit)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_MAXHEALTH',                  UpdateHealthBar, Unit)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_FACTION',                    UpdateHealthBar, Unit)
end

local function RegEventPower(Enable, UnitBarF, Unit)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_POWER_FREQUENT', UpdatePowerBar, Unit)
  Main:RegEventFrame(Enable, UnitBarF, 'UNIT_MAXPOWER',       UpdatePowerBar, Unit)
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
