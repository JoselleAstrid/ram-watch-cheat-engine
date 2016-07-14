-- Super Mario Galaxy

-- US version
-- local gameId = "RMGE01"
-- local refPointerOffset = 0xF8EF88

-- JP version
local gameId = "RMGJ01"
local refPointerOffset = 0xF8F328

-- EU version
-- local gameId = "RMGP01"
-- local refPointerOffset = 0xF8EF88




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
addrs.zeros = addrs.o + 0x626000



-- These addresses can change more frequently, so we specify them as
-- functions that can be run continually.

local computeAddr = {
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like pos and vel)
    -- move by the same amount as the value change.
    --
    -- This pointer value changes whenever you load a different area.
    -- Also, it's invalid during transition screens and before the
    -- title screen.
    return addrs.o + readIntBE(addrs.o + refPointerOffset, 4) - 0x80000000
  end,
  
  messageInfoPointer = function()
    -- Pointer that can be used to locate various message/text related info.
    --
    -- This pointer value changes whenever you load a different area.
    return addrs.o + readIntBE(addrs.o + 0x9A9240, 4) - 0x80000000
  end,
  
  posBlock = function()
    return addrs.refPointer + 0x3EEC
  end
}

local function updateAddresses()
  addrs.refPointer = computeAddr.refPointer()
  addrs.messageInfoPointer = computeAddr.messageInfoPointer()
  addrs.posBlock = computeAddr.posBlock()
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



-- Values that are a constant offset from the messageInfoPointer.
local MessageInfoValue = {}

copyFields(MessageInfoValue, {MemoryValue})

function MessageInfoValue:getAddress()
  return addrs.messageInfoPointer + self.offset
end


  
-- Unlike SMG2, SMG1 does not exactly have an in-game timer. However, this
-- address seems to be the next best thing.
-- It counts up by 1 per frame starting from the level-beginning cutscenes.
-- It also pauses for a few frames when you get the star.
-- It resets to 0 if you die.
local stageTimeFrames = V("Stage time, frames", 0x9ADE58, {StaticValue, IntValue})

local stageTimeDisplay = utils.curry(smg.timeDisplay, stageTimeFrames, "stage")



-- Inputs and spin state.

local buttons1 = V("Buttons 1", 0x61D342, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
local buttons2 = V("Buttons 2", 0x61D343, {StaticValue, BinaryValue},
  {binarySize=8, binaryStartBit=7})
  
local buttonDisp = utils.curry(smg.buttonDisp, buttons1, buttons2)

local wiimoteSpinBit = V("Wiimote spin bit", 0x27F0, {RefValue, ByteValue})
local nunchukSpinBit = V("Nunchuk spin bit", 0x27F1, {RefValue, ByteValue})
local spinCooldownTimer = V("Spin cooldown timer", 0x2217, {RefValue, ByteValue})
local spinAttackTimer = V("Spin attack timer", 0x2214, {RefValue, ByteValue})

local getShakeType = utils.curry(smg.getShakeType, wiimoteSpinBit, nunchukSpinBit)
local shakeDisp = utils.curry(smg.shakeDisp, getShakeType)
local spinDisp = utils.curry(
  smg.spinDisp, spinCooldownTimer, spinAttackTimer, getShakeType
)

local stickX = V("Stick X", 0x61D3A0, {StaticValue, FloatValue})
local stickY = V("Stick Y", 0x61D3A4, {StaticValue, FloatValue})

local inputDisplay = utils.curry(
  smg.inputDisplay, stickX, stickY, buttonDisp, shakeDisp, spinDisp
)

local newStickInputImage = utils.curry(
  smg.StickInputImage.new, smg.StickInputImage, stickX, stickY
)



-- General-interest state values.

local generalState1a = V(
  "State bits 01-08", -0x128, {PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1b = V(
  "State bits 09-16", -0x127, {PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1c = V(
  "State bits 17-24", -0x126, {PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local generalState1d = V(
  "State bits 25-32", -0x125, {PosBlockValue, BinaryValue},
  {binarySize=8, binaryStartBit=7}
)
local function onGround()
  return (generalState1a:get()[2] == 1)
end
  


-- Position, velocity, and other coordinates related stuff.

local pos = Vector3Value:new(
  V("Pos X", 0x0, {PosBlockValue, FloatValue}),
  V("Pos Y", 0x4, {PosBlockValue, FloatValue}),
  V("Pos Z", 0x8, {PosBlockValue, FloatValue}),
  "Position"
)
pos.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

local pos_early1 = Vector3Value:new(
  V("Pos X", 0x18DC, {RefValue, FloatValue}),
  V("Pos Y", 0x18E0, {RefValue, FloatValue}),
  V("Pos Z", 0x18E4, {RefValue, FloatValue}),
  "Position"
)
pos_early1.displayDefaults = {signed=true, beforeDecimal=5, afterDecimal=1}

-- TODO: Check if needed
-- local posDisplay = utils.curry(
--   smg.coordsDisplay, pos.X, pos.Y, pos.Z, "Pos", 5, 1
-- )

-- Mario/Luigi's direction of gravity.
local upVectorGravity = Vector3Value:new(
  V("Up X", 0x6A3C, {RefValue, FloatValue}),
  V("Up Y", 0x6A40, {RefValue, FloatValue}),
  V("Up Z", 0x6A44, {RefValue, FloatValue}),
  "Grav (Up)"
)
upVectorGravity.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=4}

local downVectorGravity = Vector3Value:new(
  V("Up X", 0x1B10, {RefValue, FloatValue}),
  V("Up Y", 0x1B14, {RefValue, FloatValue}),
  V("Up Z", 0x1B18, {RefValue, FloatValue}),
  "Grav (Down)"
)
downVectorGravity.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=4}

-- TODO: Check if needed
-- local upVectorGravityDisplay = utils.curry(
--   smg.coordsDisplay, upVectorGravity.X, upVectorGravity.Y, upVectorGravity.Z, "Up (Grav)", 1, 5
-- )

-- Up vector (tilt). Offset from the gravity up vector when there is tilt.
local upVectorTilt = Vector3Value:new(
  V("Up X", 0xC0, {PosBlockValue, FloatValue}),
  V("Up Y", 0xC4, {PosBlockValue, FloatValue}),
  V("Up Z", 0xC8, {PosBlockValue, FloatValue}),
  "Tilt (Up)"
)
upVectorTilt.displayDefaults = {signed=true, beforeDecimal=1, afterDecimal=4}

-- TODO: Check if needed
-- local upVectorTiltDisplay = utils.curry(
--   smg.coordsDisplay, upVectorTilt.X, upVectorTilt.Y, upVectorTilt.Z, "Up (Tilt)", 1, 5
-- )


-- Velocity based on position change.
-- Initialization example: obj = Velocity("XZ")
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
  V("Base Vel X", 0x78, {PosBlockValue, FloatValue}),
  V("Base Vel Y", 0x7C, {PosBlockValue, FloatValue}),
  V("Base Vel Z", 0x80, {PosBlockValue, FloatValue}),
  "Base Vel"
)
baseVel.displayDefaults = {signed=true}

local function RateOfChange(...)
  return smg.RateOfChange:new(...)
end

local function Tilt()
  return smg.Tilt:new(downVectorGravity, upVectorTilt)
end

local function UpwardVelocity()
  return smg.UpwardVelocity:new(pos, downVectorGravity)
end

local function LateralVelocity()
  return smg.LateralVelocity:new(pos, downVectorGravity)
end

local function UpwardVelocityLastJump()
  return smg.UpwardVelocityLastJump:new(pos, downVectorGravity, onGround)
end

local function UpVelocityTiltBonus(tiltValue)
  local nextVel = Vector3Value:new(
    RateOfChange(smg.VToDerivedValue(pos_early1.x)),
    RateOfChange(smg.VToDerivedValue(pos_early1.y)),
    RateOfChange(smg.VToDerivedValue(pos_early1.z)),
    "Velocity"
  )
  return smg.UpVelocityTiltBonus:new(nextVel, downVectorGravity, onGround, tiltValue)
end

local function AnchoredDistance(coordinates)
  return smg.AnchoredDistance:new(pos, coordinates)
end

local function AnchoredHeight()
  return smg.AnchoredHeight:new(pos, downVectorGravity)
end

local function MaxValue(baseValue)
  return smg.MaxValue:new(baseValue)
end
local function AverageValue(baseValue)
  return smg.AverageValue:new(baseValue)
end

-- Resettable values can be reset using 'v' (D-Pad Down)
local function ResettableValue(baseValue)
  return smg.ResettableValue:new(buttonDisp, 'v', baseValue)
end



-- Text.

local textProgress = V("Text progress", 0x2D39C, {MessageInfoValue, IntValue})
local alphaReq = V("Alpha req", 0x2D3B0, {MessageInfoValue, FloatValue})
local fadeRate = V("Fade rate", 0x2D3B4, {MessageInfoValue, FloatValue})




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
    -- utils.setDebugLabel(initLabel(window, 10, 5, "", 9))
  
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
    --utils.setDebugLabel(initLabel(window, 20, 165, "DEBUG"))
    
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
    --utils.setDebugLabel(initLabel(window, 200, 5, ""))
    
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

local layoutMessages = {
  
  init = function(window)
    updateMethod = "breakpoint"
  
    window:setSize(162, 528)
  
    vars.inputsLabel = initLabel(window, 6, 64, "", 12, fixedWidthFontName)
    local imageY = 134
    vars.timeLabel = initLabel(window, 6, 248, "", 12, fixedWidthFontName)
    vars.messageLabel = initLabel(window, 6, 330, "", 12, fixedWidthFontName)
  
    -- vars.timeLabel = initLabel(window, 6, 5, "", 12, fixedWidthFontName)
    -- vars.messageLabel = initLabel(window, 6, 88, "", 12, fixedWidthFontName)
    -- vars.inputsLabel = initLabel(window, 6, 338, "", 12, fixedWidthFontName)
    -- local imageY = 410
    
    -- vars.inputsLabel = initLabel(window, 6, 88, "", 12, fixedWidthFontName)
    -- local imageY = 160
    -- vars.messageLabel = initLabel(window, 6, 284, "", 12, fixedWidthFontName)
    
    -- utils.setDebugLabel(initLabel(window, 10, 515, "", 8, fixedWidthFontName))
    
    -- Graphical display of stick input
    vars.stickInputImage = newStickInputImage(
      window,
      100,    -- size
      10, imageY    -- x, y position
    )
  end,
  
  update = function()
    updateAddresses()
    
    vars.timeLabel:setCaption(stageTimeDisplay("narrow"))
    
    local s = table.concat({
      textProgress:display{narrow=true},
      alphaReq:display{narrow=true},
      fadeRate:display{narrow=true},
    }, "\n")
    vars.messageLabel:setCaption(s)
    
    vars.inputsLabel:setCaption(
      inputDisplay("spin", "compact")
    )
    vars.stickInputImage:update()
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
    -- TODO: Determine if needed
    --local sizes = {"8 lines", "4 lines no space", "100 pixels", "3 lines"}
    -- local sizes = {"14 lines", "4 lines no space", "3 lines"}
    -- local Ys = utils.determineWindowYs(window, sizes, fontSize)
    
    -- vars.coordsLabel = initLabel(window, X, Ys[1], "", fontSize, fixedWidthFontName)
    -- vars.inputsLabel = initLabel(window, X, Ys[2], "", fontSize, fixedWidthFontName)
    -- local imageY = Ys[3]
    -- vars.timeLabel = initLabel(window, X, Ys[4], "", fontSize, fixedWidthFontName)
    vars.coordsLabel = initLabel(window, X, 0, "", fontSize, fixedWidthFontName)
    vars.inputsLabel = initLabel(window, X, 0, "", fontSize, fixedWidthFontName, inputColor)
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
    
    --utils.setDebugLabel(initLabel(window, X, 0, "", 8, fixedWidthFontName))
    
    
    -- Some of the value objects might need valid addresses during initialization.
    updateAddresses()
    
    -- vars.velocityX = Velocity("X")
    -- vars.velocityY = Velocity("Y")
    -- vars.velocityZ = Velocity("Z")
    
    vars.velUp = UpwardVelocity()
    vars.upwardAccel = RateOfChange(vars.velUp, "Up Accel")
    vars.upwardVelocityLastJump = UpwardVelocityLastJump()
    vars.tilt = Tilt()
    vars.upVelocityTiltBonus = UpVelocityTiltBonus(vars.tilt)
    --vars.speedLateral = LateralVelocity()
    
    --vars.speedXZ = Velocity("XZ")
    
    --vars.velY = Velocity("Y")
    --vars.speedXYZ = Velocity("XYZ")
    --vars.anchoredDistXZ = ResettableValue(AnchoredDistance("XZ"))
    --vars.anchoredMaxDistY = ResettableValue(MaxValue(AnchoredDistance("Y")))
    --vars.anchoredMaxHeight = ResettableValue(MaxValue(AnchoredHeight()))
    --vars.averageSpeedXZ = ResettableValue(AverageValue(Velocity("XZ")))
    
    --vars.accelY = RateOfChange(vars.velY, "Y Accel")
  end,
  
  update = function()
    updateAddresses()
    
    vars.timeLabel:setCaption(stageTimeDisplay("narrow"))
    
    -- TODO: Check if needed
    
    -- -- This velocity vector:
    -- -- - Is our next frame's velocity (needed for our calculation)
    -- -- - Doesn't disregard non-tilting slopes (bad for our calculation, but
    -- --   don't know how to avoid)
    -- local velocity = Vector3:new(baseVel.x:get(), baseVel.y:get(), baseVel.z:get())
    -- --local tiltDiff = vars.tilt:getDiff()
    -- --local tiltDiffDotVelocity = tiltDiff:dot(velocity)
    
    -- local arr = vars.tilt:getRotation()
    -- local tiltRadians = arr[1]
    -- local tiltAxis = arr[2]
    -- -- Apply the tilt to the ground velocity vector.
    -- -- This is a vector rotation, which we'll calculate with Rodrigues' formula.
    -- local term1 = velocity:times(math.cos(tiltRadians))
    -- local term2 = tiltAxis:cross(velocity):times(math.sin(tiltRadians))
    -- local term3 = tiltAxis:times( tiltAxis:dot(velocity) * (1-math.cos(tiltRadians)) )
    -- local tiltedVelocity = term1:plus(term2):plus(term3)
    -- -- Find the bonus initial upward velocity
    -- -- that our tilted velocity would give us if we jumped right now.
    -- -- It's the upward component of the tilted velocity.
    -- -- TODO: Stop updating it when off the ground.
    -- local upVectorValue = Vector3:new(upVectorGravity.x:get(), upVectorGravity.y:get(), upVectorGravity.z:get())
    -- local upVelocityTiltBonus = tiltedVelocity:dot(upVectorValue)
    
    -- Next frame's velocity
    --local bvx = baseVel.x:get()
    --local bvz = baseVel.z:get()
    --local baseSpeedXZ = math.sqrt(bvx*bvx + bvz*bvz)
    
    local s = table.concat({
      -- vars.velocityX:display{narrow=true},
      -- vars.velocityY:display{narrow=true},
      -- vars.velocityZ:display{narrow=true},
      
      downVectorGravity:display{narrow=true},
      upVectorTilt:display{narrow=true},
      vars.upwardVelocityLastJump:display{narrow=true, beforeDecimal=2, afterDecimal=3},
      vars.upwardAccel:display{narrow=true, signed=true, beforeDecimal=2, afterDecimal=3},
      vars.upVelocityTiltBonus:display{narrow=true},
      
      --vars.velUp:display{narrow=true},
      -- vars.speedLateral:display{narrow=true},
      --pos:display{narrow=true},
      
      --vars.speedXZ:display{narrow=true},
      --vars.anchoredMaxDistY:display(),
      --vars.anchoredMaxHeight:display{narrow=true},
      --"Base Spd XZ:\n "..utils.floatToStr(baseSpeedXZ),
      --vars.accelY:display{narrow=true},
      --vars.tilt:displayRotation(),
      --vars.tilt:displayDiff{narrow=true},
      --"On ground:\n "..tostring(onGround()),
      
      --vars.averageSpeedXZ:display{narrow=true},
      --vars.anchoredDistXZ:display{narrow=true},
      
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

