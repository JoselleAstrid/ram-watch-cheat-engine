-- Super Mario Galaxy 2
-- US version
local gameId = "SB4E01"



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



local addrs = {}


-- Addresses that should stay constant for the most part (as long as the
-- game start address is constant).
 
addrs.o = dolphin.getGameStartAddress(gameId)

-- It's useful to have an address where there's always a ton of zeros.
-- We can use this address as the result when an address computation
-- is invalid. Zeros are better than unreadable memory (results in
-- error) or garbage values.
-- This group of zeros should go on for 0x20000 to 0x30000 bytes.
addrs.zeros = addrs.o + 0x754000



-- These addresses can change more frequently, so we specify them as
-- functions that can be run continually.

local computeAddr = {
  
  refPointer = function()
    return addrs.o + readIntBE(addrs.o + 0xC7A2C8, 4) - 0x80000000
  end,
  
  posBlock = function()
    local ptrValue = readIntBE(addrs.refPointer + 0x750, 4)
    
    if ptrValue < 0x80000000 or ptrValue > 0x90000000 then
      -- Rough check that we do not have a valid pointer. This happens when
      -- switching between Mario and Luigi. In this case, we'll give up
      -- on finding the position and read a bunch of zeros instead.
      return addrs.zeros
    end
    
    return addrs.o + ptrValue - 0x80000000 - 0x8670
  end,
}

local function updateAddresses()
  addrs.refPointer = computeAddr.refPointer()
  addrs.posBlock = computeAddr.posBlock()
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

function pos.display(displayType, beforeDecimal, afterDecimal)
  local beforeDecimal = beforeDecimalP
  local afterDecimal = afterDecimalP
  if beforeDecimal == nil then beforeDecimal = 5 end 
  if afterDecimal == nil then afterDecimal = 1 end 
  
  local numFormat = "%+0"..(beforeDecimal+afterDecimal+2).."."..afterDecimal.."f"
    
  local format = nil
  if displayType == "narrow" then
    format = "XYZ Pos:\n %s\n %s\n %s"
  else
    format = "XYZ Pos: %s | %s | %s"
  end
  
  return string.format(
    format,
    string.format(numFormat, pos.X:get()),
    string.format(numFormat, pos.Y:get()),
    string.format(numFormat, pos.Z:get())
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
  if obj.numCoordinates == 1 then obj.label = coordinates.." Velocity"
  else obj.label = coordinates.." Speed" end
  
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



-- Inputs and spin state.

local buttons1 = V("Buttons 1", 0xB38A2E, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
local buttons2 = V("Buttons 2", 0xB38A2F, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})

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

local spinDisplay = ""
local wiimoteSpinBit = V("Wiimote spin bit", 0xA26, {PosBlockValue, ByteValue})
local nunchukSpinBit = V("Nunchuk spin bit", 0xA27, {PosBlockValue, ByteValue})
local spinCooldownTimer = V("Spin cooldown timer", 0x857, {PosBlockValue, ByteValue})
local spinAttackTimer = V("Spin attack timer", 0x854, {PosBlockValue, ByteValue})
local function getSpinType()
  if wiimoteSpinBit:get() == 1 then
    return "Wiimote spin"
  elseif nunchukSpinBit:get() == 1 then
    return "Nunchuk spin"
  else
    -- This should really only happen if the script is started in the middle
    -- of a spin.
    return "?"
  end
end
local function spinDisp()
  local cooldownTimer = spinCooldownTimer:get()
  local attackTimer = spinAttackTimer:get()
  
  if cooldownTimer > 0 then
    if attackTimer > 0 then
      -- We know we're in the middle of the spin animation, but the question
      -- is when to check for a new kind of spin (Wiimote or Nunchuk).
      --
      -- If you shake the Wiimote and then immediately shake the Nunchuk after,
      -- then you should still be considered in the middle of a Wiimote spin,
      -- despite the fact that you turned on the "would activate a Nunchuk
      -- spin" bit.
      --
      -- So we only check for a new kind of spin if there is no spin currently
      -- going on, or if the cooldown timer is at its highest value, meaning a
      -- spin must have just started on this frame. (There is potential for the
      -- script to miss this first frame, though. So if you precisely follow a
      -- Wiimote spin with a Nunchuk spin, the display may fail to update
      -- accordingly.)
      if spinDisplay == "" or cooldownTimer == 79 then
        spinDisplay = getSpinType()
      end
    else
      -- Spin attack is over, but need to wait to do another spin.
      spinDisplay = "(Cooldown)"
    end
  else
    if attackTimer > 0 then
      -- Spin attack is going in midair. (This includes "fake" midair spins,
      -- and still-active spin attacks after jump canceling a ground spin.)
      -- We'll just display this the same as any other spin.
      if spinDisplay == "" or cooldownTimer == 79 then
        spinDisplay = getSpinType()
      end
    else
      -- Both spin animation and effect are inactive.
      spinDisplay = ""
    end
  end
  return spinDisplay
end

local stickX = V("Stick X", 0xB38A8C, {StaticValue, FloatValue})
local stickY = V("Stick Y", 0xB38A90, {StaticValue, FloatValue})

local function inputDisplay(displayType)
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
  local displaySpin = spinDisp()
  
  if displayType == "compact" then
    return string.format(
      "%s\n".."%s   %s\n".."%s   %s",
      displaySpin,
      displayStickX, displayButtons1,
      displayStickY, displayButtons2
    )
  else
    return string.format(
      "Stick   Buttons\n".."%s   %s\n".."%s   %s\n".."  %s",
      displayStickX, displayButtons1,
      displayStickY, displayButtons2,
      displaySpin
    )
  end
end

local function drawStickInput(canvas, width)
  -- The canvas is assumed to be square
  
  canvas:ellipse(0,0, width,width)
  
  -- stickX and stickY range from -1 to 1. Transform that to a range from
  -- 0 to width. Also, stickY goes bottom to top while image coordinates go
  -- top to bottom, so add a negative sign to get it right.
  local x = stickX:get()*(width/2) + (width/2)
  local y = stickY:get()*(-width/2) + (width/2)
  canvas:line(width/2,width/2, x,y)
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

local layoutAddressDebug = {
  
  init = function(window)
    updateMethod = "timer"
    updateTimeInterval = 100
    
    window:setSize(400, 300)
    
    vars.label = initLabel(window, 10, 5, "", 14)
    --shared.debugLabel = initLabel(window, 10, 200, "", 9)
  
    vars.addresses = {
      "o", "refPointer", "posBlock",
    }
  end,
  
  update = function()
    local s = ""
    for _, name in pairs(vars.addresses) do
      s = s..name..": "
      vars.label:setCaption(s)
      if computeAddr[name] ~= nil then
        addrs[name] = computeAddr[name]()
      end
      s = s..utils.intToHexStr(addrs[name]).."\n"
      vars.label:setCaption(s)
    end
  end,
}

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
  
    window:setSize(500, 480)
  
    vars.label = initLabel(window, 10, 5, "", 12, fixedWidthFontName)
    vars.inputsLabel = initLabel(window, 10, 300, "", 12, fixedWidthFontName)
    --shared.debugLabel = initLabel(window, 10, 220, "", 8, fixedWidthFontName)
    
    -- Graphical display of stick input
    vars.image = createImage(window)
    vars.image:setPosition(10, 370)
    vars.canvasSize = 100
    vars.image:setSize(vars.canvasSize, vars.canvasSize)
    vars.canvas = vars.image:getCanvas()
    -- Brush: ellipse() fill
    vars.canvas:getBrush():setColor(0xF0F0F0)
    -- Pen: ellipse() outline, line()
    vars.canvas:getPen():setColor(0x000000)
    vars.canvas:getPen():setWidth(2)
    -- Initialize the whole image with the brush color
    vars.canvas:fillRect(0,0, vars.canvasSize,vars.canvasSize)
    
    vars.dispY = Velocity:new("Y")
    vars.dispXZ = Velocity:new("XZ")
    vars.dispXYZ = Velocity:new("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    local s = table.concat({
      stageTimeDisplay(),
      vars.dispY:display(),
      vars.dispXZ:display(),
      vars.dispXYZ:display(),
      pos.display("narrow"),
    }, "\n")
    -- Put labels and values on separate lines to save horizontal space
    s = string.gsub(s, ": ", ":\n ")
    vars.label:setCaption(s)
    
    vars.inputsLabel:setCaption(
      inputDisplay("compact")
    )
    drawStickInput(vars.canvas, vars.canvasSize)
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

