-- F-Zero GX



-- Imports.

-- First make sure that the imported modules get de-cached as needed, since
-- we may be re-running the script in the same run of Cheat Engine.
package.loaded.shared = nil
package.loaded.utils = nil
package.loaded.dolphin = nil

local shared = require "shared"
local utils = require "utils"
local dolphin = require "dolphin"

local readIntBE = utils.readIntBE
local readFloatBE = utils.readFloatBE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local debugDisp = utils.debugDisp
local StatRecorder = utils.StatRecorder

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- Data structure for RAM values we care about.

local values = {
  state = {},
}



-- Computing RAM values.

local stateBlockOffsets = {
  machineId = 0x6,
  machineName = 0x3C,
  posX = 0x7C,
  posY = 0x80,
  posZ = 0x84,
  velX = 0x94,
  velY = 0x98,
  velZ = 0x9C,
  kmh = 0x17C,
  energy = 0x184,
}

local valueTypes = {
  -- Only add an entry here if it's something other than a float.
  machineName = "string",
}

local maxStringLengthToRead = 64

local function readStateValue(address, key)
  if valueTypes[key] == "string" then
    return readString(address + values.o, maxStringLengthToRead)
  else
    -- float
    return readFloatBE(address + values.o, 4)
  end
end



local compute = {
    
  o = function()
    values.o = dolphin.getGameStartAddress()
  end,
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like the settings
    -- slider value) move by the same amount as the value change.
    local address = 0x801B78A8
    values.refPointer = readIntBE(address + values.o, 4)
  end,
  
  machineStateBlockAddress = function()
    local pointerAddress = values.refPointer + 0x22779C
    values.machineStateBlockAddress = readIntBE(pointerAddress + values.o, 4)
  end,
  
  machineBaseStatsBlockAddress = function()
    local machineIdAddress = values.machineStateBlockAddress + stateBlockOffsets.machineId
    local machineId = readIntBE(machineIdAddress + values.o, 2)
    values.machineBaseStatsBlockAddress = 0x81554000 + (0xB4*machineId)
  end,
  
  machineBaseStatsBlock2Address = function()
    -- A duplicate of the base stats block. We'll use this as a backup of the
    -- original values, when playing with the values in the primary block.
    local machineIdAddress = values.machineStateBlockAddress + stateBlockOffsets.machineId
    local machineId = readIntBE(machineIdAddress + values.o, 2)
    local firstMachineBlockAddress = values.refPointer + 0x195584
    values.machineBaseStatsBlock2Address = firstMachineBlockAddress + (0xB4*machineId)
  end,
  
  state = function(key)
    local address = values.machineStateBlockAddress + stateBlockOffsets[key]
    values.state[key] = readStateValue(address, key)
  end,
  
  stateOfOtherMachine = function(key, machineIndex)
    local address = (values.machineStateBlockAddress
      + (0x620 * machineIndex)
      + stateBlockOffsets[key])
      
    if values.state[machineIndex] == nil then
      values.state[machineIndex] = {}
    end
    
    values.state[machineIndex][key] = readStateValue(address, key)
  end,
  
  kmh = function()
    -- This address has your km/h speed as displayed in-game on the
    -- *next* frame.
    -- There is no known address for the displayed speed on the current frame,
    -- but we can get that by just taking the previous km/h value.
    local address = values.machineStateBlockAddress + stateBlockOffsets.kmh
    
    values.currKmh = values.nextKmh
    values.nextKmh = readFloatBE(address + values.o, 4)
  end,
  
  numOfMachinesParticipating = function()
    local address = values.refPointer + 0x1BAEE0
    values.numOfMachinesParticipating = readIntBE(address + values.o, 1)
  end,
}



-- Displaying RAM values.

local keysToLabels = {
  energy = "Energy",
  currKmh = "km/h",
  nextKmh = "km/h (next)",
}

local getStr = {
  
  settingsSlider = function()
    -- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
    local address = values.refPointer + 0x2453A0
    local settingsSlider = readIntBE(address + values.o, 4)
    
    return string.format("Settings: %d%%", settingsSlider)
  end,
  
  flt = function(key, precision)
    local label = keysToLabels[key]
    
    if values[key] == nil then
      return string.format("%s: nil", label)
    end
    
    return string.format("%s: %s", label, floatToStr(values[key], precision))
  end,
  
  state = function(key, precision)
    if precision == nil then precision = 4 end
    
    local label, value = nil, nil
    
    compute.state(key)
    label = keysToLabels[key]
    value = values.state[key]
    
    return string.format(
      "%s: %s", label, floatToStr(value, precision, true)
    )
  end,
  
  stateOfOtherMachine = function(key, machineIndex, precision)
    if precision == nil then precision = 4 end
  
    local index = tonumber(machineIndex)
    if index == nil then return "nil" end
    index = math.floor(index)
  
    if index+1 > values.numOfMachinesParticipating then
      return string.format("Rival machine %d is N/A", index)
    end
    
    compute.stateOfOtherMachine(key, index)
    compute.stateOfOtherMachine("machineName", index)
    local label = (keysToLabels[key] .. ", "
                   .. tostring(values.state[index]["machineName"]))
    return string.format(
      "%s: %s",
      label,
      floatToStr(values.state[index][key], precision, true)
    )
  end,
}



local mainLabel = nil

-- Stuff for the stat layouts.

local editableStats = {}
local checkBoxes = {}
local statsToDisplay = {}
local addToListButtons = {}
local editButtons = {}
local updateButton = nil

local function updateStatDisplay()
  compute.o()
  compute.refPointer()
  compute.machineStateBlockAddress()
  compute.machineBaseStatsBlockAddress()
  compute.machineBaseStatsBlock2Address()
  
  local statLines = {}
  for _, stat in pairs(statsToDisplay) do
    local line = stat:getDisplay()
    if stat:hasChanged() then line = line.."*" end
    table.insert(statLines, line)
  end
  mainLabel:setCaption(table.concat(statLines, "\n"))
end

local function openStatEditWindow(initialText, windowTitle, setValue, resetValue)
  local font = nil
  
  -- Create an edit window
  local window = createForm(true)
  window:setSize(400, 50)
  window:centerScreen()
  window:setCaption(windowTitle)
  font = window:getFont()
  font:setName("Calibri")
  font:setSize(10)
  
  -- Add a text box, with the baseStat value, full decimal places
  local statField = createEdit(window)
  statField:setPosition(70, 10)
  statField:setSize(200, 20)
  statField.Text = initialText
  
  -- Put an OK button in the window, which would change the base stat
  -- to the value entered, and close the window
  local okButton = createButton(window)
  okButton:setPosition(300, 10)
  okButton:setCaption("OK")
  okButton:setSize(30, 25)
  local confirmValueAndCloseWindow = function(window, statField)
    local newValue = tonumber(statField.Text)
    if newValue ~= nil then
      setValue(newValue)
      
      -- Update the display. Delay for a bit first, because it seems that the
      -- write to the memory address needs a bit of time to take effect.
      sleep(50)
      updateStatDisplay()
    end
    window:close()
  end
  
  local okAction = utils.curry(confirmValueAndCloseWindow, window, statField)
  okButton:setOnClick(okAction)
  
  -- Put a Cancel button in the window, which would close the window
  local cancelButton = createButton(window)
  cancelButton:setPosition(340, 10)
  cancelButton:setCaption("Cancel")
  cancelButton:setSize(50, 25)
  local closeWindow = function(window)
    window:close()
  end
  cancelButton:setOnClick(utils.curry(closeWindow, window))
  
  -- Add a reset button, which would reset the value to baseStat2
  local resetButton = createButton(window)
  resetButton:setPosition(5, 10)
  resetButton:setCaption("Reset")
  resetButton:setSize(50, 25)
  resetButton:setOnClick(utils.curry(resetValue, statField))
  
  -- Put the initial focus on the stat field.
  statField:setFocus()
end

local function addAddressToList(entry)
  local addressList = getAddressList()
  local memoryRecord = addressList:createMemoryRecord()
  
  -- setAddress doesn't work for some reason, despite being in the Help docs?
  memoryRecord.Address = utils.intToHexStr(entry.address)
  memoryRecord:setDescription(entry.description)
  memoryRecord.Type = entry.displayType
  memoryRecord.CustomTypeName = entry.customTypeName
end

local function rebuildStatsDisplay(window)
  statsToDisplay = {}
  
  -- Remove the previous buttons
  for _, button in pairs(addToListButtons) do
    button.destroy()
  end
  for _, button in pairs(editButtons) do
    button.destroy()
  end
  addToListButtons = {}
  editButtons = {}
  
  for boxN, checkBox in pairs(checkBoxes) do
    if checkBox:getState() == cbChecked then
      -- Box is checked; include this stat in the display.
      
      -- Include the stat display
      local stat = editableStats[boxN]
      table.insert(statsToDisplay, stat)
      
      -- Include an edit button
      local editButton = createButton(window)
      local posY = 28*(#statsToDisplay - 1) + 5
      editButton:setPosition(250, posY)
      editButton:setCaption("Edit")
      editButton:setSize(40, 20)
      local font = editButton:getFont()
      font:setSize(10)
      
      editButton:setOnClick(utils.curry(stat.openEditWindow, stat))
      table.insert(editButtons, editButton)
  
      -- Include an add-to-address-list button
      local listButton = createButton(window)
      local posY = 28*(#statsToDisplay - 1) + 5
      listButton:setPosition(300, posY)
      listButton:setCaption("List")
      listButton:setSize(40, 20)
      local font = listButton:getFont()
      font:setSize(10)
      
      listButton:setOnClick(utils.curry(stat.addAddressesToList, stat))
      table.insert(addToListButtons, listButton)
    end
  end
end

local function addStatCheckboxes(window, initiallyCheckedStats)
  -- Make a list of checkboxes, one for each possible stat to look at.
    
  -- Making sets in Lua is kind of roundabout.
  -- http://www.lua.org/pil/11.5.html
  local isStatInitiallyChecked = {}
  for _, stat in pairs(initiallyCheckedStats) do
    isStatInitiallyChecked[stat.label] = true
  end
  
  for statN, stat in pairs(editableStats) do
    local checkBox = createCheckBox(window)
    local posY = 20*(statN-1) + 5
    checkBox:setPosition(350, posY)
    checkBox:setCaption(stat.label)
    
    local font = checkBox:getFont()
    font:setSize(9)
    
    -- When a checkbox is checked, the corresponding stat is displayed.
    checkBox:setOnChange(utils.curry(rebuildStatsDisplay, window))
    
    if isStatInitiallyChecked[stat.label] then
      checkBox:setState(cbChecked)
    end
    
    table.insert(checkBoxes, checkBox)
  end
  
  -- Ensure that the initially checked stats actually get initially checked.
  rebuildStatsDisplay(window)
end



local Stat = {}

function Stat:new(label, stateBlockOffset, baseStatsBlockOffset)
  local newObj = {
    -- Note that these parameters are optional, any unspecified ones
    -- will just become nil.
    label = label,
    stateBlockOffset = stateBlockOffset,
    baseStatsBlockOffset = baseStatsBlockOffset,
  }
  setmetatable(newObj, self)
  self.__index = self
  
  return newObj
end
  
function Stat:getCurrent()
  local address = values.machineStateBlockAddress + self.stateBlockOffset
  return readFloatBE(address + values.o, 4)
end

function Stat:getDisplay(precision)
  if precision == nil then precision = 4 end

  local value = self:getCurrent()
  return string.format(
    "%s: %s",
    self.label,
    floatToStr(value, precision, true)
  )
end
  
function Stat:getBase(precision)
  local address = (values.machineBaseStatsBlockAddress
    + self.baseStatsBlockOffset)
  return readFloatBE(address + values.o, 4)
end
  
function Stat:getBase2(precision)
  local address = (values.machineBaseStatsBlock2Address
    + self.baseStatsBlockOffset)
  return readFloatBE(address + values.o, 4)
end

function Stat:getBaseDisplay(precision)
  if precision == nil then precision = 4 end

  local value = self:getBase()
  return string.format(
    "%s: %s",
    self.label .. " (B)",
    floatToStr(value, precision, true)
  )
end

function Stat:hasChanged()
  -- Implementation: Check if the primary and backup base stats are different.
  --
  -- Limitation: Assumes that you only change stats by changing their base
  -- values, rather than their actual values.
  --
  -- Limitation: Does not account for base -> actual formulas in two ways:
  -- (1) Actual values of other stats could be changed by changing the base
  -- value of Accel. (2) Actual values could stay the same even when the base
  -- value is different.
  --
  -- Limitation: If the game is paused, then the actual value will not reflect
  -- the base value yet. So the "this is changed" display can be misleading
  -- if you forget that.
  return self:getBase() ~= self:getBase2()
end

function Stat:openEditWindow()
  local initialText = tostring(self:getBase())
  local windowTitle = string.format("Edit: %s base value", self.label)
  
  local setValue = function(v)
    local address = (values.machineBaseStatsBlockAddress
      + self.baseStatsBlockOffset)
    utils.writeFloatBE(address + values.o, v, 4)
  end
  
  local resetValue = function(statField)
    statField.Text = tostring(self:getBase2())
  end
  
  openStatEditWindow(initialText, windowTitle, setValue, resetValue)
end

function Stat:addAddressesToList()
  -- We'll add two entries: actual stat and base stat.
  -- The base stat is more convenient to edit, because the actual stat usually
  -- needs disabling an instruction (which writes to the address every frame)
  -- before it can be edited.
  -- On the other hand, editing the actual stat avoids having to
  -- consider the base -> actual conversion math.
  
  -- Actual stat
  addAddressToList({
    address = values.machineStateBlockAddress + self.stateBlockOffset + values.o,
    description = self.label,
    -- For the memory record type constants, look up defines.lua in
    -- your Cheat Engine folder.
    displayType = vtCustom,
    customTypeName = "Float Big Endian",
  })
  
  -- Base stat
  addAddressToList({
    address = (values.machineBaseStatsBlockAddress
      + self.baseStatsBlockOffset + values.o),
    description = self.label .. " (base)",
    displayType = vtCustom,
    customTypeName = "Float Big Endian",
  })
end



local TiltStat = {}
setmetatable(TiltStat, Stat)

function TiltStat:new(label, stateBlockOffsets, baseStatsBlockOffsets, formulas)
  local newObj = {
    label = label,
    stateBlockOffsets = stateBlockOffsets,
    baseStatsBlockOffsets = baseStatsBlockOffsets,
    formulas = formulas,
  }
  setmetatable(newObj, self)
  self.__index = self
  
  return newObj
end
  
function TiltStat:getCurrent(key)
  if key == nil then key = "a" end

  local address = values.machineStateBlockAddress + self.stateBlockOffsets[key]
  return readFloatBE(address + values.o, 4)
end
  
function TiltStat:getBase(key, precision)
  if key == nil then key = "a" end

  local address = (values.machineBaseStatsBlockAddress
    + self.baseStatsBlockOffsets[key])
  return readFloatBE(address + values.o, 4)
end
  
function TiltStat:getBase2(key, precision)
  if key == nil then key = "a" end

  local address = (values.machineBaseStatsBlock2Address
    + self.baseStatsBlockOffsets[key])
  return readFloatBE(address + values.o, 4)
end

function TiltStat:hasChanged()
  -- Since we change the actual value directly, and there is no
  -- base -> actual formula, we check actual vs. base here.
  return self:getCurrent() ~= self:getBase2()
end

function TiltStat:openEditWindow()
  local initialText = tostring(self:getCurrent())
  local windowTitle = string.format("Edit: %s actual values", self.label)
  
  local setValue = function(v)
    -- Change actual values directly; changing base doesn't change actual here
    for key, func in pairs(self.formulas) do
      local address = (values.machineStateBlockAddress
        + self.stateBlockOffsets[key])
      utils.writeFloatBE(address + values.o, func(v), 4)
    end
  end
  
  local resetValue = function(statField)
    statField.Text = tostring(self:getBase2())
  end
  
  openStatEditWindow(initialText, windowTitle, setValue, resetValue)
end

function TiltStat:addAddressesToList()
  -- Only add the actual stats here. Changing the base tilt values
  -- doesn't change the actual values, so no particular use in adding
  -- base values to the list.
  for key, func in pairs(self.formulas) do
    addAddressToList({
      address = values.machineStateBlockAddress + self.stateBlockOffsets[key] + values.o,
      description = self.label .. key,
      displayType = vtCustom,
      customTypeName = "Float Big Endian",
    })
  end
end



local accel = Stat:new("Accel", 0x220, 0x8)
local body = Stat:new("Body", 0x30, 0x44)
local boostInterval = Stat:new("Boost interval", 0x234, 0x38)
local boostStrength = Stat:new("Boost strength", 0x230, 0x34)
local cameraReorienting = Stat:new("Cam. reorienting", 0x34, 0x4C)
local cameraRepositioning = Stat:new("Cam. repositioning", 0x38, 0x50)
local drag = Stat:new("Drag", 0x23C, 0x40)
local driftAccel = Stat:new("Drift accel", 0x2C, 0x1C) 
local grip1 = Stat:new("Grip 1", 0xC, 0x10)
local grip2 = Stat:new("Grip 2", 0x24, 0x30)
local grip3 = Stat:new("Grip 3", 0x28, 0x14)
local maxSpeed = Stat:new("Max speed", 0x22C, 0xC)
local obstacleCollision = Stat:new("Obstacle collision", 0x584)
local strafe = Stat:new("Strafe", 0x1C, 0x28)
local strafeTurn = Stat:new("Strafe turn", 0x18, 0x24)
local trackCollision = Stat:new("Track collision", 0x588, 0x9C)
local turnDecel = Stat:new("Turn decel", 0x238, 0x3C)
local turning1 = Stat:new("Turning 1", 0x10, 0x18)
local turning2 = Stat:new("Turning 2", 0x14, 0x20)
local turning3 = Stat:new("Turning 3", 0x20, 0x2C)
local weight = Stat:new("Weight", 0x8, 0x4)

local tilt1 = TiltStat:new(
  "Tilt 1",
  {a = 0x24C, b = 0x2A8, c = 0x3B4, d = 0x3E4},
  {a = 0x54, b = 0x60, c = 0x84, d = 0x90},
  {
    a = function(v) return v end,
    b = function(v) return -v end,
    c = function(v) return v+0.2 end,
    d = function(v) return -(v+0.2) end,
  }
)
local tilt2 = TiltStat:new(
  "Tilt 2",
  {a = 0x254, b = 0x2B0, c = 0x3BC, d = 0x3EC},
  {a = 0x5C, b = 0x68, c = 0x8C, d = 0x98},
  {
    a = function(v) return v end,
    b = function(v) return v end,
    c = function(v) return v-0.2 end,
    d = function(v) return v-0.2 end,
  }
)
local tilt3 = TiltStat:new(
  "Tilt 3",
  {a = 0x304, b = 0x360, c = 0x414, d = 0x444},
  {a = 0x6C, b = 0x78, c = 0x9C, d = 0xA8},
  {
    a = function(v) return v end,
    b = function(v) return -v end,
    c = function(v) return v+0.2 end,
    d = function(v) return -(v+0.2) end,
  }
)
local tilt4 = TiltStat:new(
  "Tilt 4",
  {a = 0x30C, b = 0x368, c = 0x41C, d = 0x44C},
  {a = 0x74, b = 0x80, c = 0xA4, d = 0xB0},
  {
    a = function(v) return v end,
    b = function(v) return v end,
    c = function(v) return v+0.2 end,
    d = function(v) return v+0.2 end,
  }
)



-- Obstacle collision has no value in the base stats block.
function obstacleCollision:getBase() return nil end

function obstacleCollision:getBase2() return nil end

-- Since there is no base stat to refer to, we don't know if the
-- stat has changed.
function obstacleCollision:hasChanged() return false end

function obstacleCollision:openEditWindow()
  local initialText = tostring(self:getCurrent())
  local windowTitle = string.format("Edit: %s actual value", self.label)
  
  local setValue = function(v)
    -- Change the actual stat, since there's no base stat.
    local address = (values.machineStateBlockAddress
      + self.stateBlockOffset)
    utils.writeFloatBE(address + values.o, v, 4)
  end
  
  -- No base value, so don't know how to reset the value.
  local resetValue = function(statField) return end
  
  openStatEditWindow(initialText, windowTitle, setValue, resetValue)
end

function obstacleCollision:addAddressesToList()
  -- Add the actual stat, since there's no base stat.
  addAddressToList({
    address = values.machineStateBlockAddress + self.stateBlockOffset + values.o,
    description = self.label,
    displayType = vtCustom,
    customTypeName = "Float Big Endian",
  })
end


-- Treat track collision the same as obstacle collision for now.
-- But need to determine the relationship between trackCollision and Tilt 3.
setmetatable(trackCollision, obstacleCollision)
obstacleCollision.__index = obstacleCollision



editableStats = {
  accel, body, boostInterval, boostStrength,
  cameraReorienting, cameraRepositioning, drag, driftAccel,
  grip1, grip2, grip3, maxSpeed, obstacleCollision,
  strafeTurn, strafe, tilt1, tilt2, tilt3, tilt4, 
  trackCollision, turnDecel, turning1, turning2, turning3, weight,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI layout specifications.

local statRecorder = {}

local layoutA = {
  
  init = function(window)
    -- Set the display window's size.
    window:setSize(300, 200)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    mainLabel = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 160, "<debug>")
    
    statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.kmh()
    mainLabel:setCaption(
      table.concat(
        {
          getStr.settingsSlider(),
          getStr.flt("currKmh", 3),
        },
        "\n"
      )
    )
    
    if statRecorder.currentlyTakingStats then
      local s = floatToStr(values.currKmh, 6)
      statRecorder:takeStat(s)
    end
  end,
}

local layoutB = {
  
  init = function(window)
    window:setSize(400, 300)
  
    mainLabel = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 220, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.numOfMachinesParticipating()
    mainLabel:setCaption(
      table.concat(
        {
          getStr.state("energy"),
          getStr.stateOfOtherMachine("energy", 1),
          getStr.stateOfOtherMachine("energy", 2),
          getStr.stateOfOtherMachine("energy", 3),
          getStr.stateOfOtherMachine("energy", 4),
          getStr.stateOfOtherMachine("energy", 5),
        },
        "\n"
      )
    )
  end,
}

local layoutC = {
  
  init = function(window)
    window:setSize(300, 130)
  
    mainLabel = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.machineBaseStatsBlockAddress()
    mainLabel:setCaption(
      table.concat(
        {
          turning2:getBaseDisplay(),
          turning2:getDisplay(),
        },
        "\n"
      )
    )
  end,
}



local layoutD = {
  
  init = function(window)
    window:setSize(550, 510)
  
    mainLabel = initLabel(window, 10, 5, "")
    local font = mainLabel:getFont()
    font:setSize(14)

    local initiallyCheckedStats = {accel, maxSpeed, weight}
    addStatCheckboxes(window, initiallyCheckedStats)
    
    --shared.debugLabel = initLabel(window, 10, 350, "")
  end,
  
  update = function()
    updateStatDisplay()
  end,
}



local layoutE = {
  
  -- Version of layoutD that updates the display with an update button,
  -- instead of automatically on every frame. This is fine because the stats
  -- don't change often (only when you change them, or change machine or
  -- settings).
  -- By not updating on every frame, this version can keep Dolphin running
  -- much more smoothly.
  
  onlyUpdateManually = true,
  
  init = function(window)
    window:setSize(550, 510)
  
    mainLabel = initLabel(window, 10, 5, "")
    local font = mainLabel:getFont()
    font:setSize(14)

    local initiallyCheckedStats = {accel, maxSpeed, weight}
    addStatCheckboxes(window, initiallyCheckedStats)
    
    updateButton = createButton(window)
    updateButton:setPosition(10, 460)
    updateButton:setCaption("Update")
    local font = updateButton:getFont()
    font:setSize(12)
    
    -- Update the display via a button this time,
    -- instead of via a function that auto-runs on every frame.
    updateButton:setOnClick(updateStatDisplay)
    updateStatDisplay()
    
    --shared.debugLabel = initLabel(window, 10, 350, "")
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutA



-- Initializing the GUI window.

local window = createForm(true)
-- Put it in the center of the screen.
window:centerScreen()
-- Set the window title.
window:setCaption("RAM Display")
-- Customize the font.
local font = window:getFont()
font:setName("Calibri")
font:setSize(16)

layout.init(window)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- This sets a breakpoint at a particular instruction which should be
-- called exactly once every frame. (Unless the layout doesn't require it.)

debug_removeBreakpoint(getAddress("Dolphin.exe")+dolphin.oncePerFrameAddress)
if not layout.onlyUpdateManually then
  debug_setBreakpoint(getAddress("Dolphin.exe")+dolphin.oncePerFrameAddress)
end

-- If the oncePerFrameAddress was chosen correctly, everything in the
-- following function should run exactly once every frame. 

function debugger_onBreakpoint()
  
  layout.update()

  return 1

end

