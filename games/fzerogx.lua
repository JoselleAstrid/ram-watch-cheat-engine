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

local addrs = {}



-- Compute functions for some addresses.

local computeAddr = {
    
  o = function()
    return dolphin.getGameStartAddress()
  end,
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like the settings
    -- slider value) move by the same amount as the value change.
    return addrs.o + readIntBE(addrs.o + 0x801B78A8, 4)
  end,
  
  machineStateBlocks = function()
    local pointerAddress = addrs.refPointer + 0x22779C
    return addrs.o + readIntBE(pointerAddress, 4)
  end,
  
  machineBaseStatsBlocks = function()
    return addrs.o + 0x81554000
  end,
  
  machineBaseStatsBlocks2 = function()
    -- A duplicate of the base stats block. We'll use this as a backup of the
    -- original values, when playing with the values in the primary block.
    return addrs.refPointer + 0x195584
  end,
}

local function updateAddresses()
  addrs.o = computeAddr.o()
  addrs.refPointer = computeAddr.refPointer()
  addrs.machineStateBlocks = computeAddr.machineStateBlocks(machineIndex)
  addrs.machineBaseStatsBlocks = computeAddr.machineBaseStatsBlocks(machineIndex)
  addrs.machineBaseStatsBlocks2 = computeAddr.machineBaseStatsBlocks2(machineIndex)
end



-- Forward declarations.
local forMachineI = nil
local machineId = nil
local machineIndexIsValid = nil
local machineName = nil
local numOfRaceEntrants = nil



-- Stuff for an advanced UI scheme, with togglable value displays, edit
-- functions, and add-to-list functions.

local mainLabel = nil

local trackedValues = {}
local checkBoxes = {}
local valuesToDisplay = {}
local addToListButtons = {}
local editButtons = {}
local updateButton = nil

local function updateValueDisplay()
  updateAddresses()
  
  local lines = {}
  for n, v in pairs(valuesToDisplay) do
    table.insert(lines, v:getDisplay())
    
    local isValid = v:isValid()
    addToListButtons[n]:setEnabled(isValid)
    editButtons[n]:setEnabled(isValid)
  end
  mainLabel:setCaption(table.concat(lines, "\n"))
end

local function openEditWindow(mvObj)
  -- mvObj = MemoryValue object

  local font = nil
  
  -- Create an edit window
  local window = createForm(true)
  window:setSize(400, 50)
  window:centerScreen()
  window:setCaption(mvObj:getEditWindowTitle())
  font = window:getFont()
  font:setName("Calibri")
  font:setSize(10)
  
  -- Add a text box with the current value
  local textField = createEdit(window)
  textField:setPosition(70, 10)
  textField:setSize(200, 20)
  textField.Text = mvObj:getEditFieldText()
  
  -- Put an OK button in the window, which would change the value
  -- to the text field contents, and close the window
  local okButton = createButton(window)
  okButton:setPosition(300, 10)
  okButton:setCaption("OK")
  okButton:setSize(30, 25)
  local confirmValueAndCloseWindow = function(mvObj, window, textField)
    local newValue = mvObj:strToValue(textField.Text)
    if newValue == nil then return end
    mvObj:set(newValue)
    
    -- Delay for a bit first, because it seems that the
    -- write to the memory address needs a bit of time to take effect.
    -- TODO: Use Timer instead of sleep?
    sleep(50)
    -- Update the display.
    updateValueDisplay()
    -- Close the edit window.
    window:close()
  end
  
  local okAction = utils.curry(confirmValueAndCloseWindow, mvObj, window, textField)
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
  if mvObj.getResetValue then
    local resetButton = createButton(window)
    resetButton:setPosition(5, 10)
    resetButton:setCaption("Reset")
    resetButton:setSize(50, 25)
    local resetValue = function(textField)
      textField.Text = mvObj:toStrForEditField(mvObj:getResetValue())
    end
    resetButton:setOnClick(utils.curry(resetValue, textField))
  end
  
  -- Put the initial focus on the text field.
  textField:setFocus()
end

local function addAddressToList(mvObj, args)
  -- mvObj = MemoryValue object
  -- args = table of custom arguments for the address list entry, otherwise
  -- it's assumed that certain fields of the mvObj should be used
  
  local addressList = getAddressList()
  local memoryRecord = addressList:createMemoryRecord()
  
  local address = mvObj:getAddress()
  if args.address then address = args.address end
  
  local description = mvObj:getLabel()
  if args.description then description = args.description end
  
  local displayType = mvObj.addressListType
  
  -- setAddress doesn't work for some reason, despite being in the Help docs?
  memoryRecord.Address = utils.intToHexStr(address)
  memoryRecord:setDescription(description)
  memoryRecord.Type = displayType
  
  if displayType == vtCustom then
  
    local customTypeName = mvObj.addressListCustomTypeName
    memoryRecord.CustomTypeName = customTypeName
    
  elseif displayType == vtBinary then
  
    -- TODO: Can't figure out how to set the start bit and size.
    -- And this entry is useless if it's a 0-sized Binary display (which is
    -- default). So, best we can do is to make this entry a Byte...
    memoryRecord.Type = vtByte
    
    local binaryStartBit = mvObj.binaryStartBit
    if args.binaryStartBit then binaryStartBit = args.binaryStartBit end
    
    local binarySize = mvObj.binarySize
    if args.binarySize then binarySize = args.binarySize end
    
    -- This didn't work.
    --memoryRecord.Binary.Startbit = binaryStartBit
    --memoryRecord.Binary.Size = binarySize
    
  end
end

local function rebuildValuesDisplay(window)
  valuesToDisplay = {}
  
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
      -- Box is checked; include this value in the display.
      
      -- Include the value itself
      local value = trackedValues[boxN]
      table.insert(valuesToDisplay, value)
      
      -- Include an edit button
      local editButton = createButton(window)
      local posY = 28*(#valuesToDisplay - 1) + 5
      editButton:setPosition(250, posY)
      editButton:setCaption("Edit")
      editButton:setSize(40, 20)
      local font = editButton:getFont()
      font:setSize(10)
      
      editButton:setOnClick(utils.curry(openEditWindow, value))
      table.insert(editButtons, editButton)
  
      -- Include an add-to-address-list button
      local listButton = createButton(window)
      local posY = 28*(#valuesToDisplay - 1) + 5
      listButton:setPosition(300, posY)
      listButton:setCaption("List")
      listButton:setSize(40, 20)
      local font = listButton:getFont()
      font:setSize(10)
      
      listButton:setOnClick(utils.curry(value.addAddressesToList, value))
      table.insert(addToListButtons, listButton)
    end
  end
end

local function addCheckboxes(window, initiallyActive)
  -- Make a list of checkboxes, one for each possible memory value to look at.
    
  -- For the purposes of seeing which values are initially active, we just
  -- identify values by their addresses. This assumes we don't depend on
  -- having copies of the same value objects.
  --
  -- Note: making "sets" in Lua is kind of roundabout.
  -- http://www.lua.org/pil/11.5.html
  local isInitiallyActive = {}
  for _, mvObj in pairs(initiallyActive) do
    isInitiallyActive[mvObj] = true
  end
  
  -- Getting the label for a checkbox may require some addresses to be
  -- computed first.
  updateAddresses()
  
  for mvObjN, mvObj in pairs(trackedValues) do
    local checkBox = createCheckBox(window)
    local posY = 20*(mvObjN-1) + 5
    checkBox:setPosition(350, posY)
    checkBox:setCaption(mvObj:getLabel())
    
    local font = checkBox:getFont()
    font:setSize(9)
    
    -- When a checkbox is checked, the corresponding memory value is displayed.
    checkBox:setOnChange(utils.curry(rebuildValuesDisplay, window))
    
    if isInitiallyActive[mvObj] then
      checkBox:setState(cbChecked)
    end
    
    table.insert(checkBoxes, checkBox)
  end
  
  -- Ensure that the initially checked values actually get initially checked.
  rebuildValuesDisplay(window)
end



-- Generic classes and their supporting functions.



local function V(label, offset, classes, extraArgs)
  -- Note that these parameters are optional, any unspecified ones
  -- will just become nil.
  local newObj = {label = label, offset = offset}
  
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
local function copyFields(child, parents)
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



local MemoryValue = {}

function MemoryValue:get()
  return self:read(self:getAddress())
end
function MemoryValue:set(v)
  self:write(self:getAddress(), v)
end

function MemoryValue:isValid()
  -- Is there currently a valid value in memory here? Would it be okay to
  -- take this value and use it for computations, assume it will change
  -- something if edited, etc.?
  return true
end

function MemoryValue:getLabel()
  return self.label
end
function MemoryValue:getDisplay(label, value)
  -- Passing a custom label, or even value, allows you to customize a display
  -- using this memory value's display method.
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  return label .. ": " .. self:toStrForDisplay(value)
end

function MemoryValue:getEditFieldText()
  return self:toStrForEditField(self:get())
end
function MemoryValue:getEditWindowTitle()
  return string.format("Edit: %s", self:getLabel())
end

function MemoryValue:addAddressesToList()
  addAddressToList(self, {})
end



local FloatValue = {}
function FloatValue:read(address)
  return utils.readFloatBE(address, self.numOfBytes)
end
function FloatValue:write(address, v)
  return utils.writeFloatBE(address, v, self.numOfBytes)
end
function FloatValue:strToValue(s) return tonumber(s) end
function FloatValue:toStrForDisplay(v, precision, trimTrailingZeros)
  if precision == nil then precision = 4 end
  if trimTrailingZeros == nil then trimTrailingZeros = false end
  
  return utils.floatToStr(v, precision, trimTrailingZeros)
end
function FloatValue:toStrForEditField(v, precision, trimTrailingZeros)
  -- Here we have less concern of looking good, and more concern of
  -- giving more info.
  if precision == nil then precision = 10 end
  if trimTrailingZeros == nil then trimTrailingZeros = false end
  
  return utils.floatToStr(v, precision, trimTrailingZeros)
end
FloatValue.numOfBytes = 4
-- For the memory record type constants, look up defines.lua in
-- your Cheat Engine folder.
FloatValue.addressListType = vtCustom
FloatValue.addressListCustomTypeName = "Float Big Endian"

local IntValue = {}
function IntValue:read(address)
  return utils.readIntBE(address, self.numOfBytes)
end
function IntValue:write(address, v)
  return utils.writeIntBE(address, v, self.numOfBytes)
end
function IntValue:strToValue(s) return tonumber(s) end
function IntValue:toStrForDisplay(v) return tostring(v) end
IntValue.toStrForEditField = IntValue.toStrForDisplay 
IntValue.numOfBytes = 4
IntValue.addressListType = vtCustom
IntValue.addressListCustomTypeName = "4 Byte Big Endian"

local ByteValue = {}
ByteValue.read = IntValue.read
ByteValue.write = IntValue.write
ByteValue.strToValue = IntValue.strToValue
ByteValue.toStrForDisplay = IntValue.toStrForDisplay
ByteValue.toStrForEditField = IntValue.toStrForEditField
ByteValue.numOfBytes = 1
ByteValue.addressListType = vtByte

local StringValue = {}
StringValue.extraArgs = {"maxLength"}
function StringValue:read(address)
  return readString(address, self.maxLength)
end
function StringValue:write(address, text)
  writeString(address, text)
end
function StringValue:strToValue(s) return s end
function StringValue:toStrForDisplay(v) return v end
StringValue.toStrForEditField = StringValue.toStrForDisplay 
StringValue.addressListType = vtString
-- TODO: Figure out the remaining details of adding a String to the
-- address list. I think there's a couple of special fields for vtString?
-- Check Cheat Engine's help.



local BinaryValue = {}
BinaryValue.extraArgs = {"binarySize", "binaryStartBit"}
BinaryValue.addressListType = vtBinary

function BinaryValue:read(address, startBit)
  -- address is the byte address
  -- Possible startBit values from left to right: 76543210
  -- Returns: a table of the bits
  -- For now, we only support binary values contained in a single byte.
  local byte = utils.readIntBE(address, 1)
  local endBit = startBit - self.binarySize + 1
  local bits = {}
  for bitNumber = startBit, endBit, -1 do
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
  return self:read(self:getAddress(), self.binaryStartBit)
end

function BinaryValue:write(address, startBit, v)
  -- v is a table of the bits
  -- For now, we only support binary values contained in a single byte.
  
  -- Start with the current byte value. Then write the bits that need to
  -- be written.
  local byte = utils.readIntBE(address, 1)
  local endBit = startBit - self.binarySize + 1
  local bitCount = 0
  for bitNumber = startBit, endBit, -1 do
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
  self:write(self:getAddress(), self.binaryStartBit, v)
end

function BinaryValue:strToValue(s)
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

function BinaryValue:toStrForDisplay(v)
  -- v is a table of bits
  local s = ""
  for _, bit in pairs(v) do
    s = s .. tostring(bit)
  end
  return s
end
BinaryValue.toStrForEditField = BinaryValue.toStrForDisplay



-- GX specific classes and their supporting functions.



local RefValue = {}

copyFields(RefValue, {MemoryValue})

function RefValue:getAddress()
  return addrs.refPointer + self.offset
end



local StateValue = {machineIndex = 0}

copyFields(StateValue, {MemoryValue})

function StateValue:getAddress()
  return addrs.machineStateBlocks + self.offset + (0x620 * self.machineIndex)
end

function StateValue:isValid()
  return machineIndexIsValid(self.machineIndex)
end

function StateValue:getLabel()
  if self.machineIndex == 0 then
    return self.label
  else
    if machineIndexIsValid(self.machineIndex) then
      return self.label..", "..forMachineI(machineName, self.machineIndex):get()
    else
      return self.label..", ".."rival "..self.machineIndex
    end
  end
end

function StateValue:getDisplay(label, value)
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  if not machineIndexIsValid(self.machineIndex) then
    return string.format("Rival machine %d is N/A", self.machineIndex)
  end
  
  return label .. ": " .. self:toStrForDisplay(value)
end

function machineIndexIsValid(machineIndex)
  return machineIndex < numOfRaceEntrants:get()
end



local StatWithBase = {}

StatWithBase.extraArgs = {"baseOffset"}
copyFields(StatWithBase, {StateValue})

function StatWithBase:getBaseAddress()
  local thisMachineId = forMachineI(machineId, self.machineIndex)
  return (addrs.machineBaseStatsBlocks
    + (0xB4 * thisMachineId:get()) + self.baseOffset)
end
function StatWithBase:getBase()
  return self:read(self:getBaseAddress())
end

function StatWithBase:getBase2Address()
  local thisMachineId = forMachineI(machineId, self.machineIndex)
  return (addrs.machineBaseStatsBlocks2
    + (0xB4 * thisMachineId:get()) + self.baseOffset)
end
function StatWithBase:getBase2()
  return self:read(self:getBase2Address())
end

function StatWithBase:getResetValue()
  return self:getBase2()
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

function StatWithBase:getDisplay(label, value)
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  if not machineIndexIsValid(self.machineIndex) then
    return string.format("Rival machine %d is N/A", self.machineIndex)
  end
  
  local s = self:toStrForDisplay(value)
  if self:hasChanged() then
    s = s.."*"
  end
  
  return label .. ": " .. s
end



local StatTiedToBase = {}

StatTiedToBase.extraArgs = {}
copyFields(StatTiedToBase, {StatWithBase})

function StatTiedToBase:set(v)
  self:write(self:getBaseAddress(), v)
end

function StatTiedToBase:getEditFieldText()
  return self:toStrForEditField(self:getBase())
end
function StatTiedToBase:getEditWindowTitle()
  return string.format("Edit: %s (base value)", self:getLabel())
end

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

function StatTiedToBase:addAddressesToList()
  -- We'll add two entries: actual stat and base stat.
  -- The base stat is more convenient to edit, because the actual stat usually
  -- needs disabling an instruction (which writes to the address every frame)
  -- before it can be edited.
  -- On the other hand, editing the actual stat avoids having to
  -- consider the base -> actual conversion math.
  
  -- Actual stat
  addAddressToList(self, {})
  
  -- Base stat
  addAddressToList(self, {
    address = self:getBaseAddress(),
    description = self:getLabel() .. " (base)",
  })
end



local SizeStat = {}

SizeStat.extraArgs = {"specificLabels", "formulas"}
copyFields(SizeStat, {StatWithBase})

function SizeStat:getAddress(key)
  if key == nil then key = 1 end
  return (addrs.machineStateBlocks
    + (0x620 * self.machineIndex) + self.offset[key])
end
function SizeStat:get(key)
  return self:read(self:getAddress(key))
end
  
function SizeStat:getBaseAddress(key)
  if key == nil then key = 1 end
  local thisMachineId = forMachineI(machineId, self.machineIndex)
  return (addrs.machineBaseStatsBlocks
    + (0xB4 * thisMachineId:get()) + self.baseOffset[key])
end
function SizeStat:getBase(key)
  return self:read(self:getBaseAddress(key))
end
  
function SizeStat:getBase2Address(key)
  if key == nil then key = 1 end
  local thisMachineId = forMachineI(machineId, self.machineIndex)
  return (addrs.machineBaseStatsBlocks2
    + (0xB4 * thisMachineId:get()) + self.baseOffset[key])
end
function SizeStat:getBase2(key)
  return self:read(self:getBase2Address(key))
end

function SizeStat:set(v)
  -- Change actual values directly; changing base doesn't change actual here
  for key, func in pairs(self.formulas) do
    self:write(self:getAddress(key), func(v))
  end
end

function SizeStat:addAddressesToList()
  -- Only add the actual stats here. Changing the base size values
  -- doesn't change the actual values, so no particular use in adding
  -- base values to the list.
  for key, specificLabel in pairs(self.specificLabels) do
    addAddressToList(self, {
      address = self:getAddress(key),
      description = specificLabel,
    })
  end
end



local FloatStat = {}

copyFields(FloatStat, {FloatValue})

-- For machine stats that are floats, we'll prefer trimming zeros in the
-- display so that the number looks cleaner. (Normally we keep trailing
-- zeros when the value can change rapidly, as it is jarring when the
-- display constantly gains/loses digits... but machine stats don't
-- change rapidly.)
function FloatStat:toStrForDisplay(v, precision, trimTrailingZeros)
  if precision == nil then precision = 4 end
  if trimTrailingZeros == nil then trimTrailingZeros = true end
  
  return utils.floatToStr(v, precision, trimTrailingZeros)
end



local BinaryValueTiedToBase = {}

-- It's ugly design that this class exists, as it is mostly redundant
-- with BinaryValue and StatTiedToBase. Reasons for the messiness include:
-- 1. BinaryValue having to define get(), set(), and addAddressesToList()
--    which are normally not datatype specific
-- 2. The need for involving a binary start bit into many of these kinds of
--    functions; and there is a different binary start bit for the actual
--    and base for the two binary machine stats

BinaryValueTiedToBase.extraArgs = {"baseBinaryStartBit"}
copyFields(BinaryValueTiedToBase, {StatTiedToBase, BinaryValue})
  
function BinaryValueTiedToBase:getBase()
  return self:read(self:getBaseAddress(), self.baseBinaryStartBit)
end
  
function BinaryValueTiedToBase:getBase2()
  return self:read(self:getBase2Address(), self.baseBinaryStartBit)
end

function BinaryValueTiedToBase:set(v)
  self:write(self:getBaseAddress(), self.baseBinaryStartBit, v)
end

function BinaryValueTiedToBase:hasChanged()
  local base = self:getBase()
  local base2 = self:getBase2()
  for index = 1, #base do
    if base[index] ~= base2[index] then return true end
  end
  return false
end
  
function BinaryValueTiedToBase:addAddressesToList()
  -- Actual stat
  addAddressToList(self, {})
  
  -- Base stat
  addAddressToList(self, {
    address = self:getBaseAddress(),
    description = self:getLabel() .. " (base)",
    binaryStartBit = self.baseBinaryStartBit,
  })
end



forMachineI = function(stateValueObj, machineIndex)
  -- Create a new object which is the same as the first param, except
  -- it has the specified machineIndex
  local newObj = {machineIndex = machineIndex}
  setmetatable(newObj, stateValueObj)
  stateValueObj.__index = stateValueObj

  return newObj
end



-- Number of machines competing in the race when it began
numOfRaceEntrants = V("# Race entrants", 0x1BAEE0, {RefValue, ByteValue})

-- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
local settingsSlider = V("Settings slider", 0x2453A0, {RefValue, IntValue})
function settingsSlider:getDisplay(label, value)
  if label == nil then label = self:getLabel() end
  if value == nil then value = self:get() end
  
  return label .. ": " .. self:toStrForDisplay(value) .. "%"
end



local function NewStateFloat(label, stateBlockOffset)
  return V(label, stateBlockOffset, {StateValue, FloatValue})
end

machineId = V("Machine ID", 0x6, {StateValue, IntValue})
machineId.numOfBytes = 2
machineId.addressListType = vtCustom
machineId.addressListCustomTypeName = "2 Byte Big Endian"

machineName = V("Machine name", 0x3C, {StateValue, StringValue}, {maxLength=64})

local posX = NewStateFloat("Pos X", 0x7C)
local posY = NewStateFloat("Pos Y", 0x80)
local posZ = NewStateFloat("Pos Z", 0x84)
local velX = NewStateFloat("Vel X", 0x94)
local velY = NewStateFloat("Vel Y", 0x98)
local velZ = NewStateFloat("Vel Z", 0x9C)
local kmh = NewStateFloat("km/h (next)", 0x17C)
local energy = NewStateFloat("Energy", 0x184)



local function NewMachineStatFloat(label, offset, baseOffset)
  return V(
    label, offset, {StatTiedToBase, FloatStat}, {baseOffset=baseOffset}
  )
end

local accel = NewMachineStatFloat("Accel", 0x220, 0x8)
local body = NewMachineStatFloat("Body", 0x30, 0x44)
local boostInterval = NewMachineStatFloat("Boost interval", 0x234, 0x38)
local boostStrength = NewMachineStatFloat("Boost strength", 0x230, 0x34)
local cameraReorienting = NewMachineStatFloat("Cam. reorienting", 0x34, 0x4C)
local cameraRepositioning = NewMachineStatFloat("Cam. repositioning", 0x38, 0x50)
local drag = NewMachineStatFloat("Drag", 0x23C, 0x40)
local driftAccel = NewMachineStatFloat("Drift accel", 0x2C, 0x1C) 
local grip1 = NewMachineStatFloat("Grip 1", 0xC, 0x10)
local grip2 = NewMachineStatFloat("Grip 2", 0x24, 0x30)
local grip3 = NewMachineStatFloat("Grip 3", 0x28, 0x14)
local maxSpeed = NewMachineStatFloat("Max speed", 0x22C, 0xC)
local obstacleCollision = V(
  "Obstacle collision", 0x584, {StateValue, FloatStat}, nil
)
local strafe = NewMachineStatFloat("Strafe", 0x1C, 0x28)
local strafeTurn = NewMachineStatFloat("Strafe turn", 0x18, 0x24)
local trackCollision = V(
  "Track collision", 0x588, {StatWithBase, FloatStat}, {baseOffset=0x9C}
)
local turnDecel = NewMachineStatFloat("Turn decel", 0x238, 0x3C)
local turning1 = NewMachineStatFloat("Turning 1", 0x10, 0x18)
local turning2 = NewMachineStatFloat("Turning 2", 0x14, 0x20)
local turning3 = NewMachineStatFloat("Turning 3", 0x20, 0x2C)
local weight = NewMachineStatFloat("Weight", 0x8, 0x4)
local unknown48 = V(
  "Unknown 48", 0x477, {StatTiedToBase, ByteValue}, {baseOffset=0x48}
)

-- Actual is state bit 1; base is 0x49 / 2
local unknown49a = V(
  "Unknown 49a", 0x0, {BinaryValueTiedToBase},
  {baseOffset=0x49, binarySize=1, binaryStartBit=7, baseBinaryStartBit=1}
)
-- Actual is state bit 24; base is 0x49 % 2
local unknown49b = V(
  "Unknown 49b", 0x2, {BinaryValueTiedToBase},
  {baseOffset=0x49, binarySize=1, binaryStartBit=0, baseBinaryStartBit=0}
)

local frontWidth = V(
  "Size, front width",
  {0x24C, 0x2A8, 0x3B4, 0x3E4},
  {SizeStat, FloatStat},
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
local frontLength = V(
  "Size, front length",
  {0x254, 0x2B0, 0x3BC, 0x3EC},
  {SizeStat, FloatStat},
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
local backWidth = V(
  "Size, back width",
  {0x304, 0x360, 0x414, 0x444},
  {SizeStat, FloatStat},
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
        if machineId:get() == 29 then return v+0.3 else return v+0.2 end
      end,
      function(v)
        if machineId:get() == 29 then return -(v+0.3) else return -(v+0.2) end
      end,
    },
  }
)
local backLength = V(
  "Size, back length",
  {0x30C, 0x368, 0x41C, 0x44C},
  {SizeStat, FloatStat},
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



machineStats = {
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

local vars = {}

local layout1 = {
  
  init = function(window)
    -- Set the display window's size.
    window:setSize(300, 200)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    mainLabel = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 160, "<debug>")
    
    vars.statRecorder = StatRecorder:new(window, 90)
    
    vars.kmh = nil
  end,
  
  update = function()
    updateAddresses()
    mainLabel:setCaption(
      table.concat(
        {
          settingsSlider:getDisplay(),
          kmh:getDisplay("km/h", vars.kmh, 3, false)
        },
        "\n"
      )
    )
    
    if vars.statRecorder.currentlyTakingStats then
      local s = kmh:toStrForEditField(vars.kmh)
      vars.statRecorder:takeStat(s)
    end
    
    -- The kmh address has the km/h that will be displayed onscreen on the
    -- NEXT frame, so we order the code accordingly to display the CURRENT
    -- frame's km/h.
    vars.kmh = kmh:get()
  end,
}

local layout2A = {
  
  init = function(window)
    window:setSize(400, 300)
  
    mainLabel = initLabel(window, 10, 5, "")
    --shared.debugLabel = initLabel(window, 10, 220, "")
    
    vars.energies = {}
    vars.energies[0] = energy
    for i = 1, 5 do
      vars.energies[i] = forMachineI(energy, i)
    end
  end,
  
  update = function()
    updateAddresses()
    mainLabel:setCaption(
      table.concat(
        {
          vars.energies[0]:getDisplay(),
          vars.energies[1]:getDisplay(),
          vars.energies[2]:getDisplay(),
          vars.energies[3]:getDisplay(),
          vars.energies[4]:getDisplay(),
          vars.energies[5]:getDisplay(),
          numOfRaceEntrants:getDisplay(),
        },
        "\n"
      )
    )
  end,
}

local layout2B = {
  
  init = function(window)
    window:setSize(550, 300)
  
    mainLabel = initLabel(window, 10, 5, "")
    local font = mainLabel:getFont()
    font:setSize(14)
    
    --shared.debugLabel = initLabel(window, 10, 220, "")
    
    trackedValues = {energy}
    for i = 1, 5 do
      table.insert(trackedValues, forMachineI(energy, i))
    end

    local initiallyActive = {}
    for k, v in pairs(trackedValues) do initiallyActive[k] = v end
    addCheckboxes(window, initiallyActive)
  end,
  
  update = function()
    updateValueDisplay()
  end,
}

local layout3 = {
  
  init = function(window)
    window:setSize(300, 130)
  
    mainLabel = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    updateAddresses()
    mainLabel:setCaption(
      table.concat(
        {
          turning2:getDisplay(turning2:getLabel().." (B)", turning2:getBase()),
          turning2:getDisplay(),
        },
        "\n"
      )
    )
  end,
}



local layout4A = {
  
  init = function(window)
    window:setSize(550, 570)
  
    mainLabel = initLabel(window, 10, 5, "")
    local font = mainLabel:getFont()
    font:setSize(14)
    
    --shared.debugLabel = initLabel(window, 10, 350, "")

    trackedValues = machineStats
    local initiallyActive = {accel, maxSpeed, weight}
    addCheckboxes(window, initiallyActive)
  end,
  
  update = function()
    updateValueDisplay()
  end,
}



local layout4B = {
  
  -- Version of layout 4 that updates the display with an update button,
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

    trackedValues = machineStats
    local initiallyActive = {accel, maxSpeed, weight}
    addCheckboxes(window, initiallyActive)
    
    updateButton = createButton(window)
    updateButton:setPosition(10, 460)
    updateButton:setCaption("Update")
    local font = updateButton:getFont()
    font:setSize(12)
    
    -- Update the display via a button this time,
    -- instead of via a function that auto-runs on every frame.
    updateButton:setOnClick(updateValueDisplay)
    updateValueDisplay()
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layout4B



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

