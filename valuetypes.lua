-- Non-game-specific value classes,
-- and their supporting functions.

package.loaded.utils = nil
local utils = require "utils"
local subclass = utils.subclass
package.loaded.utils_math = nil
local utils_math = require "utils_math"
local Vector3 = utils_math.Vector3

local valuetypes = {}



function valuetypes.V(valueClass, ...)
  local newValue = subclass(valueClass)

  newValue.init = utils.curryInstance(valueClass.init, ...)

  return newValue
end

function valuetypes.MV(label, offset, valueClass, typeMixinClass, extraArgs)
  local newValue = subclass(valueClass, typeMixinClass)

  local function f(
      newV_, label_, offset_, valueClass_, typeMixinClass_, extraArgs_)
    valueClass_.init(newV_, label_, offset_, extraArgs_)
    typeMixinClass_.init(newV_, extraArgs_)
  end

  newValue.init = utils.curryInstance(
    f, label, offset, valueClass, typeMixinClass, extraArgs)

  return newValue
end

function valuetypes.initValueAsNeeded(value)
  if value.initCalled then return end

  value:init()
  value.initCalled = true
end



local Block = {}
Block.blockValues = {}
Block.blockAlias = 'block'
Block.blockInstances = {}
valuetypes.Block = Block

function Block:init()
  -- self.a = new object of class self.blockValues.a,
  -- whose init() must take 0 args.
  for key, valueTemplate in pairs(self.blockValues) do
    -- Assign to the block namespace.
    self[key] = subclass(valueTemplate)
    -- Allow the new object to know about this block object (and ancestors).
    self:addParentReferences(self[key])
  end

  -- THEN init everything. Some objects' init functions may require
  -- other objects to already be assigned to the block namespace.
  --
  -- Note that the order of objects in this for loop is undefined. However,
  -- an object A's init() might call another object B's init() if A depends
  -- on B. So this for loop must only call an object's init
  -- if it wasn't already called.
  for key, _ in pairs(self.blockValues) do
    valuetypes.initValueAsNeeded(self[key])
  end
end

function Block:addParentReferences(value)
  -- Let the value know what its 'owner' block/game is.
  value.block = self
  if self.game then value.game = self.game end
  if self.blockAlias then value[self.blockAlias] = self end

  -- In some cases, if this block belongs to another block, etc., it's
  -- also useful to give the object info about those blocks.
  local ancestorBlock = self.block
  while ancestorBlock do
    if ancestorBlock.blockAlias then
      value[ancestorBlock.blockAlias] = ancestorBlock
    end
    ancestorBlock = ancestorBlock.block
  end
end

function Block:getBlockKey(...)
  -- Subclasses should override this.
  return error("Function not implemented")
end


-- valuetypes.V()/MV() and initialization rolled into one.
-- Use this if the block is already initialized or being initialized.

function Block:V(...)
  local newValue = valuetypes.V(...)
  self:addParentReferences(newValue)
  valuetypes.initValueAsNeeded(newValue)
  return newValue
end

function Block:MV(...)
  local newValue = valuetypes.MV(...)
  self:addParentReferences(newValue)
  valuetypes.initValueAsNeeded(newValue)
  return newValue
end



Value = {}
valuetypes.Value = Value
Value.label = "Label not specified"
Value.initialValue = nil
Value.invalidDisplay = "<Invalid value>"

function Value:init()
  self.value = self.initialValue

  if self.game.usingFrameCounter then
    self.lastUpdateFrame = self.game:getFrameCount()
  end
end

function Value:updateValue()
  -- Subclasses should implement this function to update self.value.
  error("Function not implemented")
end

function Value:update()
  -- Generally this method shouldn't be overridden.

  if self.game.usingFrameCounter then
    -- There's no point in updating again if we've already updated on this
    -- game frame.
    -- In fact, some values' accuracies depend on not updating more than once
    -- per frame, particularly rates of change.
    local currentFrame = self.game:getFrameCount()

    if self.lastUpdateFrame == currentFrame then return end
    self.lastUpdateFrame = currentFrame
  end

  self:updateValue()
end

function Value:get()
  self:update()
  return self.value
end

function Value:isValid()
  -- Is there currently a valid value here? Or is there a problem which could
  -- make the standard value-getting functions return something nonsensical
  -- (or trigger an error)?
  -- For example, if there is a memory value whose pointer becomes
  -- invalid sometimes, then it can return false in those cases.
  return true
end

function Value:displayValue(options)
  -- Subclasses with non-float values should override this.
  -- This is separate from display() for ease of overriding this function.
  return utils.floatToStr(self.value, options)
end

function Value:getLabel()
  -- If there is anything dynamic about a Value's label display,
  -- this function can be overridden to accommodate that.
  -- All display() functions should use self:getLabel() instead of self.label.
  return self.label
end

function Value:getEditWindowTitle()
  return string.format("Edit: %s", self:getLabel())
end

function Value:display(passedOptions)
  local options = {}
  -- First apply default options
  if self.displayDefaults then
    utils.updateTable(options, self.displayDefaults)
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedOptions then
    utils.updateTable(options, passedOptions)
  end

  local isValid = self:isValid()
  local valueDisplay = self.invalidDisplay
  if isValid then
    self:update()
    if options.valueDisplayFunction then
      valueDisplay = options.valueDisplayFunction(options)
    else
      valueDisplay = self:displayValue(options)
    end
  end

  if options.nolabel then
    return valueDisplay
  else
    local label = options.label or self:getLabel()
    if options.narrow then
      return label..":\n "..valueDisplay
    else
      return label..": "..valueDisplay
    end
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

function MemoryValue:getEditFieldText()
  return self:toStrForEditField(self:get())
end

function MemoryValue:getAddressListEntries()
  return {{
    Address = utils.intToHexStr(self:getAddress()),
    Description = self:getLabel(),
    Type = self.addressListType,
    CustomTypeName = self.addressListCustomTypeName,
    BinaryStartBit = self.binaryStartBit,
    BinarySize = self.binarySize,
  }}
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
function TypeMixin:equals(obj2)
  return self:get() == obj2:get()
end


-- Floating-point value, single precision, Little Endian.
local FloatTypeLE = subclass(TypeMixin)
valuetypes.FloatTypeLE = FloatTypeLE
FloatTypeLE.numOfBytes = 4
-- For the memory record type constants, look up defines.lua in
-- your Cheat Engine folder.
FloatTypeLE.addressListType = vtSingle
function FloatTypeLE:read(address)
  return utils.readFloatLE(address, self.numOfBytes)
end
function FloatTypeLE:write(address, v)
  return utils.writeFloatLE(address, v, self.numOfBytes)
end
function FloatTypeLE:strToValue(s) return tonumber(s) end
function FloatTypeLE:displayValue(options)
  return utils.floatToStr(self.value, options)
end
function FloatTypeLE:toStrForEditField(v, options)
  -- Here we have less concern of looking good, and more concern of
  -- giving more info.
  options = options or {}
  options.afterDecimal = options.afterDecimal or 10
  options.trimTrailingZeros = options.trimTrailingZeros or false
  return utils.floatToStr(v, options)
end

-- Big-Endian version.
local FloatTypeBE = subclass(FloatTypeLE)
valuetypes.FloatTypeBE = FloatTypeBE
-- Must have a custom Cheat Engine type defined called Float Big Endian.
FloatTypeBE.addressListType = vtCustom
FloatTypeBE.addressListCustomTypeName = "Float Big Endian"
function FloatTypeBE:read(address)
  return utils.readFloatBE(address, self.numOfBytes)
end
function FloatTypeBE:write(address, v)
  return utils.writeFloatBE(address, v, self.numOfBytes)
end


local IntTypeLE = subclass(TypeMixin)
valuetypes.IntTypeLE = IntTypeLE
function IntTypeLE:read(address)
  return utils.readIntLE(address, self.numOfBytes)
end
function IntTypeLE:write(address, v)
  return utils.writeIntLE(address, v, self.numOfBytes)
end
function IntTypeLE:strToValue(s) return tonumber(s) end
function IntTypeLE:displayValue() return tostring(self.value) end
function IntTypeLE:toStrForEditField(v) return tostring(v) end
IntTypeLE.numOfBytes = 4
IntTypeLE.addressListType = vtDword

local IntTypeBE = subclass(IntTypeLE)
valuetypes.IntTypeBE = IntTypeBE
function IntTypeBE:read(address)
  return utils.readIntBE(address, self.numOfBytes)
end
function IntTypeBE:write(address, v)
  return utils.writeIntBE(address, v, self.numOfBytes)
end
IntTypeBE.addressListType = vtCustom
IntTypeBE.addressListCustomTypeName = "4 Byte Big Endian"


local ShortTypeLE = subclass(IntTypeLE)
valuetypes.ShortTypeLE = ShortTypeLE
ShortTypeLE.numOfBytes = 2
ShortTypeLE.addressListType = vtWord

local ShortTypeBE = subclass(IntTypeBE)
valuetypes.ShortTypeBE = ShortTypeBE
ShortTypeBE.numOfBytes = 2
ShortTypeBE.addressListType = vtCustom
ShortTypeBE.addressListCustomTypeName = "2 Byte Big Endian"

local ByteType = subclass(IntTypeLE)
valuetypes.ByteType = ByteType
ByteType.numOfBytes = 1
ByteType.addressListType = vtByte


-- Floats are interpreted as signed by default, while integers are interpreted
-- as unsigned by default. We'll define a few classes to interpret integers
-- as signed.
local function readSigned(self, address)
  local v = utils.readIntBE(address, self.numOfBytes)
  return utils.unsignedToSigned(v, self.numOfBytes)
end
local function writeSigned(self, address, v)
  local v2 = utils.signedToUnsigned(v, self.numOfBytes)
  return utils.writeIntBE(address, v2, self.numOfBytes)
end

valuetypes.SignedIntTypeLE = subclass(IntTypeLE)
valuetypes.SignedIntTypeLE.read = readSigned
valuetypes.SignedIntTypeLE.write = writeSigned

valuetypes.SignedIntTypeBE = subclass(IntTypeBE)
valuetypes.SignedIntTypeBE.read = readSigned
valuetypes.SignedIntTypeBE.write = writeSigned

valuetypes.SignedShortTypeLE = subclass(ShortTypeLE)
valuetypes.SignedShortTypeLE.read = readSigned
valuetypes.SignedShortTypeLE.write = writeSigned

valuetypes.SignedShortTypeBE = subclass(ShortTypeBE)
valuetypes.SignedShortTypeBE.read = readSigned
valuetypes.SignedShortTypeBE.write = writeSigned

valuetypes.SignedByteType = subclass(ByteType)
valuetypes.SignedByteType.read = readSigned
valuetypes.SignedByteType.write = writeSigned


local StringType = subclass(TypeMixin)
valuetypes.StringType = StringType
function StringType:init(extraArgs)
  TypeMixin.init(self)
  self.maxLength = extraArgs.maxLength
    or error("Must specify a max string length")
end
function StringType:read(address)
  return readString(address, self.maxLength)
end
function StringType:write(address, text)
  writeString(address, text)
end
function StringType:strToValue(s) return s end
function StringType:displayValue() return self.value end
function StringType:toStrForEditField(v) return v end
StringType.addressListType = vtString
-- TODO: Figure out the remaining details of adding a String to the
-- address list. I think there's a couple of special fields for vtString?
-- Check Cheat Engine's help.


local BinaryType = subclass(TypeMixin)
valuetypes.BinaryType = BinaryType
BinaryType.addressListType = vtBinary
BinaryType.initialValue = {}

function BinaryType:init(extraArgs)
  TypeMixin.init(self)
  self.binarySize = extraArgs.binarySize
    or error("Must specify size of the binary value (number of bits)")
  -- Possible binaryStartBit values from left to right: 76543210
  self.binaryStartBit = extraArgs.binaryStartBit
    or error("Must specify binary start bit (which bit within the byte)")
end

function BinaryType:read(address)
  -- address is the byte address
  -- Returns: a table of the bits
  -- For now, we only support binary values contained in a single byte.
  local byte = utils.readIntBE(address, 1)
  local endBit = self.binaryStartBit - self.binarySize + 1
  local bits = {}
  for bitNumber = self.binaryStartBit, endBit, -1 do
    -- Check if the byte has 1 or 0 in this position.
    if 2^bitNumber == bAnd(byte, 2^bitNumber) then
      table.insert(bits, 1)
    else
      table.insert(bits, 0)
    end
  end
  return bits
end

function BinaryType:write(address, v)
  -- v is a table of the bits
  -- For now, we only support binary values contained in a single byte.

  -- Start with the current byte value. Then write the bits that need to
  -- be written.
  local byte = utils.readIntBE(address, 1)
  local endBit = self.binaryStartBit - self.binarySize + 1
  local bitCount = 0
  for bitNumber = self.binaryStartBit, endBit, -1 do
    bitCount = bitCount + 1
    if v[bitCount] == 1 then
      byte = bOr(byte, 2^bitNumber)
    else
      byte = bAnd(byte, 255 - 2^bitNumber)
    end
  end
  utils.writeIntBE(address, byte, 1)
end

function BinaryType:strToValue(s)
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

function BinaryType:toStrForEditField(v)
  -- The value is a table of bits
  local s = ""
  for _, bit in pairs(v) do
    s = s .. tostring(bit)
  end
  return s
end

function BinaryType:displayValue()
  return self:toStrForEditField(self.value)
end

function BinaryType:equals(obj2)
  -- Lua doesn't do value-based equality of tables, so we need to compare
  -- the elements one by one.
  local v1 = self:get()
  local v2 = obj2:get()
  for index = 1, #v1 do
    if v1[index] ~= v2[index] then return false end
  end
  -- Also compare table lengths; this accounts for the case where v1 is just
  -- the first part of v2.
  return #v1 == #v2
end



local Vector3Value = subclass(Value, Block)
valuetypes.Vector3Value = Vector3Value
Vector3Value.initialValue = "Value field not used"

function Vector3Value:init(x, y, z)
  self.blockValues = {x = x, y = y, z = z}
  Value.init(self)
  Block.init(self)
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
    utils.updateTable(options, self.displayDefaults)
  end
  -- Then apply passed-in options, replacing default options of the same keys
  if passedOptions then
    utils.updateTable(options, passedOptions)
  end

  local label = options.label or self:getLabel()

  local format = nil
  if options.narrow then
    format = "%s:\n X %s\n Y %s\n Z %s"
  else
    format = "%s: X %s | Y %s | Z %s"
  end

  local isValid = self:isValid()
  local x = self.invalidDisplay
  local y = self.invalidDisplay
  local z = self.invalidDisplay
  if isValid then
    self:update()
    x = self.x:displayValue(options)
    y = self.y:displayValue(options)
    z = self.z:displayValue(options)
  end

  return string.format(format, label, x, y, z)
end



local RateOfChange = subclass(Value)
valuetypes.RateOfChange = RateOfChange
RateOfChange.label = "Label to be passed as argument"
RateOfChange.initialValue = 0.0

function RateOfChange:init(baseValue, label)
  Value.init(self)

  valuetypes.initValueAsNeeded(baseValue)
  self.baseValue = baseValue
  self.label = label
  -- Display the same way as the base value
  self.displayValue = self.baseValue.displayValue
end

function RateOfChange:updateValue()
  -- Update prev and curr stat values
  self.prevStat = self.currStat
  self.baseValue:update()
  self.currStat = self.baseValue.value

  -- Update rate of change value
  if self.prevStat == nil then
    self.value = 0.0
  else
    self.value = self.currStat - self.prevStat
  end
end



local ResettableValue = subclass(Value)
valuetypes.ResettableValue = ResettableValue

function ResettableValue:init(resetButton)
  Value.init(self)

  -- If a reset button isn't passed in or specified by the game, then the
  -- default reset button is D-Pad Down, which is assumed to be represented
  -- with 'v'.
  self.resetButton = resetButton or self.game.defaultResetButton or 'v'
end

function ResettableValue:reset()
  error(
    "Reset function not implemented in value of label: "..self.baseValue.label)
end

function ResettableValue:update()
  -- Do an initial reset, if we haven't already.
  -- We don't do this in init() because the reset function may depend on
  -- looking up other Values, which may require that those Values be
  -- initialized. We COULD ensure that those Values get init'd first, but it's
  -- just as simple to move the initial update here.
  if not self.initialResetDone then
    self:reset()
    self.initialResetDone = true
  end

  Value.update(self)

  -- If the reset button is being pressed, call the reset function.
  --
  -- First check if the game has a concept of separate players or not
  -- (which we'll assume is called Player). If so, call getButton on
  -- Player 1. If not, call getButton on the game itself.
  local buttonNamespace = self.game
  if self.game.Player then
    buttonNamespace = self.game:getBlock(self.game.Player, 1)
  else
    buttonNamespace = self.game
  end

  if buttonNamespace:getButton(self.resetButton) == 1 then
    self:reset()
  end
end



local MaxValue = subclass(ResettableValue)
valuetypes.MaxValue = MaxValue
MaxValue.label = "Label to be passed as argument"
MaxValue.initialValue = 0.0

function MaxValue:init(baseValue, resetButton)
  ResettableValue.init(self, resetButton)

  valuetypes.initValueAsNeeded(baseValue)
  self.baseValue = baseValue
  self.label = "Max "..self.baseValue.label
  -- Display the same way as the base value
  self.displayValue = self.baseValue.displayValue
end

function MaxValue:updateValue()
  self.baseValue:update()

  if self.baseValue.value > self.value then
    self.value = self.baseValue.value
  end
end

function MaxValue:reset()
  -- Set max value to (essentially) negative infinity, so any valid value
  -- is guaranteed to be the new max
  self.value = -math.huge
end



local AverageValue = subclass(ResettableValue)
valuetypes.AverageValue = AverageValue
AverageValue.label = "Label to be passed as argument"
AverageValue.initialValue = 0.0

function AverageValue:init(baseValue)
  ResettableValue.init(self, resetButton)

  valuetypes.initValueAsNeeded(baseValue)
  self.baseValue = baseValue
  self.label = "Avg "..self.baseValue.label
  -- Display the same way as the base value
  self.displayValue = self.baseValue.displayValue
end

function AverageValue:updateValue()
  self.baseValue:update()
  self.sum = self.sum + self.baseValue.value
  self.numOfDataPoints = self.numOfDataPoints + 1

  self.value = self.sum / self.numOfDataPoints
end

function AverageValue:reset()
  self.sum = 0
  self.numOfDataPoints = 0
end



return valuetypes

