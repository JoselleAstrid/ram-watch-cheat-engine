-- Non-game-specific value classes,
-- and their supporting functions.

package.loaded.utils = nil
local utils = require "utils"
local subclass = utils.subclass
package.loaded.utils_math = nil
local utils_math = require "utils_math"
local Vector3 = utils_math.Vector3

local valuetypes = {}



Value = {}
valuetypes.Value = Value
Value.label = "Label not specified"
Value.initialValue = nil

function Value:init()
  self.value = self.initialValue
  self.lastUpdateFrame = self.game:getFrameCount()
end

function Value:updateValue()
  -- Subclasses should implement this function to update self.value.
  error("Function not implemented")
end

function Value:update()
  -- Generally this shouldn't be overridden.
  local currentFrame = self.game:getFrameCount()
  if self.lastUpdateFrame == currentFrame then return end
  self.lastUpdateFrame = currentFrame
  
  self:updateValue()
end

function Value:get()
  self:update()
  return self.value
end

function Value:displayValue(options)
  -- Subclasses with non-float values should override this.
  -- This is separate from display() for
  -- (1) Ease of overriding this function, and
  -- (2) Providing a more bare-bones display function, which allows callers
  -- some flexibility on how to display values.
  return utils.floatToStr(self.value, options)
end

function Value:display(passedOptions)
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
  
  local label = options.label or self.label
  
  self:update()
  if options.narrow then
    return label..":\n "..self:displayValue(options)
  else
    return label..": "..self:displayValue(options)
  end
end


-- TODO: Move to layouts?
function valuetypes.openEditWindow(mvObj, updateDisplayFunction)
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


-- TODO: Move to layouts?
function valuetypes.addAddressToList(mvObj, args)
  -- mvObj = MemoryValue object
  -- args = table of custom arguments for the address list entry, otherwise
  -- it's assumed that certain fields of the mvObj should be used
  
  local addressList = getAddressList()
  local memoryRecord = addressList:createMemoryRecord()
  
  local address = mvObj:getAddress()
  if args.address then address = args.address end
  
  local description = mvObj.label
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



local MemoryValue = subclass(Value)
valuetypes.MemoryValue = MemoryValue

function MemoryValue:init(label, offset)
  Value.init(self)

  -- These parameters are optional; will be nil if unspecified.
  self.label = label
  self.offset = offset
end

function MemoryValue:getAddress()
  error("Must be implemented by subclass")
end

function MemoryValue:updateValue()
  self.value = self:read(self:getAddress())
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

function MemoryValue:getEditFieldText()
  return self:toStrForEditField(self:get())
end
function MemoryValue:getEditWindowTitle()
  return string.format("Edit: %s", self.label)
end

function MemoryValue:addAddressesToList()
  -- TODO: Where is this function from now?
  addAddressToList(self, {})
end



-- Not considered a descendant of MemoryValue, but can be used
-- as a mixin class when initializing a MemoryValue.
local TypeMixin = {}
function TypeMixin:init() end
function TypeMixin:read(address)
  error("Must be implemented by subclass")
end
function TypeMixin:write(address, v)
  error("Must be implemented by subclass")
end
function TypeMixin:strToValue(s)
  error("Must be implemented by subclass")
end
function TypeMixin:displayValue(v, options)
  error("Must be implemented by subclass")
end
function TypeMixin:toStrForEditField(v, options)
  error("Must be implemented by subclass")
end

local FloatValue = subclass(TypeMixin)
valuetypes.FloatValue = FloatValue
function FloatValue:read(address)
  return utils.readFloatBE(address, self.numOfBytes)
end
function FloatValue:write(address, v)
  return utils.writeFloatBE(address, v, self.numOfBytes)
end
function FloatValue:strToValue(s) return tonumber(s) end
function FloatValue:displayValue(options)
  return utils.floatToStr(self.value, options)
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

local IntValue = subclass(TypeMixin)
valuetypes.IntValue = IntValue
function IntValue:read(address)
  return utils.readIntBE(address, self.numOfBytes)
end
function IntValue:write(address, v)
  return utils.writeIntBE(address, v, self.numOfBytes)
end
function IntValue:strToValue(s) return tonumber(s) end
function IntValue:displayValue() return tostring(self.value) end
IntValue.toStrForEditField = IntValue.displayValue 
IntValue.numOfBytes = 4
IntValue.addressListType = vtCustom
IntValue.addressListCustomTypeName = "4 Byte Big Endian"

local ShortValue = subclass(IntValue)
valuetypes.ShortValue = ShortValue
ShortValue.numOfBytes = 2
ShortValue.addressListType = vtCustom
ShortValue.addressListCustomTypeName = "2 Byte Big Endian"

local ByteValue = subclass(IntValue)
valuetypes.ByteValue = ByteValue
ByteValue.numOfBytes = 1
ByteValue.addressListType = vtByte

local SignedIntValue = subclass(TypeMixin)
valuetypes.SignedIntValue = SignedIntValue
function SignedIntValue:read(address)
  local v = utils.readIntBE(address, self.numOfBytes)
  return utils.unsignedToSigned(v, self.numOfBytes)
end
function SignedIntValue:write(address, v)
  local v2 = utils.signedToUnsigned(v, self.numOfBytes)
  return utils.writeIntBE(address, v2, self.numOfBytes)
end


local StringValue = subclass(TypeMixin)
valuetypes.StringValue = StringValue
function StringValue:init(extraArgs)
  TypeMixin.init(self)
  self.maxLength = extraArgs.maxLength
    or error("Must specify a max string length")
end
function StringValue:read(address)
  return readString(address, self.maxLength)
end
function StringValue:write(address, text)
  writeString(address, text)
end
function StringValue:strToValue(s) return s end
function StringValue:displayValue() return self.value end
StringValue.toStrForEditField = StringValue.displayValue 
StringValue.addressListType = vtString
-- TODO: Figure out the remaining details of adding a String to the
-- address list. I think there's a couple of special fields for vtString?
-- Check Cheat Engine's help.



local BinaryValue = subclass(TypeMixin)
valuetypes.BinaryValue = BinaryValue
BinaryValue.addressListType = vtBinary

function BinaryValue:init(extraArgs)
  TypeMixin.init(self)
  if not extraArgs.binarySize then error(self.label) end
  self.binarySize = extraArgs.binarySize
    or error("Must specify size of the binary value (number of bits)")
  self.binaryStartBit = extraArgs.binaryStartBit
    or error("Must specify binary start bit (which bit within the byte)")
end
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

function BinaryValue:updateValue()
  self.value = self:read(self:getAddress(), self.binaryStartBit)
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

function BinaryValue:displayValue()
  -- self.value is a table of bits
  local s = ""
  for _, bit in pairs(self.value) do
    s = s .. tostring(bit)
  end
  return s
end
BinaryValue.toStrForEditField = BinaryValue.displayValue



local Vector3Value = subclass(Value)
valuetypes.Vector3Value = Vector3Value
Vector3Value.initialValue = "Value field not used"

function Vector3Value:init(x, y, z)
  Value.init(self)
  self.x = x
  self.y = y
  self.z = z
end

function Vector3Value:get()
  self:update()
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

function Vector3Value:update()
  self.x:update()
  self.y:update()
  self.z:update()
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
  
  local label = options.label or self.label

  local format = nil
  if options.narrow then
    format = "%s:\n X %s\n Y %s\n Z %s"
  else
    format = "%s: X %s | Y %s | Z %s"
  end
  
  self:update()
  return string.format(
    format,
    label,
    self.x:displayValue(options),
    self.y:displayValue(options),
    self.z:displayValue(options)
  )
end



return valuetypes

