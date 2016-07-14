-- Super Mario Galaxy 2
-- US version
local gameId = "SB4E01"
local refPointerOffset = 0xC7A2C8



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
package.loaded.utils = nil
package.loaded.utils_math = nil
package.loaded.dolphin = nil
package.loaded.valuetypes = nil
package.loaded.valuedisplay = nil
package.loaded._supermariogalaxyshared = nil

local utils = require "utils"
local utils_math = require "utils_math"
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

local Vector3 = utils_math.Vector3

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
local Vector3Value = vtypes.Vector3Value
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
    return addrs.o + readIntBE(addrs.o + refPointerOffset, 4) - 0x80000000
  end,
  
  refPointer2 = function()
    return addrs.o + readIntBE(addrs.o + 0x10824F0, 4) - 0x80000000
  end,
  
  posRefPointer = function()
    local ptrValue = readIntBE(addrs.refPointer + 0x750, 4)
    
    if ptrValue < 0x80000000 or ptrValue > 0x90000000 then
      -- Rough check that we do not have a valid pointer. This happens when
      -- switching between Mario and Luigi. In this case, we'll give up
      -- on finding the position and read a bunch of zeros instead.
      return addrs.zeros
    end
    utils.debugDisp(utils.intToHexStr(ptrValue))
    
    -- TODO: Check if we still need this old offset for reference
    --return addrs.o + ptrValue - 0x80000000 - 0x8670
    return addrs.o + ptrValue - 0x80000000
  end,
}

local function updateAddresses()
  addrs.refPointer = computeAddr.refPointer()
  addrs.refPointer2 = computeAddr.refPointer2()
  addrs.posRefPointer = computeAddr.posRefPointer()
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



-- Values that are a constant offset from a certain reference pointer.
local Ref2Value = {}

copyFields(Ref2Value, {MemoryValue})

function Ref2Value:getAddress()
  return addrs.refPointer2 + self.offset
end



-- Values that are a constant offset from the position values' location.
--
-- We might end up using negative offsets from here;
-- it might be a bit confusing, but it'll work.
local PosRefValue = {}

copyFields(PosRefValue, {MemoryValue})

function PosRefValue:getAddress()
  return addrs.posRefPointer + self.offset
end



-- General-interest state values.

local generalState1a = V(
  "State bits 01-08", -0x51FC, {PosRefValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1b = V(
  "State bits 09-16", -0x51FB, {PosRefValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1c = V(
  "State bits 17-24", -0x51FA, {PosRefValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1d = V(
  "State bits 25-32", -0x51F9, {PosRefValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local function onGround()
  return (generalState1a:get()[2] == 1)
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



-- Position, velocity, and other coordinates related stuff.

local pos = Vector3Value:new(
  V("Pos X", -0x8670, {PosRefValue, FloatValue}),
  V("Pos Y", -0x866C, {PosRefValue, FloatValue}),
  V("Pos Z", -0x8668, {PosRefValue, FloatValue}),
  "Position"
)
pos.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

-- 1 frame earlier than what you see on camera.
local pos_early1 = Vector3Value:new(
  V("Pos X", -0x8C58+0x14, {PosRefValue, FloatValue}),
  V("Pos Y", -0x8C58+0x18, {PosRefValue, FloatValue}),
  V("Pos Z", -0x8C58+0x1C, {PosRefValue, FloatValue}),
  "Position"
)
pos_early1.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}



-- Velocity based on position change.
-- Initialization example: obj = Velocity("XZ")
-- TODO: Make it clear that this combines the components, making it different
-- from passing position into RateOfChange().

local function Velocity(coordinates)
  return smg.Velocity:new(pos, coordinates)
end

-- Velocity directly from a memory value.
-- Not all kinds of movement are covered. For example, launch stars and
-- riding moving platforms aren't accounted for.
--
-- It's usually preferable to use velocity based on position change, because
-- that's more accurate to observable velocity. But this velocity value
-- can still have its uses. For example, this is actually the velocity
-- observed on the NEXT frame, so if we want advance knowledge of the velocity,
-- then we might use this.

local baseVel = Vector3Value:new(
  V("Base Vel X", -0x8C58+0x38, {PosRefValue, FloatValue}),
  V("Base Vel Y", -0x8C58+0x3C, {PosRefValue, FloatValue}),
  V("Base Vel Z", -0x8C58+0x40, {PosRefValue, FloatValue}),
  "Base Vel"
)
baseVel.displayDefaults = {signed=true}


-- Gravity acting on Mario/Luigi.

local downVectorGravity = Vector3Value:new(
  V("Down X", -0x86C4, {PosRefValue, FloatValue}),
  V("Down Y", -0x86C0, {PosRefValue, FloatValue}),
  V("Down Z", -0x86BC, {PosRefValue, FloatValue}),
  "Grav (Down)"
)
downVectorGravity.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=4}

-- Downward accel acting on Mario/Luigi.

local downVectorAccel = Vector3Value:new(
  V("Down X", -0x7D88, {PosRefValue, FloatValue}),
  V("Down Y", -0x7D84, {PosRefValue, FloatValue}),
  V("Down Z", -0x7D80, {PosRefValue, FloatValue}),
  "Down accel\ndirection"
)
downVectorAccel.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=4}

-- Mario/Luigi's tilt.

local upVectorTilt = Vector3Value:new(
  V("Up X", -0x5018, {PosRefValue, FloatValue}),
  V("Up Y", -0x5014, {PosRefValue, FloatValue}),
  V("Up Z", -0x5010, {PosRefValue, FloatValue}),
  "Tilt (Up)"
)
upVectorTilt.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=4}



-- How much Mario/Luigi is tilted relative to gravity.

local function Tilt()
  return smg.Tilt:new(downVectorGravity, upVectorTilt)
end

-- Upward velocity, regardless of which direction is up.

local function UpwardVelocity()
  return smg.UpwardVelocity:new(pos, downVectorGravity)
end

-- Lateral velocity, regardless of which direction is up.

local function LateralVelocity()
  return smg.LateralVelocity:new(pos, downVectorGravity)
end

local function UpwardVelocityLastJump()
  return smg.UpwardVelocityLastJump:new(pos, downVectorGravity, onGround)
end

-- Distance from a particular point (the "anchor").

local function AnchoredDistance(coordinates)
  return smg.AnchoredDistance:new(pos, coordinates)
end

-- Modifiers that can apply to value classes.

local function RateOfChange(...)
  return smg.RateOfChange:new(...)
end

local function MaxValue(baseValue)
  return smg.MaxValue:new(baseValue)
end
local function AverageValue(baseValue)
  return smg.AverageValue:new(baseValue)
end

-- If we jump now, we'll get this much "bonus" upward velocity due to
-- the current tilt.

local function UpVelocityTiltBonus(tiltValue)
  local nextVel = Vector3Value:new(
    RateOfChange(smg.VToDerivedValue(pos_early1.x)),
    RateOfChange(smg.VToDerivedValue(pos_early1.y)),
    RateOfChange(smg.VToDerivedValue(pos_early1.z)),
    "Velocity"
  )
  return smg.UpVelocityTiltBonus:new(nextVel, downVectorGravity, onGround, tiltValue)
end



-- Inputs and spin state.

local buttons1 = V("Buttons 1", 0xB38A2E, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
local buttons2 = V("Buttons 2", 0xB38A2F, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
  
local buttonDisp = utils.curry(smg.buttonDisp, buttons1, buttons2)

local wiimoteSpinBit = V("Wiimote spin bit", -0x7C4A, {PosRefValue, ByteValue})
local nunchukSpinBit = V("Nunchuk spin bit", -0x7C49, {PosRefValue, ByteValue})
local spinCooldownTimer = V("Spin cooldown timer", -0x7E19, {PosRefValue, ByteValue})
local spinAttackTimer = V("Spin attack timer", -0x7E1C, {PosRefValue, ByteValue})

local getShakeType = utils.curry(smg.getShakeType, wiimoteSpinBit, nunchukSpinBit)
local shakeDisp = utils.curry(smg.shakeDisp, getShakeType)
local spinDisp = utils.curry(
  smg.spinDisp, spinCooldownTimer, spinAttackTimer, getShakeType
)

local stickX = V("Stick X", 0xB38A8C, {StaticValue, FloatValue})
local stickY = V("Stick Y", 0xB38A90, {StaticValue, FloatValue})

local inputDisplay = utils.curry(
  smg.inputDisplay, stickX, stickY, buttonDisp, shakeDisp, spinDisp
)

local newStickInputImage = utils.curry(
  smg.StickInputImage.new, smg.StickInputImage, stickX, stickY
)



-- Resettable values can be reset using 'v' (D-Pad Down)

local function ResettableValue(baseValue)
  return smg.ResettableValue:new(buttonDisp, 'v', baseValue)
end



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
    utils.setDebugLabel(initLabel(window, 10, 200, "", 9))
  
    vars.addresses = {
      "o", "refPointer", "refPointer2", "posRefPointer",
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
    --utils.setDebugLabel(initLabel(window, 5, 180, ""))
    
    updateAddresses()
    
    vars.velocityY = Velocity("Y")
    vars.velocityXZ = Velocity("XZ")
    vars.velocityXYZ = Velocity("XYZ")
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.velocityY:display(),
        vars.velocityXZ:display(),
        vars.velocityXYZ:display(),
        pos:display(),
      }, "\n")
    )
  end,
}

local layoutRecording = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(400, 130)
  
    vars.label = initLabel(window, 10, 5, "", 16, fixedWidthFontName)
    
    updateAddresses()
    
    vars.velocityY = Velocity("Y")
    vars.statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    updateAddresses()
    
    vars.label:setCaption(
      table.concat({
        stageTimeDisplay(),
        vars.velocityY:display(),
      }, "\n")
    )
    
    if vars.statRecorder.currentlyTakingStats then
      local s = vars.velocityY:display{beforeDecimal=1, afterDecimal=10}
      vars.statRecorder:takeStat(s)
    end
  end,
}

local layoutInputs = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    local dolphinNativeResolutionHeight = 528
    window:setSize(144, dolphinNativeResolutionHeight)
    
    local fontSize = 12
    local X = 6
    local inputColor = 0x880000    -- Cheat Engine uses BGR order, not sure why
    
    vars.coordsLabel = initLabel(window, X, 0, "", fontSize, fixedWidthFontName)
    -- vars.inputsLabel = initLabel(window, X, 0, "", fontSize, fixedWidthFontName, inputColor)
    vars.timeLabel = initLabel(window, X, 0, "", fontSize, fixedWidthFontName)
    
    -- Graphical display of stick input
    -- vars.stickInputImage = newStickInputImage(
    --   window,
    --   100,    -- size
    --   10, 0,    -- x, y position
    --   inputColor
    -- )
    
    vars.window = window
    vars.windowElements = {vars.coordsLabel, vars.timeLabel}
    -- vars.windowElements = {vars.coordsLabel, vars.inputsLabel, vars.stickInputImage.image, vars.timeLabel}
    vars.windowElementsPositioned = false
    
    -- utils.setDebugLabel(initLabel(window, X, 0, "", 8, fixedWidthFontName))
    
    
    -- Some of the value objects might need valid addresses during initialization.
    updateAddresses()
    
    -- vars.velocityX = Velocity("X")
    -- vars.velocityY = Velocity("Y")
    -- vars.velocityZ = Velocity("Z")
    
    vars.upwardVelocity = UpwardVelocity()
    vars.upwardAccel = RateOfChange(vars.upwardVelocity, "Up Accel")
    vars.upwardVelocityLastJump = UpwardVelocityLastJump()
    
    vars.tilt = Tilt()
    vars.upVelocityTiltBonus = UpVelocityTiltBonus(vars.tilt)
    
    --vars.lateralVelocity = LateralVelocity()
    
    --vars.velocityY = Velocity("Y")
    --vars.accelY = RateOfChange(vars.velocityY, "Y Accel")
    
    -- vars.speedXZ = Velocity("XZ")
    -- vars.speedXZ2 = smg.Velocity:new(pos_early1, "XZ")
  end,
  
  update = function()
    updateAddresses()
    
    vars.timeLabel:setCaption(stageTimeDisplay("narrow"))
    
    -- local bvx = baseVel.x:get()
    -- local bvz = baseVel.z:get()
    -- local baseVelXZ = math.sqrt(bvx*bvx + bvz*bvz)
    
    local s = table.concat({
      -- vars.velocityX:display{narrow=true},
      -- vars.velocityY:display{narrow=true},
      -- vars.velocityZ:display{narrow=true},
      
      -- vars.upwardVelocity:display{narrow=true},
      -- downVectorAccel:display{narrow=true},
      downVectorGravity:display{narrow=true},
      upVectorTilt:display{narrow=true},
      vars.upwardVelocityLastJump:display{narrow=true, beforeDecimal=2, afterDecimal=3},
      vars.upwardAccel:display{narrow=true, signed=true, beforeDecimal=2, afterDecimal=3},
      vars.upVelocityTiltBonus:display{narrow=true},
      
      --vars.lateralVelocity:display{narrow=true},
      --pos:display{narrow=true},
      --vars.velocityY:display{narrow=true},
      -- vars.accelY:display{narrow=true},
      -- vars.speedXZ:display{narrow=true},
      -- vars.speedXZ2:display{narrow=true, label="XZ Speed 2"},
      -- "XZ BaseVel:\n "..utils.floatToStr(baseVelXZ, {narrow=true}),
      -- "On ground:\n "..tostring(onGround()),
      -- generalState1a:display{narrow=true},
      -- generalState1b:display{narrow=true},
      -- generalState1c:display{narrow=true},
      -- generalState1d:display{narrow=true},
    }, "\n")
    vars.coordsLabel:setCaption(s)
    
    -- vars.inputsLabel:setCaption(
    --   inputDisplay("both", "compact")
    -- )
    -- vars.stickInputImage:update()
    
    if not vars.windowElementsPositioned then
      utils.positionWindowElements(vars.window, vars.windowElements)
      vars.windowElementsPositioned = true
    end
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutInputs



-- Initializing the GUI window.

local window = createForm(true)
-- Put it in the center of the screen.
--window:centerScreen()
-- TODO: Revert
window:setPosition(988,487)
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

