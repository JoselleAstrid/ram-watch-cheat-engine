-- Non-game-specific value classes,
-- and their supporting functions.

package.loaded.utils = nil
local utils = require "utils"
local subclass = utils.subclass
local copyFields = utils.copyFields
package.loaded.utils_math = nil
local utils_math = require "utils_math"
local Vector3 = utils_math.Vector3



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



local function openEditWindow(mvObj, updateDisplayFunction)
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
    updateDisplayFunction()
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
function MemoryValue:display(passedOptions)
  local options = {}
  -- First apply default options
  if self.displayDefaults then
    for key, value in pairs(self.displayDefaults) do
      options[key] = value
    end
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedOptions then
    for key, value in pairs(passedOptions) do
      options[key] = value
    end
  end
  
  -- Passing a custom label, or even value, allows you to customize a display
  -- using this memory value's display method.
  local label = options.label or self:getLabel()
  local value = options.value or self:get()
  local narrow = options.narrow or false
  
  if narrow then
    return label .. ":\n " .. self:toStrForDisplay(value, options)
  else
    return label .. ": " .. self:toStrForDisplay(value, options)
  end
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
function FloatValue:toStrForDisplay(v, options)
  return utils.floatToStr(v, options)
end
function FloatValue:toStrForEditField(v, options)
  -- Here we have less concern of looking good, and more concern of
  -- giving more info.
  options.afterDecimal = options.afterDecimal or 10
  options.trimTrailingZeros = options.trimTrailingZeros or false
  return utils.floatToStr(v, options)
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

local ShortValue = {}
copyFields(ShortValue, {IntValue})
ShortValue.numOfBytes = 2
ShortValue.addressListType = vtCustom
ShortValue.addressListCustomTypeName = "2 Byte Big Endian"

local ByteValue = {}
copyFields(ByteValue, {IntValue})
ByteValue.numOfBytes = 1
ByteValue.addressListType = vtByte

local SignedIntValue = {}
function SignedIntValue:read(address)
  local v = utils.readIntBE(address, self.numOfBytes)
  return utils.unsignedToSigned(v, self.numOfBytes)
end
function SignedIntValue:write(address, v)
  local v2 = utils.signedToUnsigned(v, self.numOfBytes)
  return utils.writeIntBE(address, v2, self.numOfBytes)
end


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



-- Vector3Value is different from the other value types so far. It's basically
-- a wrapper for 3 other Values.
-- You call the new() method to instantiate rather than calling V().

local Vector3Value = {}

function Vector3Value:new(x, y, z, label)
  local obj = subclass(Vector3Value)
  obj.x = x
  obj.y = y
  obj.z = z
  obj.label = label
  return obj
end

function Vector3Value:get()
  return Vector3:new(self.x:get(), self.y:get(), self.z:get())
end
function Vector3Value:set(vec3)
  self.x:set(vec3.x)
  self.y:set(vec3.y)
  self.z:set(vec3.z)
end

function Vector3Value:isValid()
  return (self.x:isValid() and self.y:isValid() and self.z:isValid()) 
end

function Vector3Value:getLabel()
  return self.label
end
function Vector3Value:display(passedOptions)
  local options = {}
  -- First apply default options
  if self.displayDefaults then
    for key, value in pairs(self.displayDefaults) do
      options[key] = value
    end
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedOptions then
    for key, value in pairs(passedOptions) do
      options[key] = value
    end
  end
  
  -- Passing a custom label, or even value, allows you to customize a display
  -- using this memory value's display method.
  if options == nil then arg = {} end
  local label = options.label or self:getLabel()
  local value = options.value or self:get()
  local narrow = options.narrow or false

  local format = nil
  if narrow then
    format = "%s:\n X %s\n Y %s\n Z %s"
  else
    format = "%s: X %s | Y %s | Z %s"
  end
  
  return string.format(
    format,
    label,
    self.x:toStrForDisplay(value.x, options),
    self.y:toStrForDisplay(value.y, options),
    self.z:toStrForDisplay(value.z, options)
  )
end

function Vector3Value:getEditFieldText()
  error("Value "..self:getLabel().." isn't editable")
end
function Vector3Value:getEditWindowTitle()
  error("Value "..self:getLabel().." isn't editable")
end

function Vector3Value:addAddressesToList()
  -- TODO: Implement adding X, Y, and Z addresses to the list
end



return {
  V = V,
  
  MemoryValue = MemoryValue,
  FloatValue = FloatValue,
  IntValue = IntValue,
  ShortValue = ShortValue,
  ByteValue = ByteValue,
  SignedIntValue = SignedIntValue,
  StringValue = StringValue,
  BinaryValue = BinaryValue,
  
  Vector3Value = Vector3Value,
  
  openEditWindow = openEditWindow,
  addAddressToList = addAddressToList,
}

