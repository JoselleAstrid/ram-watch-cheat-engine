-- Super Mario Galaxy
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

local gameId = "RMGE01"  -- US version
local addrs = {
  o = dolphin.getGameStartAddress(gameId),
}

local computeAddr = {
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like pos and vel)
    -- move by the same amount as the value change.
    return addrs.o + readIntBE(addrs.o + 0xF8EF88, 4) - 0x80000000
  end,
  
  posBlock = function()
    return addrs.refPointer + 0x3EEC
  end
}

local function updateAddresses()
  addrs.refPointer = computeAddr.refPointer()
  addrs.posBlock = computeAddr.posBlock()

  -- It's useful to have an address where there's always a ton of zeros.
  -- We can use this address as the result when an address computation
  -- is invalid. Zeros are better than unreadable memory (results in
  -- error) or garbage values.
  -- This group of zeros should go on for 0x20000 to 0x30000 bytes.
  addrs.zeros = addrs.o + 0x626000
end



-- SMG1 specific classes and their supporting functions.



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
local PosBlockValue = {}

copyFields(PosBlockValue, {MemoryValue})

function PosBlockValue:getAddress()
  return addrs.posBlock + self.offset
end


  
-- Unlike SMG2, SMG1 does not exactly have an in-game timer. However, this
-- address seems to be the next best thing.
-- It counts up by 1 per frame starting from the level-beginning cutscenes.
-- It also pauses for a few frames when you get the star.
-- It resets to 0 if you die.
local stageTimeFrames = V("Stage time, frames", 0x9ADE58, {StaticValue, IntValue})
  
local function stageTimeDisplay()
  local frames = stageTimeFrames:get()

  local centis = math.floor((frames % 60) * (100/60))
  local secs = math.floor(frames / 60) % 60
  local mins = math.floor(math.floor(frames / 60) / 60)
  
  local stageTimeStr = string.format("%d:%02d.%02d",
    mins, secs, centis
  )
  local display = string.format("Time: %s | %d",
    stageTimeStr, frames
  )
  return display
end
  


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
  if beforeDecimal == nil then beforeDecimal = 3 end 
  if afterDecimal == nil then afterDecimal = 1 end 
  
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
local baseVelX = V("Base Vel X", 0x78, {PosBlockValue, FloatValue})
local baseVelY = V("Base Vel Y", 0x7C, {PosBlockValue, FloatValue})
local baseVelZ = V("Base Vel Z", 0x80, {PosBlockValue, FloatValue})

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI window layouts.

local vars = {}
local updateMethod = nil
local updateTimeInterval = nil
local updateButton = nil
local generalFontName = "Calibri"  -- alt: Arial
local fixedWidthFontName = "Consolas"  -- alt: Lucida Console

local layoutStageTime = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 16
    
    -- Set the display window's size.
    window:setSize(400, 100)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called regularly as the game runs, we'll update
    -- the label text.
    vars.label = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(stageTimeDisplay())
  end,
}

local layoutVelocity = {
  
  init = function(window)
    updateMethod = "breakpoint"
    
    window:setSize(500, 200)
    
    vars.label = initLabel(window, 10, 5, "", 13, fixedWidthFontName)
    --shared.debugLabel = initLabel(window, 20, 165, "DEBUG")
    
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
    --shared.debugLabel = initLabel(window, 200, 5, "")
    
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



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutVelocity



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

