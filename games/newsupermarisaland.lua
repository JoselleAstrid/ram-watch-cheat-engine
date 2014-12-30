-- New Super Marisa Land (Ver 1.10, which has the Extra levels)



-- Imports.

-- First make sure that the imported modules get de-cached as needed, since
-- we may be re-running the script in the same run of Cheat Engine.
package.loaded.shared = nil
package.loaded.utils = nil

local shared = require "shared"
local utils = require "utils"

local readIntLE = utils.readIntLE
local readFloatLE = utils.readFloatLE
local floatToStr = utils.floatToStr
local initLabel = utils.initLabel
local debugDisp = utils.debugDisp
local StatRecorder = utils.StatRecorder

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- Static value (as an offset from 6kinoko.exe) that increases by 1
-- once per frame.
local frameCounterAddress = 0x11B750
-- Static instruction that runs once per frame. (This is just the
-- instruction that updates the above)
local oncePerFrameAddress = 0xE0F3



-- Data structure for RAM values we care about.

local values = {}



-- Computing RAM values.

local compute = {
  
  o = function()
    values.o = getAddress("6kinoko.exe")
  end,
  
  refPointer = function()
    values.refPointer = readIntLE(0x114424 + values.o, 4)
  end,
  
  marisaSpriteAddress = function()
    -- Not sure if this is actually the sprite count. It generally goes
    -- up/down along with sprite creation and erasure. But it could be the
    -- index of a particular sprite.
    values.spriteCount = readIntLE(0x114354 + values.o, 4)
    
    if values.spriteCount < 2 then
      -- There is no Marisa sprite, and no valid sprite in the location where
      -- we'd normally look.
      -- Possible situations: transitioning from an empty room like in
      -- Hakurei Shrine, entering a level, or exiting to the title screen.
      values.marisaSpriteAddress = nil
      return
    end
    
    local spritePtrArrayStart = readIntLE(0x114344 + values.o, 4)
    local arrayOffset = (values.spriteCount - 2) * 4
    values.marisaSpriteAddress = readIntLE(spritePtrArrayStart + arrayOffset, 4)
  end,
  
  posAndVel = function()
    if values.marisaSpriteAddress == nil then
      values.posX = nil
      values.posY = nil
      values.velX = nil
      values.velY = nil
      return
    end
    
    values.posX = readFloatLE(values.marisaSpriteAddress + 0xF0, 4)
    values.posY = readFloatLE(values.marisaSpriteAddress + 0xF4, 4)
    values.velX = readFloatLE(values.marisaSpriteAddress + 0x100, 4)
    values.velY = readFloatLE(values.marisaSpriteAddress + 0x104, 4)
  end,
  
  ticksLeft = function()
    local address = values.refPointer + 0x194404
    values.ticksLeft = readIntLE(address, 4)
  end,
  
  framesLeft = function()
    local address = values.refPointer + 0x3AA8C
    values.framesLeft = readIntLE(address, 4) / 2
  end,
  
  frameCount = function()
    local address = frameCounterAddress + values.o
    values.frameCount = readIntLE(address, 4)
  end,
}



-- Displaying RAM values.

local keysToLabels = {
  frameCount = "Frames",
  spriteCount = "Sprites",
  timeTicks = "Timer",
  velX = "Vel X",
  velY = "Vel Y",
}

local getStr = {
  
  int = function(key)
    local label = keysToLabels[key]
    
    if values[key] == nil then
      return string.format("%s: nil", label)
    end
    
    return string.format("%s: %d", label, values[key])
  end,
  
  flt = function(key, precision)
    local label = keysToLabels[key]
    
    if values[key] == nil then
      return string.format("%s: nil", label)
    end
    
    return string.format("%s: %s", label, floatToStr(values[key], precision))
  end,
  
  pos = function()
    if values.posX == nil or values.posY == nil then
      return "Pos: nil"
    end
    
    return string.format(
      "Pos: %.2f, %.2f",
      values.posX, values.posY
    )
  end,
  
  ticksAndFramesLeft = function()
    local ticks = (values.framesLeft - (values.framesLeft % 30)) / 30
    local frames = values.framesLeft % 30
    return string.format("Timer: %dT %02dF", ticks, frames)
  end,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- GUI layout specifications.

local vars = {}
local updateMethod = nil
local timer = nil
local timerInterval = nil
local timerFunction = nil

local layout1 = {
  
  init = function(window)
    updateMethod = "timer"
    timerInterval = 16
    
    -- Set the display window's size.
    window:setSize(300, 200)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    vars.label1 = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.framesLeft()
    compute.frameCount()
    vars.label1:setCaption(
      table.concat(
        {
          getStr.ticksAndFramesLeft(),
          getStr.int("frameCount"),
        },
        "\n"
      )
    )
  end,
}

local layout2 = {
  
  init = function(window)
    updateMethod = "timer"
    timerInterval = 16
  
    window:setSize(300, 200)
  
    vars.label1 = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.framesLeft()
    compute.marisaSpriteAddress()
    compute.posAndVel()
    compute.frameCount()
    vars.label1:setCaption(
      table.concat(
        {
          getStr.ticksAndFramesLeft(),
          getStr.flt("velX", 2),
          getStr.flt("velY", 2),
          getStr.pos(),
        },
        "\n"
      )
    )
  end,
}



-- *** CHOOSE YOUR LAYOUT HERE ***
local layout = layout2



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



-- Clean up from previous runs of the script 
if oncePerFrameAddress then
  debug_removeBreakpoint(getAddress("6kinoko.exe")+oncePerFrameAddress)
end


if updateMethod == "timer" then

  -- Set the window to be the timer's parent, so that when the window is
  -- closed, the timer will stop being called. This allows us to edit and then
  -- re-run the script, and then close the old window to stop previous timer
  -- loops.
  timer = createTimer(window)
  timer.setInterval(timerInterval)
  
  timerFunction = function()
    layout.update()
    
    timer.destroy()
    timer = createTimer(window)
    timer.setInterval(timerInterval)
    timer.setOnTimer(timerFunction)
  end
  timer.setOnTimer(timerFunction)

elseif updateMethod == "breakpoint" then
  
  debug_setBreakpoint(getAddress("6kinoko.exe")+oncePerFrameAddress)
  
  -- If the oncePerFrameAddress was chosen correctly, everything in the
  -- following function should run exactly once every frame.
  function debugger_onBreakpoint()
    layout.update()
    return 1
  end
  
end




