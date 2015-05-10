-- Super Mario Galaxy 2
-- US version
local gameId = "SB4E01"



-- Imports.

-- First make sure that the imported modules get de-cached as needed. That way,
-- if we change the code in those modules and then re-run the script, we won't
-- need to restart Cheat Engine to see the code changes take effect.
--
-- Make sure this game module de-caches all packages that are used, directly
-- or through another module.
--
-- And don't let other modules do the de-caching, because if any of the loaded
-- modules accept state changes from outside, then having their data cleared
-- multiple times during initialization can mess things up.
package.loaded.shared = nil
package.loaded.utils = nil
package.loaded.dolphin = nil
package.loaded.valuetypes = nil
package.loaded.valuedisplay = nil
package.loaded._supermariogalaxyshared = nil

local shared = require "shared"
local utils = require "utils"
local dolphin = require "dolphin"
local vtypes = require "valuetypes"
local vdisplay = require "valuedisplay"
local smg = require "_supermariogalaxyshared"

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

local stageTimeDisplay = utils.curry(smg.timeDisplay, stageTimeFrames, "stage")
local fileTimeDisplay = utils.curry(smg.timeDisplay, fileTimeFrames, "file")



local pos = {}
pos.X = V("Pos X", 0x0, {PosBlockValue, FloatValue})
pos.Y = V("Pos Y", 0x4, {PosBlockValue, FloatValue})
pos.Z = V("Pos Z", 0x8, {PosBlockValue, FloatValue})

local posDisplay = utils.curry(smg.posDisplay, pos.X, pos.Y, pos.Z)

local newVelocityTracker = utils.curry(
  smg.Velocity.new, smg.Velocity, pos.X, pos.Y, pos.Z
)



-- Base velocity: not all kinds of movement are covered.
-- For example, launch stars and riding moving platforms aren't
-- accounted for.
-- So it is usually preferable to subtract positions (as Velocity
-- does) instead of using this.
local baseVelX = V("Base Vel X", -0x5B0, {PosBlockValue, FloatValue})
local baseVelY = V("Base Vel Y", -0x5AC, {PosBlockValue, FloatValue})
local baseVelZ = V("Base Vel Z", -0x5A8, {PosBlockValue, FloatValue})



-- Inputs and spin state.

local buttons1 = V("Buttons 1", 0xB38A2E, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
local buttons2 = V("Buttons 2", 0xB38A2F, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
  
local buttonDisp = utils.curry(smg.buttonDisp, buttons1, buttons2)

local wiimoteSpinBit = V("Wiimote spin bit", 0xA26, {PosBlockValue, ByteValue})
local nunchukSpinBit = V("Nunchuk spin bit", 0xA27, {PosBlockValue, ByteValue})
local spinCooldownTimer = V("Spin cooldown timer", 0x857, {PosBlockValue, ByteValue})
local spinAttackTimer = V("Spin attack timer", 0x854, {PosBlockValue, ByteValue})

local getSpinType = utils.curry(smg.getSpinType, wiimoteSpinBit, nunchukSpinBit)
local spinDisp = utils.curry(
  smg.spinDisp, spinCooldownTimer, spinAttackTimer, getSpinType
)

local stickX = V("Stick X", 0xB38A8C, {StaticValue, FloatValue})
local stickY = V("Stick Y", 0xB38A90, {StaticValue, FloatValue})

local inputDisplay = utils.curry(
  smg.inputDisplay, stickX, stickY, buttonDisp, spinDisp
)

local drawStickInput = utils.curry(
  smg.drawStickInput, stickX, stickY
)



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI window layouts.

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
    
    vars.dispY = newVelocityTracker("Y")
    vars.dispXZ = newVelocityTracker("XZ")
    vars.dispXYZ = newVelocityTracker("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.dispY:display(),
        vars.dispXZ:display(),
        vars.dispXYZ:display(),
        posDisplay(),
      }, "\n")
    )
  end,
}

local layoutDispYRecording = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(400, 130)
  
    vars.label = initLabel(window, 10, 5, "", 16, fixedWidthFontName)
    
    vars.dispY = newVelocityTracker("Y")
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
    --shared.debugLabel = initLabel(window, 300, 10, "", 8, fixedWidthFontName)
    
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
    
    vars.dispY = newVelocityTracker("Y")
    vars.dispXZ = newVelocityTracker("XZ")
    vars.dispXYZ = newVelocityTracker("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    local s = table.concat({
      stageTimeDisplay(),
      vars.dispY:display(),
      vars.dispXZ:display(),
      vars.dispXYZ:display(),
      posDisplay("narrow"),
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

