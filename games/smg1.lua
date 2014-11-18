-- Super Mario Galaxy



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

local values = {}



-- Computing RAM values.

local compute = {
    
  o = function()
    values.o = dolphin.getGameStartAddress()
  end,
  
  stageTime = function()
    -- Unlike SMG2, SMG1 does not exactly have an in-game timer. However, this
    -- address seems to be the next best thing.
    -- It counts up by 1 per frame starting from the level-beginning cutscenes.
    -- It also pauses for a few frames when you get the star.
    -- It resets to 0 if you die.
    local address = 0x809ADE58
    values.stageTimeFrames = readIntBE(address + values.o, 4)
  end,
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like pos and vel)
    -- move by the same amount as the value change.
    local address = 0x80F8EF88
    values.refPointer = readIntBE(address + values.o, 4)
  end,
  
  position = function()
    local posStartAddress = values.o + values.refPointer + 0x3EEC
    values.posXprev = values.posX
    values.posYprev = values.posY
    values.posZprev = values.posZ
    
    local posXtemp = readFloatBE(posStartAddress, 4)
    if posXtemp ~= nil then
      values.posX = posXtemp
      values.posY = readFloatBE(posStartAddress+0x4, 4)
      values.posZ = readFloatBE(posStartAddress+0x8, 4)
    else
      -- We seem to be reading a non-readable address; perhaps the pointer
      -- is temporarily invalid. This will happen in SMG2 when switching
      -- between Mario and Luigi on the Starship.
      values.posX = nil
      values.posY = nil
      values.posZ = nil
    end
  end,

  velocity = function()
    -- Note on these velocity values: not all kinds of movement are covered.
    -- For example, launch stars and riding moving platforms aren't
    -- accounted for.
    -- So it may be preferable to use displacement instead of velocity, since
    -- displacement is calculated from the position values, which seem more
    -- generally applicable.
    
    local velStartAddress = values.o + values.refPointer + 0x3F64
    
    values.velX = readFloatBE(velStartAddress, 4)
    values.velY = readFloatBE(velStartAddress+0x4, 4)
    values.velZ = readFloatBE(velStartAddress+0x8, 4)
    values.velXZ = math.sqrt(
      values.velX*values.velX + values.velZ*values.velZ
    )
  end,

  displacement = function()
    -- Similar to velocity, except that it takes the difference between
    -- previous and current positions, rather than taking a velocity value
    -- from memory. Displacement is better at covering all kinds of movement,
    -- including launch stars and moving platforms.
  
    if values.posX ~= nil and values.posXprev ~= nil then
      local dispX = values.posX - values.posXprev
      local dispZ = values.posZ - values.posZprev
      values.dispY = values.posY - values.posYprev
      values.dispXZ = math.sqrt(
        dispX*dispX + dispZ*dispZ
      )
      values.dispXYZ = math.sqrt(
        dispX*dispX + values.dispY*values.dispY + dispZ*dispZ
      )
    else
      values.dispY = nil
      values.dispXZ = nil
      values.dispXYZ = nil
    end
  end,
}



-- Displaying RAM values.

local keysToLabels = {
  dispY = "Vel Y",
  dispXZ = "Speed XZ",
  dispXYZ = "Speed XYZ",
}

local getStr = {
  
  stageTime = function()
    local centis = math.floor((values.stageTimeFrames % 60) * (100/60))
    local secs = math.floor(values.stageTimeFrames / 60) % 60
    local mins = math.floor(math.floor(values.stageTimeFrames / 60) / 60)
    
    local stageTimeStr = string.format("%d:%02d.%02d",
      mins, secs, centis
    )
    local stageTimeDisplay = string.format("Time: %s | %d",
      stageTimeStr, values.stageTimeFrames
    )
    return stageTimeDisplay
  end,
  
  flt = function(key, precision)
    local label = keysToLabels[key] 
    return string.format(
      "%s: %s",
      label,
      floatToStr(values[key], precision)
    )
  end,
  
  position = function(precision)
    return string.format(
      "XYZ Pos: %s | %s | %s",
      floatToStr(values.posX, precision),
      floatToStr(values.posY, precision),
      floatToStr(values.posZ, precision)
    )
  end,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI layout specifications.

local statRecorder = {}

local layoutA = {
  label1 = nil,
  
  init = function(window)
    -- Set the display window's size.
    window:setSize(400, 100)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    label1 = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.stageTime()
    label1:setCaption(getStr.stageTime())
  end,
}

local layoutB = {
  label1 = nil,
  
  init = function(window)
    window:setSize(500, 200)
    label1 = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 5, 180, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.stageTime()
    compute.position()
    compute.displacement()
    label1:setCaption(
      table.concat(
        {
          getStr.stageTime(),
          getStr.flt("dispY", 3),
          getStr.flt("dispXZ", 3),
          getStr.flt("dispXYZ", 3),
          getStr.position(1),
        },
        "\n"
      )
    )
  end,
}

local layoutC = {
  label1 = nil,
  
  init = function(window)
    window:setSize(400, 130)
  
    label1 = initLabel(window, 10, 5, "")
    
    statRecorder = StatRecorder:new(window, 90)
    
    --shared.debugLabel = initLabel(window, 200, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.stageTime()
    compute.position()
    compute.displacement()
    
    label1:setCaption(
      table.concat(
        {
          getStr.stageTime(),
          getStr.flt("dispY", 3),
        },
        "\n"
      )
    )
    
    if statRecorder.currentlyTakingStats then
      local s = floatToStr(values.dispY, 6)
      statRecorder:takeStat(s)
    end
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layoutA



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
-- called exactly once every frame.

debug_removeBreakpoint(getAddress("Dolphin.exe")+dolphin.oncePerFrameAddress)
debug_setBreakpoint(getAddress("Dolphin.exe")+dolphin.oncePerFrameAddress)

-- If all goes well, everything in the following function should run
-- exactly once every frame. 

function debugger_onBreakpoint()
  
  layout.update()

  return 1

end

