-- F-Zero GX



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

local values = {
  baseStats = {},
  currentStats = {},
}



-- Computing RAM values.

local stateBlockOffsets = {
  accel = 0x220,
  body = 0x30,
  boostDuration = 0x230,
  boostInterval = 0x234,
  cameraReorienting = 0x34,
  cameraRepositioning = 0x38,
  drag = 0x23C,
  grip1 = 0xC,
  grip2 = 0x24,
  grip3 = 0x28,
  maxSpeed = 0x22C,
  obstacleCollision = 0x584,
  slideTurn = 0x18,
  strafe = 0x1C,
  tilt1 = 0x24C,
  tilt2 = 0x254,
  tilt3 = 0x304,
  tilt4 = 0x30C,
  trackCollision = 0x588,
  turning1 = 0x10,
  turning2 = 0x14,
  turning3 = 0x20,
  turningAccel = 0x2C,
  turningDecel = 0x238,
  weight = 0x8,
  
  machineId = 0x6,
  posX = 0x7C,
  posY = 0x80,
  posZ = 0x84,
  velX = 0x94,
  velY = 0x98,
  velZ = 0x9C,
  kmh = 0x17C
}
local baseStatsBlockOffsets = {
  accel = 0x8,
  body = 0x44,
  boostDuration = 0x34,
  boostInterval = 0x38,
  cameraReorienting = 0x4C,
  cameraRepositioning = 0x50,
  drag = 0x40,
  grip1 = 0x10,
  grip2 = 0x30,
  grip3 = 0x14,
  maxSpeed = 0xC,
  slideTurn = 0x24,
  strafe = 0x28,
  tilt1 = 0x54,
  tilt2 = 0x5C,
  tilt3 = 0x6C,
  tilt4 = 0x74,
  trackCollision = 0x9C,
  turning1 = 0x18,
  turning2 = 0x20,
  turning3 = 0x2C,
  turningAccel = 0x1C,
  turningDecel = 0x3C,
  weight = 0x4
}

local compute = {
    
  o = function()
    values.o = dolphin.getGameStartAddress()
  end,
  
  refPointer = function()
    -- Pointer that we'll use for reference.
    -- Not sure what this is meant to point to exactly, but when this pointer
    -- changes value, some other relevant addresses (like the settings
    -- slider value) move by the same amount as the value change.
    local address = 0x801B78A8
    values.refPointer = readIntBE(address + values.o, 4)
  end,
  
  machineStateBlockAddress = function()
    local pointerAddress = values.refPointer + 0x22779C
    values.machineStateBlockAddress = readIntBE(pointerAddress + values.o, 4)
  end,
  
  machineBaseStatsBlockAddress = function()
    local machineIdAddress = values.machineStateBlockAddress + stateBlockOffsets.machineId
    local machineId = readIntBE(machineIdAddress + values.o, 2)
    values.machineBaseStatsBlockAddress = 0x81554000 + (0xB4*machineId)
  end,
  
  baseStats = function(key)
    local address = values.machineBaseStatsBlockAddress + baseStatsBlockOffsets[key]
    values.baseStats[key] = readFloatBE(address + values.o, 4)
  end,
  
  currentStats = function(key)
    local address = values.machineStateBlockAddress + stateBlockOffsets[key]
    values.currentStats[key] = readFloatBE(address + values.o, 4)
  end,
  
  kmh = function()
    -- This address has your km/h speed as displayed in-game on the
    -- *next* frame.
    -- There is no known address for the displayed speed on the current frame,
    -- but we can get that by just taking the previous km/h value.
    local address = values.machineStateBlockAddress + stateBlockOffsets.kmh
    
    values.currKmh = values.nextKmh
    values.nextKmh = readFloatBE(address + values.o, 4)
  end,
  
  settingsSlider = function()
    -- Accel/max speed setting; 0 (full accel) to 100 (full max speed).
    local address = values.refPointer + 0x2453A0
    values.settingsSlider = readIntBE(address + values.o, 4)
  end,
}



-- Displaying RAM values.

local statKeysToLabels = {
  accel = "Accel",
  body = "Body",
  boostDuration = "Boost duration",
  boostInterval = "Boost interval",
  cameraReorienting = "Camera reorienting",
  cameraRepositioning = "Camera repositioning",
  drag = "Drag",
  grip1 = "Grip 1",
  grip2 = "Grip 2",
  grip3 = "Grip 3",
  maxSpeed = "Max speed",
  obstacleCollision = "Obstacle collision",
  slideTurn = "Slide turn",
  strafe = "Strafe",
  tilt1 = "Tilt 1",
  tilt2 = "Tilt 2",
  tilt3 = "Tilt 3",
  tilt4 = "Tilt 4",
  trackCollision = "Track collision",
  turning1 = "Turning 1",
  turning2 = "Turning 2",
  turning3 = "Turning 3",
  turningAccel = "Turning accel",
  turningDecel = "Turning decel",
  weight = "Weight",
}

local keysToLabels = {
  currKmh = "km/h",
  nextKmh = "km/h (next)",
}

local getStr = {
  
  settingsSlider = function()
    return string.format(
      "Settings: %d%%",
      values.settingsSlider
    )
  end,
  
  flt = function(key, precision)
    local label = keysToLabels[key]
    
    if values[key] == nil then
      return string.format("%s: nil", label)
    end
    
    return string.format("%s: %s", label, floatToStr(values[key], precision))
  end,
  
  baseStats = function(key, precision)
    -- A compute and getStr function rolled into one. This way our layout code
    -- only has to specify each kind of stat once, rather than in separate
    -- compute and getStr calls.
    compute.baseStats(key)
    local label = statKeysToLabels[key].." (B)"
    return string.format(
      "%s: %s",
      label,
      floatToStr(values.baseStats[key], precision)
    )
  end,
  
  currentStats = function(key)
    compute.currentStats(key)
    local label = statKeysToLabels[key]
    return string.format(
      "%s: %s",
      label,
      floatToStr(values.currentStats[key], precision)
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
    window:setSize(300, 200)
  
    -- Add a blank label to the window at position (10,5). In the update
    -- function, which is called on every frame, we'll update the label text.
    label1 = initLabel(window, 10, 5, "")
    
    --shared.debugLabel = initLabel(window, 10, 160, "<debug>")
    
    statRecorder = StatRecorder:new(window, 90)
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.kmh()
    compute.settingsSlider()
    label1:setCaption(
      table.concat(
        {
          getStr.settingsSlider(),
          getStr.flt("currKmh", 3),
        },
        "\n"
      )
    )
    
    if statRecorder.currentlyTakingStats then
      local s = floatToStr(values.currKmh, 6)
      statRecorder:takeStat(s)
    end
  end,
}

local layoutB = {
  label1 = nil,
  
  init = function(window)
    window:setSize(300, 130)
  
    label1 = initLabel(window, 10, 5, "")
  end,
  
  update = function()
    compute.o()
    compute.refPointer()
    compute.machineStateBlockAddress()
    compute.machineBaseStatsBlockAddress()
    label1:setCaption(
      table.concat(
        {
          getStr.baseStats("tilt2", 3),
          getStr.currentStats("tilt2", 3),
        },
        "\n"
      )
    )
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

-- If the oncePerFrameAddress was chosen correctly, everything in the
-- following function should run exactly once every frame. 

function debugger_onBreakpoint()
  
  layout.update()

  return 1

end

