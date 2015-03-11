-- Super Mario Galaxy 2
-- Tested only on the US version so far.



-- Imports.

-- First make sure that the imported modules get de-cached as needed, since
-- we may be re-running the script in the same run of Cheat Engine.
package.loaded.shared = nil
package.loaded.utils = nil
package.loaded.dolphin = nil
package.loaded.valuetypes = nil
package.loaded.valuedisplay = nil

local shared = require "shared"
local utils = require "utils"
local dolphin = require "dolphin"
local vtypes = require "valuetypes"
local vdisplay = require "valuedisplay"

local readIntBE = utils.readIntBE
local readFloatBE = utils.readFloatBE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local debugDisp = utils.debugDisp
local StatRecorder = utils.StatRecorder 

local V = vtypes.V
local copyFields = vtypes.copyFields
local MemoryValue = vtypes.MemoryValue
local FloatValue = vtypes.FloatValue
local IntValue = vtypes.IntValue
local ShortValue = vtypes.ShortValue
local ByteValue = vtypes.ByteValue
local SignedIntValue = vtypes.SignedIntValue
local StringValue = vtypes.StringValue
local BinaryValue = vtypes.BinaryValue
local addAddressToList = vtypes.addAddressToList

local ValueDisplay = vdisplay.ValueDisplay

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- Functions that compute some addresses.

local gameId = "SB4E01"  -- US version
local addrs = {
  o = dolphin.getGameStartAddress(gameId),
}

local computeAddr = {
  
  posBlock = function()
    -- Pointer to the pointer to the block.
    local ptr2Addr = addrs.o + 0xC7A2C8
    local ptr2Value = readIntBE(ptr2Addr, 4)
    
    local ptr1Addr = addrs.o + ptr2Value - 0x80000000 + 0x750
    local ptr1Value = readIntBE(ptr1Addr, 4)
    
    if ptr1Value < 0x80000000 or ptr1Value > 0x90000000 then
      -- Rough check that we do not have a valid pointer. This happens when
      -- switching between Mario and Luigi. In this case, we'll give up
      -- on finding the position and read a bunch of zeros instead.
      return addrs.zeros
    end
    
    return addrs.o + ptr1Value - 0x80000000 - 0x8670
  end
}

local function updateAddresses()
  addrs.posBlock = computeAddr.posBlock()

  -- It's useful to have an address where there's always a ton of zeros.
  -- We can use this address as the result when an address computation
  -- is invalid. Zeros are better than unreadable memory (results in
  -- error) or garbage values.
  -- This group of zeros should go on for 0x20000 to 0x30000 bytes.
  addrs.zeros = addrs.o + 0x754000
end



-- SMG2 specific classes and their supporting functions.



-- Values at static addresses (from the beginning of the game memory).
local StaticValue = {}

copyFields(StaticValue, {MemoryValue})

function StaticValue:getAddress()
  return addrs.o + self.offset
end



-- Values that are a constant offset from a certain reference pointer.
local RefValue = {}

copyFields(RefValue, {MemoryValue})

function RefValue:getAddress()
  return addrs.refPointer + self.offset
end



-- Values that are a constant small offset from the position values' location.
--
-- It might not be ideal to use the position as a reference since that's
-- not necessarily at the start of a block. So we might end up using negative
-- offsets from here; it'll work, but it might be a bit confusing.
local PosBlockValue = {}

copyFields(PosBlockValue, {MemoryValue})

function PosBlockValue:getAddress()
  return addrs.posBlock + self.offset
end



local stageTimeFrames = V("Stage time, frames", 0xA75D10, {StaticValue, IntValue})

local fileTimeFrames = V("Stage time, frames", 0xE40E4C, {StaticValue, ShortValue})
function fileTimeFrames:get()
  -- This is a weird combination of big endian and little endian, it seems.
  local address = self:getAddress()
  local lowPart = self:read(address)
  local highPart = self:read(address + 2)
  return (highPart * 65536) + lowPart
end
  
local function timeDisplay(which)
  local frames = nil
  if which == "stage" then frames = stageTimeFrames:get()
  else frames = fileTimeFrames:get() end
  
  local centis = math.floor((frames % 60) * (100/60))
  local secs = math.floor(frames / 60) % 60
  
  local timeStr = nil
  local label = nil
  
  if which == "stage" then
    local mins = math.floor(frames / (60*60))
    timeStr = string.format("%d:%02d.%02d",
      mins, secs, centis
    )
    label = "Stage time"
  else
    local mins = math.floor(frames / (60*60)) % 60
    local hrs = math.floor(frames / (60*60*60))
    timeStr = string.format("%d:%02d:%02d.%02d",
      hrs, mins, secs, centis
    )
    label = "File time"
  end
    
  local display = string.format("%s: %s | %d",
    label, timeStr, frames
  )
  return display
end
local stageTimeDisplay = utils.curry(timeDisplay, "stage")
local fileTimeDisplay = utils.curry(timeDisplay, "file")



local pos = {}
pos.X = V("Pos X", 0x0, {PosBlockValue, FloatValue})
pos.Y = V("Pos Y", 0x4, {PosBlockValue, FloatValue})
pos.Z = V("Pos Z", 0x8, {PosBlockValue, FloatValue})

function pos.display(beforeDecimal, afterDecimal)
  local beforeDecimal = beforeDecimalP
  local afterDecimal = afterDecimalP
  if beforeDecimal == nil then beforeDecimal = 5 end 
  if afterDecimal == nil then afterDecimal = 1 end 
  
  local format = "%+0"..(beforeDecimal+afterDecimal+2).."."..afterDecimal.."f"
    
  return string.format(
    "XYZ Pos: %s | %s | %s",
    string.format(format, pos.X:get()),
    string.format(format, pos.Y:get()),
    string.format(format, pos.Z:get())
  )
end



-- Velocity calculated as position change.
-- TODO: Share this code with Galaxy 1 instead of duplicating it. Maybe the
-- code can even be shared with other games.

local Velocity = {}

function Velocity:new(coordinates)
  -- coordinates - examples: "X" "Y" "XZ" "XYZ" 

  -- Make an object of the "class" Velocity.
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  
  obj.lastUpdateFrame = dolphin.getFrameCount()
  obj.numCoordinates = string.len(coordinates)
  if obj.numCoordinates == 1 then obj.label = "Vel "..coordinates
  else obj.label = "Speed "..coordinates end
  
  obj.posObjects = {}
  for char in coordinates:gmatch"." do
    table.insert(obj.posObjects, pos[char])
  end
  obj.value = 0.0
  
  return obj
end
  
function Velocity:update()
  local currentFrame = dolphin.getFrameCount()
  if self.lastUpdateFrame == currentFrame then return end
  self.lastUpdateFrame = currentFrame

  -- Update prev and curr position
  self.prevPos = self.currPos
  self.currPos = {}
  for _, posObject in pairs(self.posObjects) do
    table.insert(self.currPos, posObject:get())
  end
  
  local s = ""
  for _, v in pairs(self.currPos) do s = s..tostring(v) end
  
  -- Update velocity value
  
  if self.prevPos == nil then
    self.value = 0.0
    return
  end
  
  if self.numCoordinates == 1 then
    self.value = self.currPos[1] - self.prevPos[1]
  else
    local sumOfSquaredDiffs = 0.0
    for n = 1, self.numCoordinates do
      local diff = self.currPos[n] - self.prevPos[n] 
      sumOfSquaredDiffs = sumOfSquaredDiffs + diff*diff
    end
    self.value = math.sqrt(sumOfSquaredDiffs)
  end
end

function Velocity:display(beforeDecimalP, afterDecimalP, withoutLabel)
  self:update()

  local beforeDecimal = beforeDecimalP
  local afterDecimal = afterDecimalP
  if beforeDecimal == nil then beforeDecimal = 2 end 
  if afterDecimal == nil then afterDecimal = 2 end 
  
  local valueStr = nil
  if self.numCoordinates == 1 then
    local format = "%+0"..(beforeDecimal+afterDecimal+2).."."..afterDecimal.."f"
    valueStr = string.format(format, self.value)
  else
    local format = "%0"..(beforeDecimal+afterDecimal+1).."."..afterDecimal.."f"
    valueStr = string.format(format, self.value)
  end
  
  if withoutLabel then return valueStr
  else return self.label..": "..valueStr end
end



-- Base velocity: not all kinds of movement are covered.
-- For example, launch stars and riding moving platforms aren't
-- accounted for.
-- So it is usually preferable to subtract positions (as the Velocity
-- class does) instead of using this.
local baseVelX = V("Base Vel X", -0x5B0, {PosBlockValue, FloatValue})
local baseVelY = V("Base Vel Y", -0x5AC, {PosBlockValue, FloatValue})
local baseVelZ = V("Base Vel Z", -0x5A8, {PosBlockValue, FloatValue})



local buttons1 = V("Buttons 1", 0xB38A2E, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
local buttons2 = V("Buttons 2", 0xB38A2F, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
local stickX = V("Stick X", 0xB38A8C, {StaticValue, FloatValue})
local stickY = V("Stick Y", 0xB38A90, {StaticValue, FloatValue})

local function buttonDisp(button)
  local value = nil
  if button == "H" then  -- Home
    value = buttons1:get()[1]
  elseif button == "C" then
    value = buttons1:get()[2]
  elseif button == "Z" then
    value = buttons1:get()[3]
  elseif button == "A" then
    value = buttons1:get()[5]
  elseif button == "B" then
    value = buttons1:get()[6]
  elseif button == "+" then
    value = buttons2:get()[4]
  elseif button == "^" then
    value = buttons2:get()[5]
  elseif button == "v" then
    value = buttons2:get()[6]
  elseif button == ">" then
    value = buttons2:get()[7]
  elseif button == "<" then
    value = buttons2:get()[8]
  end
  if value == 1 then
    return button
  else
    return " "
  end
end
local function inputDisplay()
  local displayStickX = string.format("%+.3f", stickX:get())
  local displayStickY = string.format("%+.3f", stickY:get())
  local displayButtons1 = string.format("%s%s%s%s%s",
    buttonDisp("C"), buttonDisp("^"), buttonDisp("v"),
    buttonDisp("<"), buttonDisp(">")
  )
  local displayButtons2 = string.format("%s%s%s%s%s",
    buttonDisp("A"), buttonDisp("B"), buttonDisp("Z"),
    buttonDisp("+"), buttonDisp("H")
  )
  local s = string.format(
    "Stick   Buttons\n".."%s   %s\n".."%s   %s",
    displayStickX, displayButtons1, displayStickY, displayButtons2
  )
  return s
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI layout specifications.

local vars = {}
local updateMethod = nil
local updateTimeInterval = nil
local updateButton = nil
local generalFontName = "Calibri"  -- alt: Arial
local fixedWidthFontName = "Consolas"  -- alt: Lucida Console

local layoutTime = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 16
  
    -- Set the display window's size.
    window:setSize(450, 100)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called regularly as the game runs, we'll update
    -- the label text.
    vars.label = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      fileTimeDisplay().."\n"..stageTimeDisplay()
    )
  end,
}

local layoutVelocity = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(500, 200)
    
    vars.label = initLabel(window, 10, 5, "", 13, fixedWidthFontName)
    --shared.debugLabel = initLabel(window, 5, 180, "")
    
    vars.dispY = Velocity:new("Y")
    vars.dispXZ = Velocity:new("XZ")
    vars.dispXYZ = Velocity:new("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.dispY:display(),
        vars.dispXZ:display(),
        vars.dispXYZ:display(),
        pos.display(),
      }, "\n")
    )
  end,
}

local layoutDispYRecording = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(400, 130)
  
    vars.label = initLabel(window, 10, 5, "", 16, fixedWidthFontName)
    
    vars.dispY = Velocity:new("Y")
    vars.statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.dispY:display(),
      }, "\n")
    )
    
    if vars.statRecorder.currentlyTakingStats then
      local s = vars.dispY:display(1, 10, true)
      vars.statRecorder:takeStat(s)
    end
  end,
}

local layoutInputs = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(500, 300)
  
    vars.label = initLabel(window, 10, 5, "", 13, fixedWidthFontName)
    vars.inputsLabel = initLabel(window, 10, 150, "", 12, fixedWidthFontName)
    --shared.debugLabel = initLabel(window, 10, 220, "", 8, fixedWidthFontName)
    
    vars.dispY = Velocity:new("Y")
    vars.dispXZ = Velocity:new("XZ")
    vars.dispXYZ = Velocity:new("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.dispY:display(),
        vars.dispXZ:display(),
        vars.dispXYZ:display(),
      }, "\n")
    )
    vars.inputsLabel:setCaption(
      inputDisplay()
    )
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutInputs



-- Initializing the GUI window.

local window = createForm(true)
-- Put it in the center of the screen.
window:centerScreen()
-- Set the window title.
window:setCaption("RAM Display")
-- Customize the font.
local font = window:getFont()
font:setName(generalFontName)
font:setSize(16)

layout.init(window)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


dolphin.setupDisplayUpdates(
  updateMethod, layout.update, window, updateTimeInterval, updateButton)

