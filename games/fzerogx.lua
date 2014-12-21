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

local stateOffsets = {
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
  
  machineId = function()
    local machineIdAddress = values.machineStateBlockAddress + stateOffsets.machineId
    values.machineId = readIntBE(machineIdAddress + values.o, 2)
  end,
  
  machineBaseStatsBlockAddress = function()
    values.machineBaseStatsBlockAddress = 0x81554000 + (0xB4*values.machineId)
  end,
  
  machineBaseStatsBlock2Address = function()
    -- A duplicate of the base stats block. We'll use this as a backup of the
    -- original values, when playing with the values in the primary block.
    local firstMachineBlockAddress = values.refPointer + 0x195584
    values.machineBaseStatsBlock2Address = firstMachineBlockAddress + (0xB4*values.machineId)
  end,
  
  state = function(key)
    local address = values.machineStateBlockAddress + stateOffsets[key]
    values.state[key] = readStateValue(address, key)
  end,
  
  stateOfOtherMachine = function(key, machineIndex)
    local address = (values.machineStateBlockAddress
      + (0x620 * machineIndex)
      + stateOffsets[key])
      
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
    local address = values.machineStateBlockAddress + stateOffsets.kmh
    
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
  compute.machineId()
  compute.machineBaseStatsBlockAddress()
  compute.machineBaseStatsBlock2Address()
  
  local statLines = {}
  for _, stat in pairs(statsToDisplay) do
    local line = stat:getDisplay()
    if stat.hasChanged ~= nil and stat:hasChanged() then
      line = line.."*"
    end
    table.insert(statLines, line)
  end
  mainLabel:setCaption(table.concat(statLines, "\n"))
end

local function openValueEditWindow(initialText, windowTitle, setValue, resetValue)
  local font = nil
  
  -- Create an edit window
  local window = createForm(true)
  window:setSize(400, 50)
  window:centerScreen()
  window:setCaption(windowTitle)
  font = window:getFont()
  font:setName("Calibri")
  font:setSize(10)
  
  -- Add a text box with the current value
  local statField = createEdit(window)
  statField:setPosition(70, 10)
  statField:setSize(200, 20)
  statField.Text = initialText
  
  -- Put an OK button in the window, which would change the value
  -- to the text field contents, and close the window
  local okButton = createButton(window)
  okButton:setPosition(300, 10)
  okButton:setCaption("OK")
  okButton:setSize(30, 25)
  local confirmValueAndCloseWindow = function(window, statField)
    setValue(statField.Text)
    
    -- Update the display. Delay for a bit first, because it seems that the
    -- write to the memory address needs a bit of time to take effect.
    -- TODO: Use Timer instead of sleep?
    sleep(50)
    updateStatDisplay()
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
  
  -- Add a reset button, if applicable
  if resetValue then
    local resetButton = createButton(window)
    resetButton:setPosition(5, 10)
    resetButton:setCaption("Reset")
    resetButton:setSize(50, 25)
    resetButton:setOnClick(utils.curry(resetValue, statField))
  end
  
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
  if entry.displayType == vtCustom then
    memoryRecord.CustomTypeName = entry.customTypeName
  elseif entry.displayType == vtBinary then
    -- TODO: Can't figure out how to set the start bit and size.
    -- And this entry is useless if it's a 0-sized Binary display (which is
    -- default). Best we can do is to make this entry a Byte...
    --memoryRecord.Binary.Startbit = entry.binaryStartBit
    --memoryRecord.Binary.Size = entry.binarySize
    memoryRecord.Type = vtByte
  end
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



local StateValue = {}

function StateValue:getAddress()
  return values.machineStateBlockAddress + self.stateOffset + values.o
end

function StateValue:get()
  return self.read(self:getAddress(), self.numOfBytes)
end

function StateValue:getDisplay(...)
  local value = self:get()
  return self.label .. ": " .. self.toStr(value, ...)
end

function StateValue:set(v)
  self.write(self:getAddress(), v, self.numOfBytes)
end

function StateValue:openEditWindow()
  -- Use tostring instead of self.toStr() to ensure that the raw value (e.g.
  -- full float decimal places) is there. We want accuracy here, not fluff.
  local initialText = tostring(self:get())
  local windowTitle = string.format("Edit: %s value", self.label)
  local setValue = function(s)
    local v = tonumber(s)
    if v ~= nil then self:set(v) end
  end
  
  -- Normal values don't have a reference value to use for resetting.
  local resetValue = nil
  
  openValueEditWindow(initialText, windowTitle, setValue, resetValue)
end

function StateValue:addAddressesToList()
  addAddressToList({
    address = self:getAddress(),
    description = self.label,
    -- For the memory record type constants, look up defines.lua in
    -- your Cheat Engine folder.
    displayType = self.addressListType,
    -- Just give all the possible fields, and let addAddressToList figure out
    -- what needs to be used.
    customTypeName = self.addressListCustomTypeName,
    binaryStartBit = self.binaryStartBit,
    binarySize = self.binarySize,
  })
end



function StateValue:new(label, stateOffset, classes, extraArgs)
  local newObj = {
    -- Note that these parameters are optional, any unspecified ones
    -- will just become nil.
    label = label,
    stateOffset = stateOffset,
  }
  setmetatable(newObj, self)
  self.__index = self
  
  -- The below is a simple implementation of mixins. This lets us get
  -- some attributes from one class and some attributes from another class.
  
  for _, class in pairs(classes) do
    for key, value in pairs(class) do
      newObj[key] = value
    end
    if class.extraArgs then
      for _, argName in pairs(class.extraArgs) do
        -- TODO: Would be nice to have a good way of enforcing that the
        -- extraArgs needed are present.
        newObj[argName] = extraArgs[argName]
      end
    end
  end
  
  return newObj
end

-- Kind of like inheritance, except it just copies the fields from the parents
-- to the children. This means no "super" calls. This also means you can
-- easily have multiple parents ordered by priority.
function copyFields(child, parents)
  for _, parent in pairs(parents) do
    for key, value in pairs(parent) do
      if key == "extraArgs" then
        -- Add the parent's extraArgs to the child's. 
        for _, name in pairs(value) do
          table.insert(child.extraArgs, name)
        end
      else
        -- For any non-extraArgs field, just set the value directly.
        child[key] = value
      end
    end
  end
end



local FloatValue = {}
FloatValue.read = utils.readFloatBE
FloatValue.write = utils.writeFloatBE
FloatValue.toStr = function(v, precision, trimTrailingZeros)
  if precision == nil then precision = 4 end
  if trimTrailingZeros == nil then trimTrailingZeros = false end
  return utils.floatToStr(v, precision, trimTrailingZeros)
end
FloatValue.numOfBytes = 4
FloatValue.addressListType = vtCustom
FloatValue.addressListCustomTypeName = "Float Big Endian"

local IntValue = {}
IntValue.read = utils.readIntBE
IntValue.write = utils.writeIntBE
IntValue.toStr = tostring
IntValue.numOfBytes = 4
IntValue.addressListType = vtCustom
IntValue.addressListCustomTypeName = "4 Byte Big Endian"

local ByteValue = {}
ByteValue.read = utils.readIntBE
ByteValue.write = utils.writeIntBE
ByteValue.toStr = tostring
ByteValue.numOfBytes = 1
ByteValue.addressListType = vtByte



local BinaryValue = {}
BinaryValue.extraArgs = {"binarySize", "binaryStartBit"}
BinaryValue.addressListType = vtBinary



function BinaryValue.read(address, firstBit, binarySize)
  -- address is the byte address
  -- Possible startBit values from left to right: 76543210
  -- Returns: a table of the bits
  -- For now, we only support binary values contained in a single byte.
  local byte = utils.readIntBE(address, 1)
  local lastBit = firstBit - binarySize + 1
  local bits = {}
  for bitNumber = firstBit, lastBit, -1 do
    -- Check if the byte has 1 or 0 in this position.
    if 2^bitNumber == bAnd(byte, 2^bitNumber) then
      table.insert(bits, 1)
    else
      table.insert(bits, 0)
    end
  end
  return bits
end

function BinaryValue:get()
  return self.read(self:getAddress(), self.binaryStartBit, self.binarySize)
end

function BinaryValue.write(address, firstBit, binarySize, v)
  -- v is a table of the bits
  -- For now, we only support binary values contained in a single byte.
  
  -- Start with the current byte value. Then write the bits that need to
  -- be written.
  local byte = utils.readIntBE(address, 1)
  local lastBit = firstBit - binarySize + 1
  local bitCount = 0
  for bitNumber = firstBit, lastBit, -1 do
    bitCount = bitCount + 1
    if v[bitCount] == 1 then
      byte = bOr(byte, 2^bitNumber)
    else
      byte = bAnd(byte, 255 - 2^bitNumber)
    end
  end
  utils.writeIntBE(address, byte, 1)
end

function BinaryValue:set(v)
  self.write(self:getAddress(), self.binaryStartBit, self.binarySize, v)
end

function BinaryValue.toStr(v)
  -- v is a table of bits
  local s = ""
  for _, bit in pairs(v) do
    s = s .. tostring(bit)
  end
  return s
end

function BinaryValue:bitStrToTable(s)
  local bits = {}
  -- Iterate over string characters (http://stackoverflow.com/a/832414)
  for singleBitStr in s:gmatch"." do
    if singleBitStr == "1" then
      table.insert(bits, 1)
    elseif singleBitStr == "0" then
      table.insert(bits, 0)
    else
      return nil
    end
  end
  if self.binarySize ~= #bits then return nil end
  return bits
end

function BinaryValue:openEditWindow()
  local initialText = self.toStr(self:get())
  local windowTitle = string.format("Edit: %s value", self.label)
  local setValue = function(bitStr)
    local v = self:bitStrToTable(bitStr)
    if v ~= nil then self:set(v) end
  end
  
  local resetValue = nil
  
  openValueEditWindow(initialText, windowTitle, setValue, resetValue)
end



local StatWithBase = {}

StatWithBase.extraArgs = {"baseOffset"}

function StatWithBase:getBaseAddress()
  return values.o + values.machineBaseStatsBlockAddress + self.baseOffset
end

function StatWithBase:getBase2Address()
  return values.o + values.machineBaseStatsBlock2Address + self.baseOffset
end
  
function StatWithBase:getBase()
  return self.read(self:getBaseAddress(), self.numOfBytes)
end
  
function StatWithBase:getBase2()
  return self.read(self:getBase2Address(), self.numOfBytes)
end

function StatWithBase:getBaseDisplay(...)
  local value = self:getBase()
  return self.label .. " (B): " .. self.toStr(value, ...)
end

function StatWithBase:hasChanged()
  -- Implementation: Check if the actual value and backup base value
  -- are the same.
  --
  -- Assumes you don't go into the memory and change the backup base value.
  --
  -- Assumes there is no formula between the base and actual values,
  -- though this can be changed for specific stats by overriding this function.
  --
  -- Limitation: If the game is paused, then the actual value will not reflect
  -- the base value yet. So the "this is changed" display can be misleading
  -- if you forget that.
  return self:get() ~= self:getBase2()
end

function StatWithBase:openEditWindow()
  local initialText = tostring(self:get())
  local windowTitle = string.format("Edit: %s actual value", self.label)
  
  local setValue = function(s)
    local v = tonumber(s)
    if v ~= nil then self:set(v) end
  end
  
  local resetValue = function(statField)
    statField.Text = tostring(self:getBase2())
  end
  
  openValueEditWindow(initialText, windowTitle, setValue, resetValue)
end



local StatTiedToBase = {}

StatTiedToBase.extraArgs = {}
copyFields(StatTiedToBase, {StatWithBase})

function StatTiedToBase:hasChanged()
  -- Implementation: Check if the primary and backup base values are different.
  --
  -- Assumes that you only change this stat by changing its base
  -- values, rather than the actual value.
  --
  -- Does not fully account for base -> actual formulas in two ways:
  -- (1) Actual values of other stats could be changed by changing the base
  -- value of Accel (it's special that way).
  -- (2) Actual values could stay the same even when the base value
  -- is different. For example, Turn decel's actual value may be locked at
  -- 0.01 for a variety of base values.
  --
  -- Limitation: If the game is paused, then the actual value will not reflect
  -- the base value yet. So the "this is changed" display can be misleading
  -- if you forget that.
  return self:getBase() ~= self:getBase2()
end

function StatTiedToBase:openEditWindow()
  local initialText = tostring(self:getBase())
  local windowTitle = string.format("Edit: %s base value", self.label)
  
  local setValue = function(s)
    local v = tonumber(s)
    if v ~= nil then
      self.write(self:getBaseAddress(), v, self.numOfBytes)
    end
  end
  
  local resetValue = function(statField)
    statField.Text = tostring(self:getBase2())
  end
  
  openValueEditWindow(initialText, windowTitle, setValue, resetValue)
end

function StatTiedToBase:addAddressesToList()
  -- We'll add two entries: actual stat and base stat.
  -- The base stat is more convenient to edit, because the actual stat usually
  -- needs disabling an instruction (which writes to the address every frame)
  -- before it can be edited.
  -- On the other hand, editing the actual stat avoids having to
  -- consider the base -> actual conversion math.
  
  -- Actual stat
  addAddressToList({
    address = self:getAddress(),
    description = self.label,
    displayType = self.addressListType,
    customTypeName = self.addressListCustomTypeName,
    binaryBitPosition = self.binaryBitPosition,
  })
  
  -- Base stat
  addAddressToList({
    address = self:getBaseAddress(),
    description = self.label .. " (base)",
    displayType = self.addressListType,
    customTypeName = self.addressListCustomTypeName,
    binaryBitPosition = self.binaryBitPosition,
  })
end



local SizeStat = {}

SizeStat.extraArgs = {"specificLabels", "formulas"}
copyFields(SizeStat, {StatWithBase})
  
function SizeStat:get(key)
  if key == nil then key = 1 end

  local address = values.machineStateBlockAddress + self.stateOffset[key]
  return self.read(address + values.o, 4)
end
  
function SizeStat:getBase(key, precision)
  if key == nil then key = 1 end

  local address = (values.machineBaseStatsBlockAddress
    + self.baseOffset[key])
  return self.read(address + values.o, 4)
end
  
function SizeStat:getBase2(key, precision)
  if key == nil then key = 1 end

  local address = (values.machineBaseStatsBlock2Address
    + self.baseOffset[key])
  return self.read(address + values.o, 4)
end

function SizeStat:openEditWindow()
  local initialText = tostring(self:get())
  local windowTitle = string.format("Edit: %s actual values", self.label)
  
  local setValue = function(s)
    local v = tonumber(s)
    if v ~= nil then
      -- Change actual values directly; changing base doesn't change actual here
      for key, func in pairs(self.formulas) do
        local address = (values.machineStateBlockAddress
          + self.stateOffset[key])
        self.write(address + values.o, func(v), self.numOfBytes)
      end
    end
  end
  
  local resetValue = function(statField)
    statField.Text = tostring(self:getBase2())
  end
  
  openValueEditWindow(initialText, windowTitle, setValue, resetValue)
end

function SizeStat:addAddressesToList()
  -- Only add the actual stats here. Changing the base size values
  -- doesn't change the actual values, so no particular use in adding
  -- base values to the list.
  for key, specificLabel in pairs(self.specificLabels) do
    addAddressToList({
      address = values.machineStateBlockAddress + self.stateOffset[key] + values.o,
      description = specificLabel,
      displayType = self.addressListType,
      customTypeName = self.addressListCustomTypeName,
      binaryStartBit = self.binaryStartBit,
      binarySize = self.binarySize,
    })
  end
end



local FloatStat = {}

copyFields(FloatStat, {FloatValue})

FloatStat.toStr = function(v, precision, trimTrailingZeros)
  if precision == nil then precision = 4 end
  if trimTrailingZeros == nil then trimTrailingZeros = true end
  return utils.floatToStr(v, precision, trimTrailingZeros)
end



-- It's ugly design that this class exists, as it is mostly redundant
-- with BinaryValue and StatTiedToBase. Reasons for the messiness include:
-- 1. BinaryValue having to define get(), set(), and openEditWindow() which
--    are normally not datatype specific
-- 2. The need for involving a binary start bit into many of these kinds of
--    functions; and there is a different binary start bit for the actual
--    and base for the two binary machine stats

local BinaryValueTiedToBase = {}

BinaryValueTiedToBase.extraArgs = {"baseBinaryStartBit"}
copyFields(BinaryValueTiedToBase, {StatTiedToBase, BinaryValue})
  
function BinaryValueTiedToBase:getBase()
  return self.read(self:getBaseAddress(), self.baseBinaryStartBit, self.binarySize)
end
  
function BinaryValueTiedToBase:getBase2()
  return self.read(self:getBase2Address(), self.baseBinaryStartBit, self.binarySize)
end

function BinaryValueTiedToBase:hasChanged()
  local base = self:getBase()
  local base2 = self:getBase2()
  for index = 1, #base do
    if base[index] ~= base2[index] then return true end
  end
  return false
end
  
function BinaryValueTiedToBase:openEditWindow()
  local initialText = self.toStr(self:getBase())
  local windowTitle = string.format("Edit: %s base value", self.label)
  
  local setValue = function(bitStr)
    local v = self:bitStrToTable(bitStr)
    if v ~= nil then
      self.write(
        self:getBaseAddress(), self.baseBinaryStartBit, self.binarySize, v
      )
    end
  end
  
  local resetValue = function(statField)
    statField.Text = self.toStr(self:getBase2())
  end
  
  openValueEditWindow(initialText, windowTitle, setValue, resetValue)
end
  
function BinaryValueTiedToBase:addAddressesToList()
  -- Actual stat
  addAddressToList({
    address = self:getAddress(),
    description = self.label,
    displayType = self.addressListType,
    customTypeName = self.addressListCustomTypeName,
    binaryBitPosition = self.binaryBitPosition,
  })
  
  -- Base stat
  addAddressToList({
    address = self:getBaseAddress(),
    description = self.label .. " (base)",
    displayType = self.addressListType,
    customTypeName = self.addressListCustomTypeName,
    binaryBitPosition = self.baseBinaryStartBit,
  })
end



function GenericStat(label, stateOffset, baseOffset)
  return StateValue:new(
    label, stateOffset, {FloatStat, StatTiedToBase}, {baseOffset=baseOffset}
  )
end

local accel = GenericStat("Accel", 0x220, 0x8)
local body = GenericStat("Body", 0x30, 0x44)
local boostInterval = GenericStat("Boost interval", 0x234, 0x38)
local boostStrength = GenericStat("Boost strength", 0x230, 0x34)
local cameraReorienting = GenericStat("Cam. reorienting", 0x34, 0x4C)
local cameraRepositioning = GenericStat("Cam. repositioning", 0x38, 0x50)
local drag = GenericStat("Drag", 0x23C, 0x40)
local driftAccel = GenericStat("Drift accel", 0x2C, 0x1C) 
local grip1 = GenericStat("Grip 1", 0xC, 0x10)
local grip2 = GenericStat("Grip 2", 0x24, 0x30)
local grip3 = GenericStat("Grip 3", 0x28, 0x14)
local maxSpeed = GenericStat("Max speed", 0x22C, 0xC)
local obstacleCollision = StateValue:new(
  "Obstacle collision", 0x584, {FloatStat}, nil
)
local strafe = GenericStat("Strafe", 0x1C, 0x28)
local strafeTurn = GenericStat("Strafe turn", 0x18, 0x24)
local trackCollision = StateValue:new(
  "Track collision", 0x588, {FloatStat, StatWithBase}, {baseOffset=0x9C}
)
local turnDecel = GenericStat("Turn decel", 0x238, 0x3C)
local turning1 = GenericStat("Turning 1", 0x10, 0x18)
local turning2 = GenericStat("Turning 2", 0x14, 0x20)
local turning3 = GenericStat("Turning 3", 0x20, 0x2C)
local weight = GenericStat("Weight", 0x8, 0x4)
local unknown48 = StateValue:new(
  "Unknown 48", 0x477, {ByteValue, StatTiedToBase}, {baseOffset=0x48}
)

-- Actual is state bit 1; base is 0x49 / 2
local unknown49a = StateValue:new(
  "Unknown 49a", 0x0, {BinaryValueTiedToBase},
  {baseOffset=0x49, binarySize=1, binaryStartBit=7, baseBinaryStartBit=1}
)
-- Actual is state bit 24; base is 0x49 % 2
local unknown49b = StateValue:new(
  "Unknown 49b", 0x2, {BinaryValueTiedToBase},
  {baseOffset=0x49, binarySize=1, binaryStartBit=0, baseBinaryStartBit=0}
)

local frontWidth = StateValue:new(
  "Size, front width",
  {0x24C, 0x2A8, 0x3B4, 0x3E4},
  {FloatStat, SizeStat},
  {
    baseOffset={0x54, 0x60, 0x84, 0x90},
    specificLabels={
      "Tilt, front width, right",
      "Tilt, front width, left",
      "Wall collision, front width, right",
      "Wall collision, front width, left",
    },
    formulas={
      function(v) return v end,
      function(v) return -v end,
      function(v) return v+0.2 end,
      function(v) return -(v+0.2) end,
    },
  }
)
local frontLength = StateValue:new(
  "Size, front length",
  {0x254, 0x2B0, 0x3BC, 0x3EC},
  {FloatStat, SizeStat},
  {
    baseOffset={0x5C, 0x68, 0x8C, 0x98},
    specificLabels={
      "Tilt, front length, right",
      "Tilt, front length, left",
      "Wall collision, front length, right",
      "Wall collision, front length, left",
    },
    formulas={
      function(v) return v end,
      function(v) return v end,
      function(v) return v-0.2 end,
      function(v) return v-0.2 end,
    },
  }
)
local backWidth = StateValue:new(
  "Size, back width",
  {0x304, 0x360, 0x414, 0x444},
  {FloatStat, SizeStat},
  {
    baseOffset={0x6C, 0x78, 0x9C, 0xA8},
    specificLabels={
      "Tilt, back width, right",
      "Tilt, back width, left",
      "Wall collision, back width, right",
      "Wall collision, back width, left",
    },
    formulas={
      function(v) return v end,
      function(v) return -v end,
      function(v)
        -- Black Bull is 0.3, everyone else is 0.2
        if values.machineId == 29 then return v+0.3 else return v+0.2 end
      end,
      function(v)
        if values.machineId == 29 then return -(v+0.3) else return -(v+0.2) end
      end,
    },
  }
)
local backLength = StateValue:new(
  "Size, back length",
  {0x30C, 0x368, 0x41C, 0x44C},
  {FloatStat, SizeStat},
  {
    baseOffset={0x74, 0x80, 0xA4, 0xB0},
    specificLabels={
      "Tilt, back length, right",
      "Tilt, back length, left",
      "Wall collision, back length, right",
      "Wall collision, back length, left",
    },
    formulas={
      function(v) return v end,
      function(v) return v end,
      function(v) return v+0.2 end,
      function(v) return v+0.2 end,
    },
  }
)



editableStats = {
  accel, body, boostInterval, boostStrength,
  cameraReorienting, cameraRepositioning, drag, driftAccel,
  grip1, grip2, grip3, maxSpeed, obstacleCollision,
  strafeTurn, strafe, trackCollision, turnDecel,
  turning1, turning2, turning3, weight,
  backLength, backWidth, frontLength, frontWidth,
  unknown48, unknown49a, unknown49b,
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
    compute.machineId()
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
    window:setSize(550, 570)
  
    mainLabel = initLabel(window, 10, 5, "")
    local font = mainLabel:getFont()
    font:setSize(14)
    
    --shared.debugLabel = initLabel(window, 10, 350, "")

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

